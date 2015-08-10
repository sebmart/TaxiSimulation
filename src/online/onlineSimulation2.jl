"""
Simulates the online problem by initializing an Online Method, updating customers
using TCall, then proccesses the returned TaxiActions to produce a TaxiSolution
"""
function onlineSimulation2(city::TaxiProblem, virtualCity::TaxiProblem, om::OnlineMethod; verbose=false)
	customers = Customer[]
	virtualCustomers = Customer[]
	noTcallInt = Int(om.noTcall)
	noTmaxtInt = Int(om.noTmaxt)
	for c in city.custs
		c = Customer(c.id, c.orig, c.dest, c.tcall * (1 - noTcallInt) + c.tmin * noTcallInt, c.tmin, c.tmaxt * (1 - noTmaxtInt) + city.nTime * noTmaxtInt, c.price)
		push!(customers, c)
	end
	for c in virtualCity.custs
		c = Customer(c.id, c.orig, c.dest, c.tcall * (1 - noTcallInt) + c.tmin * noTcallInt, c.tmin, c.tmaxt * (1 - noTmaxtInt) + city.nTime * noTmaxtInt, c.price)
		push!(virtualCustomers, c)
	end
	pb = copy(city)
	pb.custs = customers
	vpb = copy(virtualCity)
	vpb.custs = virtualCustomers


	# Sorts customers by tcall
	custs = sort(pb.custs, by = x -> x.tcall)
	vcusts = sort(vpb.custs, by = x -> x.tcall)
	mergedCustomers = Customer[]
	realCustomer = trues(length(custs) + length(vcusts))
	i = 1
	j = 1
	while (i <= length(custs) && j < length(vcusts))
		if custs[i].tcall < vcusts[j].tcall + TaxiSimulation.EPS
			push!(mergedCustomers, custs[i])
			i += 1
		else
			push!(mergedCustomers, vcusts[j])
			j += 1
			realCustomer[length(mergedCustomers)] = false
		end
	end
	while (i <= length(custs))
		push!(mergedCustomers, custs[i])
		i += 1
	end
	while (j <= length(vcusts))
		push!(mergedCustomers, vcusts[j])
		j += 1
		realCustomer[length(mergedCustomers)] = false
	end

	# Initializes the online method with the given taxi problem without the customers
	init = copy(pb)
	init.custs = Customer[]
	onlineInitialize!(om, init)
	totalTaxiActions = TaxiActions[TaxiActions(Tuple{ Float64, Road}[], CustomerAssignment[]) for i in 1:length(pb.taxis)]

	function onlineStep!(tStart::Float64, tEnd::Float64, newCustomers::Vector{Customer}, newVirtualCustomers::Vector{Customer})
		if verbose
			l = string([c.id for c in newCustomers])
			println("================================")
			@printf("Online Step -- time %.2f => %.2f (%.2f%%), customer(s) : %s\n", tStart, tEnd, 100*tEnd/pb.nTime, l)
		end
		# Updates the online method, selecting for taxi actions within the given time period
		newTaxiActions = onlineUpdate!(om, tEnd, newCustomers, newVirtualCustomers)
		for (k,totalAction) in enumerate(totalTaxiActions)
			if !isempty(newTaxiActions[k].path)
				if newTaxiActions[k].path[1][1] < tStart - TaxiSimulation.EPS
					error("Path modification back in time: $(newTaxiActions[k].path[1][1]) < $tStart !")
				else
					append!(totalAction.path,newTaxiActions[k].path)
				end
			end
			if !isempty(newTaxiActions[k].custs)
				if newTaxiActions[k].custs[1].timeIn < tStart - TaxiSimulation.EPS
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
		vcurrentIndex = 1
		while (currentStep-1) * period <= pb.nTime
			newCustomers = Customer[]
			index = currentIndex
			while index <= length(custs) && custs[index].tcall <= (currentStep - 1) * period
				index += 1
			end
			newCustomers = custs[currentIndex:(index - 1)]
			currentIndex = index

			newVirtualCustomers = Customer[]
			vindex = vcurrentIndex
			while vindex <= length(vcusts) && vcusts[vindex].tcall <= (currentStep - 1) * period
				vindex += 1
			end
			newVirtualCustomers = vcusts[vcurrentIndex:(vindex - 1)]
			vcurrentIndex = vindex
			# Selects for customers with tcall in the current time period
			onlineStep!((currentStep-1)*period, min(pb.nTime,currentStep*period), newCustomers, newVirtualCustomers)
			currentStep += 1
		end
	else
		# Goes through time, adding customers and updating the online solution
		startIndex = 1
		while startIndex <= length(mergedCustomers)
			# Selects for customers with tcall in the current time period
			newCustomers = Customer[]
			newVirtualCustomers = Customer[]
			finishIndex = startIndex
			while (finishIndex <= length(mergedCustomers) && mergedCustomers[finishIndex].tcall < mergedCustomers[startIndex].tcall + TaxiSimulation.EPS)
				if realCustomer[finishIndex]
					push!(newCustomers, mergedCustomers[finishIndex])
				else
					push!(newVirtualCustomers, mergedCustomers[finishIndex])
				end
				finishIndex += 1
			end

			# Updates the online method, selecting for taxi actions within the given time period
			if finishIndex <= length(mergedCustomers)
				onlineStep!(mergedCustomers[startIndex].tcall, mergedCustomers[finishIndex].tcall, newCustomers, newVirtualCustomers)
			else
				onlineStep!(mergedCustomers[startIndex].tcall, pb.nTime, newCustomers, newVirtualCustomers)
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
