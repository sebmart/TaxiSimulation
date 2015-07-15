"""
Simulates the online problem by initializing an Online Method, updating customers 
using TCall, then proccesses the returned TaxiActions to produce a TaxiSolution
"""
function onlineSimulation(pb::TaxiProblem, om::OnlineMethod; period::Float64 = 1.0, noTCall::Bool = false)
	if noTCall
		newCustomers = Customer[]
		for c in pb.custs
			newC = Customer(c.id, c.orig, c.dest, c.tmin, c.tmin, c.tmaxt, c.price)
			push!(newCustomers, newC)
		end
		pb.custs = newCustomers
	end

	# Sorts customers by tcall
	custs = sort(pb.custs, by = x -> x.tcall)

	# Initializes the online method with the given taxi problem
	initialize!(om, pb)
	totalTaxiActions = TaxiActions[TaxiActions(Tuple{ Float64, Road}[], CustomerAssignment[]) for i in 1:length(pb.taxis)]

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
		newTaxiActions = update!(om, min(currentStep * period, pb.nTime), newCustomers)
		for (k,totalAction) in enumerate(totalTaxiActions)
			if !isempty(newTaxiActions[k].path) && newTaxiActions[k].path[1][1] >= (currentStep - 1) * period
				append!(totalAction.path,newTaxiActions[k].path)
			end
			if !isempty(newTaxiActions[k].custs) && newTaxiActions[k].custs[1].timeIn >= (currentStep - 1) * period
				append!(totalAction.custs,newTaxiActions[k].custs)
			end
		end
		currentStep += 1
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
