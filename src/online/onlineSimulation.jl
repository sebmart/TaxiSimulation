"""
Simulates the online problem by initializing an Online Method, updating customers
using TCall, then proccesses the returned TaxiActions to produce a TaxiSolution
"""
function onlineSimulation(pb::TaxiProblem, om::OnlineMethod; period::Float64 = 1.0)
	customers = Customer[]
	noTcallInt = Int(om.noTcall)
	noTmaxtInt = Int(om.noTmaxt)
	for c in pb.custs
		c = Customer(c.id, c.orig, c.dest, c.tcall * (1 - noTcallInt) + c.tmin * noTcallInt, c.tmin, c.tmaxt * (1 - noTmaxtInt) + pb.nTime * noTmaxtInt, c.price)
		push!(customers, c)
	end
	pb.custs = customers

	# Sorts customers by tcall
	custs = sort(pb.custs, by = x -> x.tcall)

	# Initializes the online method with the given taxi problem without the customers
	init = copy(pb)
	init.custs = Customer[]
	onlineInitialize!(om, init)
	totalTaxiActions = TaxiActions[TaxiActions(Tuple{ Float64, Road}[], CustomerAssignment[]) for i in 1:length(pb.taxis)]

	if om.bySteps
		# Goes through time, adding customers and updating the online solution
		currentStep = 1
		currentIndex = 1
		while (currentStep * period < pb.nTime)
			# Selects for customers with tcall in the current time period
			newCustomers = Customer[]
			for index = currentIndex:length(custs)
				if custs[index].tcall > (currentStep - 1) * period
					newCustomers = custs[currentIndex:(index - 1)]
					currentIndex = index
					break
				end
			end
			# Updates the online method, selecting for taxi actions within the given time period
			newTaxiActions = onlineUpdate!(om, min(currentStep * period, pb.nTime), newCustomers)
			for (k,totalAction) in enumerate(totalTaxiActions)
				if !isempty(newTaxiActions[k].path)
					if newTaxiActions[k].path[1][1] < (currentStep - 1) * period
						error("Path modification back in time!")
					else
						append!(totalAction.path,newTaxiActions[k].path)
					end
				end
				if !isempty(newTaxiActions[k].custs)
					if newTaxiActions[k].custs[1].timeIn < (currentStep - 1) * period
						error("Customer modification back in time!")
					else
						append!(totalAction.custs,newTaxiActions[k].custs)
					end
				end
			end
			currentStep += 1
		end
	else
		# Goes through time, adding customers and updating the online solution
		startIndex = 1
		while (startIndex <= length(custs))
			# Selects for customers with tcall in the current time period
			newCustomers = Customer[]
			finishIndex = startIndex
			while (finishIndex <= length(custs) && custs[finishIndex].tcall < custs[startIndex].tcall + TaxiSimulation.EPS)
				finishIndex += 1
			end
			newCustomers = custs[startIndex:finishIndex - 1]

			# Updates the online method, selecting for taxi actions within the given time period
			if finishIndex <= length(custs)
				newTaxiActions = onlineUpdate!(om, min(custs[finishIndex].tcall, pb.nTime), newCustomers)
			else
				newTaxiActions = onlineUpdate!(om, pb.nTime, newCustomers)
			end

			for (k,totalAction) in enumerate(totalTaxiActions)
				if !isempty(newTaxiActions[k].path)
					if newTaxiActions[k].path[1][1] < custs[startIndex].tcall
						error("Path modification back in time!")
					else
						append!(totalAction.path,newTaxiActions[k].path)
					end
				end
				if !isempty(newTaxiActions[k].custs)
					if newTaxiActions[k].custs[1].timeIn < custs[startIndex].tcall
						error("Customer modification back in time!")
					else
						append!(totalAction.custs,newTaxiActions[k].custs)
					end
				end
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
