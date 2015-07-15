type IterativeOffline2 <: OnlineMethod
	solver::Function
	tHorizon::Float64
	startTime::Float64
	totalSimulationTime::Float64
	
	pb::TaxiProblem
	customers::Vector{Customer}
	notTaken::Dict{Int64, Bool}

	function IterativeOffline2(tHorizon::Float64)
		offline = new()
		offline.tHorizon = tHorizon
		offline.startTime = 0.0
		offline.customers = Customer[]
		offline.notTaken = Dict{Int64, Bool}()
		return offline
	end
end

"""
Initializes a given OnlineMethod with a selected taxi problem without customers
"""
function initialize!(om::OnlineMethod, pb::TaxiProblem)
	reducedPb = copy(pb)
	reducedPb.custs = Customer[]
	om.pb = reducedPb
	om.totalSimulationTime = om.pb.nTime
end

"""
Updates OnlineMethod to account for new customers, returns a list of TaxiActions 
since the last update. Needs initial information to start from. 
"""
function update!(om::OnlineMethod, endTime::Float64, newCustomers::Vector{Customer})
	tt = TaxiSimulation.traveltimes(om.pb)
	# Sets the time window for the offline solver	
	startOffline = om.startTime
	finishOffline = startOffline + om.tHorizon

	# Adds the new customers to the problem's customers
	append!(om.customers, newCustomers)	
	for customer in om.customers
		om.notTaken[customer.id] = true
	end
	sort!(om.customers, by = x->x.tmin)

	# Identifies current customers with pickup window within the time window
	currentCustomers = Customer[]
	IDtoIndex = Int64[]
	for customer in om.customers
		if om.notTaken[customer.id]
			if customer.tmin < startOffline 
				if customer.tmaxt >= startOffline 
					tmin = 0.0; tmaxt = min(customer.tmaxt, finishOffline) - startOffline 
					push!(IDtoIndex, customer.id)
					c = Customer(length(IDtoIndex), customer.orig, customer.dest, 0, tmin, tmaxt, customer.price)
					push!(currentCustomers, c)
				end
			elseif customer.tmin < finishOffline
			 	tmaxt = min(customer.tmaxt, finishOffline) - startOffline
			 	push!(IDtoIndex, customer.id)
				c = Customer(length(IDtoIndex), customer.orig, customer.dest, 0, customer.tmin - startOffline, tmaxt, customer.price)
				push!(currentCustomers, c)
			end
		end
	end

	# Sets the problem's customers to those identified within the time window, and solves
	om.pb.custs = currentCustomers
	om.pb.nTime = om.tHorizon
	offlineSolution = TaxiSolution(om.pb,localDescent(om.pb, 1000))

	onlineTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(om.pb.taxis)]
	# Processes offline solution to fit it to online simulation
	for (i, TaxiAction) in enumerate(offlineSolution.taxis)
		# Selects for customers who taxis begin driving towards before the start of the next time window
		for j = 1:length(TaxiAction.custs)
			customer = TaxiAction.custs[j]
			if j == 1
				if TaxiAction.custs[j].timeIn + startOffline > endTime
					break
				else
					om.notTaken[IDtoIndex[customer.id]] = false
					c = CustomerAssignment(IDtoIndex[customer.id], customer.timeIn + startOffline, customer.timeOut + startOffline)
					push!(onlineTaxiActions[i].custs, c)
				end
			else
				start = om.pb.custs[TaxiAction.custs[j - 1].id].dest
				finish = om.pb.custs[TaxiAction.custs[j].id].orig
				if TaxiAction.custs[j].timeIn - tt[start, finish] + startOffline > endTime
					break
				else
					om.notTaken[IDtoIndex[customer.id]] = false
					c = CustomerAssignment(IDtoIndex[customer.id], customer.timeIn + startOffline, customer.timeOut + startOffline)
					push!(onlineTaxiActions[i].custs, c)
				end
			end
		end
		# Selects for taxi paths that finish before the last customer's dropoff
		for (t, road) in TaxiAction.path
			if isempty(onlineTaxiActions[i].custs) || t + startOffline >= onlineTaxiActions[i].custs[end].timeOut - EPS
				break
			else
				push!(onlineTaxiActions[i].path, (t + startOffline, road))
			end
		end
		# Updates the initial taxi locations and paths for the next time window
		if !isempty(onlineTaxiActions[i].path)
			(t, road) = onlineTaxiActions[i].path[end]
			newt = max(t + om.pb.roadTime[src(road), dst(road)] - startOffline, 0.0)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, dst(road), newt)
		else
			newt = max(om.pb.taxis[i].initTime - endTime + startOffline, 0.0)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, om.pb.taxis[i].initPos, newt)
		end
	end
	
	# Updates the start time for the next time window
	om.startTime = endTime

	println("===============")
	@printf("%.2f %% solved", 100 * endTime / om.totalSimulationTime)

	# Returns new TaxiActions to OnlineSimulation
	return onlineTaxiActions
end


