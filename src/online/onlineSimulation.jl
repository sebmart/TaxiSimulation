"""
Simulates the online problem: send only the online information to an online solver
(OnlineMethod), in an iterative way. Compiles the taxis' online actions into a
TaxiSolution object

Parameters of OnlineMethod:
noTcall : customers are sent at tmin (no "booking" allowed)
noTmaxt : customers can wait indefinitely for a taxi
"""
function onlineSimulation(pb::TaxiProblem, om::OnlineMethod; verbose=false)
	customers = Customer[]

	noTcallInt = :noTcall in fieldnames(om) ? Int(om.noTcall) : 0
	for c in pb.custs
		c = Customer(c.id, c.orig, c.dest, c.tcall * (1 - noTcallInt) + c.tmin * noTcallInt, c.tmin, c.tmaxt, c.price)
		push!(customers, c)
	end

	# Sorts customers by tcall
	sort!(customers, by = x -> x.tcall)

	# Initializes the online method with the given taxi problem without the customers
	init = copy(pb)
	init.custs = Customer[]
	onlineInitialize!(om, init)
	totalTaxiActions = TaxiActions[TaxiActions(Tuple{ Float64, Road}[], CustomerAssignment[]) for i=1:length(pb.taxis)]

	function onlineStep!(tStart::Float64, tEnd::Float64, newCustomers::Vector{Customer})
		if verbose
			l = string([c.id for c in newCustomers])
			println("================================")
			@printf("Online Step -- time %.2f => %.2f (%.2f%%), customer(s) : %s\n", tStart, tEnd, 100*tEnd/pb.nTime, l)
		end
		# Updates the online method, selecting for taxi actions within the given time period
		newTaxiActions = onlineUpdate!(om, tEnd, newCustomers)
		for (k,totalAction) in enumerate(totalTaxiActions)
			if !isempty(newTaxiActions[k].path)
				if newTaxiActions[k].path[1][1] < tStart - EPS
					error("Path modification back in time: $(newTaxiActions[k].path[1][1]) < $tStart !")
				else
					append!(totalAction.path,newTaxiActions[k].path)
				end
			end
			if !isempty(newTaxiActions[k].custs)
				if newTaxiActions[k].custs[1].timeIn < tStart - EPS
					error("Customer modification back in time: $(newTaxiActions[k].custs[1].timeIn) < $tStart!")
				else
					append!(totalAction.custs,newTaxiActions[k].custs)
				end
			end
		end
	end

	#First case : we have an update period defined
	if :period in fieldnames(om) && om.period > 0.
		period = om.period
		# Goes through time, adding customers and updating the online solution
		currentStep = 0
		custIndex = 1
		while currentStep * period <= pb.nTime
			newCustomers = Customer[]
			index = custIndex
			while index <= length(customers) && customers[index].tcall <= currentStep * period
				index += 1
			end
			newCustomers = customers[custIndex:(index - 1)]
			custIndex = index
			onlineStep!(currentStep*period, min(pb.nTime,(currentStep+1)*period), newCustomers)
			currentStep += 1
		end
	else #Second case: we call for an update everytime a new customer calls
		# Goes through time, adding customers and updating the online solution
		startIndex = 1
		while startIndex <= length(customers)
			# Selects customers with same tcall (tolerance EPS)
			newCustomers = Customer[]
			finishIndex = startIndex + 1
			while (finishIndex <= length(customers) && customers[finishIndex].tcall < customers[startIndex].tcall + EPS)
				finishIndex += 1
			end
			newCustomers = customers[startIndex:(finishIndex - 1)]

			# Updates the online method, selecting for taxi actions within the given time period
			if finishIndex <= length(customers)
				onlineStep!(customers[startIndex].tcall, customers[finishIndex].tcall, newCustomers)
			else
				onlineStep!(customers[startIndex].tcall, pb.nTime, newCustomers)
			end
			startIndex = finishIndex
		end
	end

	# Identifies customers who are not taken as part of the online solution
	customersNotTaken = trues(length(pb.custs))
	for (k, taxi) in enumerate(totalTaxiActions), c in totalTaxiActions[k].custs
		customersNotTaken[c.id] = false
	end

	# Computes the overall cost for the generated taxi actions
	totalCost = solutionCost(pb, totalTaxiActions)

	# Returns the complete online solution
	return TaxiSolution(totalTaxiActions, customersNotTaken, totalCost)
end
