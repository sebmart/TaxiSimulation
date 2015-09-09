"""
Simulates the online problem: send only the online information to an online solver
(OnlineMethod), in an iterative way. Compiles the taxis' online actions into a
TaxiSolution object

Parameters of OnlineMethod:
noTcall : customers are sent at tmin (no "booking" allowed)
noTmaxt : customers can wait indefinitely for a taxi
"""
function onlineSimulation(city::TaxiProblem, om::OnlineMethod; verbose=false)
	customers = Customer[]

	noTcallInt = :noTcall in fieldnames(om) ? Int(om.noTcall) : 0
	for c in city.custs
		c = Customer(c.id, c.orig, c.dest, c.tcall * (1 - noTcallInt) + c.tmin * noTcallInt, c.tmin, c.tmaxt, c.price)
		push!(customers, c)
	end
	pb = copy(city)
	pb.custs = customers

	# Sorts customers by tcall
	custs = sort(pb.custs, by = x -> x.tcall)

	# Initializes the online method with the given taxi problem without the customers
	init = copy(pb)
	init.custs = Customer[]
	onlineInitialize!(om, init)
	totalTaxiActions = TaxiActions[TaxiActions(Tuple{ Float64, Road}[], CustomerAssignment[]) for i in 1:length(pb.taxis)]

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

	if om.period > 0.
		period = om.period
		# Goes through time, adding customers and updating the online solution
		currentStep = 1
		currentIndex = 1
		while (currentStep-1) * period <= pb.nTime
			newCustomers = Customer[]
			index = currentIndex
			while index <= length(custs) && custs[index].tcall <= (currentStep - 1) * period
				index += 1
			end
			newCustomers = custs[currentIndex:(index - 1)]
			currentIndex = index
			# Selects for customers with tcall in the current time period
			onlineStep!((currentStep-1)*period, min(pb.nTime,currentStep*period), newCustomers)
			currentStep += 1
		end
	else
		# Goes through time, adding customers and updating the online solution
		startIndex = 1
		while startIndex <= length(custs)
			# Selects for customers with tcall in the current time period
			newCustomers = Customer[]
			finishIndex = startIndex
			while (finishIndex <= length(custs) && custs[finishIndex].tcall < custs[startIndex].tcall + EPS)
				finishIndex += 1
			end
			newCustomers = custs[startIndex:(finishIndex - 1)]

			# Updates the online method, selecting for taxi actions within the given time period
			if finishIndex <= length(custs)
				onlineStep!(custs[startIndex].tcall, custs[finishIndex].tcall, newCustomers)
			else
				onlineStep!(custs[startIndex].tcall, pb.nTime, newCustomers)
			end
			startIndex = finishIndex
		end
	end

	# Identifies customers who are not taken as part of the online solution
	customersNotTaken = trues(length(pb.custs))
	for (k, taxi) in enumerate(totalTaxiActions), customer in totalTaxiActions[k].custs
		customersNotTaken[customer.id] = false
	end

	# Coputes the overall cost for the generated taxi actions
	totalCost = solutionCost(pb, totalTaxiActions)

	# Returns the complete online solution
	return TaxiSolution(totalTaxiActions, customersNotTaken, totalCost)
end
