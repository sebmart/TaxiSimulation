"""
Simulates the online problem by initializing an Online Method, updating customers 
using TCall, then proccesses the returned TaxiActions to produce a TaxiSolution
"""
function onlineSimulation(pb::TaxiProblem, om::OnlineMethod; period::Float64 = 1.0)
	custs = sort(pb.custs, by = x -> x.tcall)
	initialCustomers = Vector{Customer}
	laterCustomers = Vector{Customer}

	simplePb = copy(pb)
	simplePb.custs = Vector{Customer}

	initialize!(om, simplePb)
	totalTaxiActions = Array(TaxiActions, length(pb.taxis))

	currentStep = 1
	currentIndex = 1
	while (currentStep * period < pb.nTime)
		newCustomers = Vector{Customer}
		for index = currentIndex:length(custs)
			if custs[index].tcall > (currentStep - 1) * period
				newCustomers = custs[currentIndex:(index - 1)]
				currentIndex = index
				break
			end
		end
		
		newTaxiActions = update!(om, min(currentStep * period, pb.nTime), newCustomers)
		for (k,totalAction) in enumerate(totalTaxiActions)
			append!(totalAction.path,newTaxiActions[k].path)
			append!(totalAction.custs,newTaxiActions[k].custs)
		end
		currentStep += 1
	end

	customersNotTaken = falses(length(pb.custs))
	for taxi in totalTaxiActions, customer in totalTaxiActions[taxi].custs
		customersNotTaken[customer] = true
	end

	totalCost = solutionCost(pb, totalTaxiActions)

	return TaxiSolution(totalTaxiActions, customersNotTaken, totalCost)
end