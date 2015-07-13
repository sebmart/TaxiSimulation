type IterativeOffline <: OnlineMethod
	solver::Function
	tHorizon::Float64
	startTime::Float64
	
	pb::TaxiProblem

	customers::Vector{Customer}
	notTaken::Vector{Bool}

	function IterativeOffline(tHorizon::Float64)
		offline = new()
		offline.tHorizon = tHorizon
		offline.startTime = 0.0
		offline.customers = Customer[]
		offline.notTaken = Bool[]
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
end

"""
Updates OnlineMethod to account for new customers, returns a list of TaxiActions 
since the last update. Needs initial information to start from. 
"""
# remove/ignore customers that are after THorizon?
function update!(om::OnlineMethod, endTime::Float64, newCustomers::Vector{Customer})
	# Sets the time window for the offline solver	
	startOffline = om.startTime
	finishOffline = startOffline + om.tHorizon
	# shift = endTime - start
	
	# Adds the new customers to the problem's customers
	append!(om.customers, newCustomers)	
	append!(om.notTaken, [true for i in length(om.customers)])
	sort!(om.customers, x->x.tmin)

	# Identifies current customers with pickup window within the time window
	currentCustomers = Customer[]
	IDtoIndex = Int[]
	for customer in om.customers
		if om.notTaken[customer.id]
			if customer.tmin < startOffline 
				if customer.tmaxt >= startOffline 
					tmin = 0.0; tmaxt = min(customer.tmaxt, finishOffline) - startOffline 
					push!(IDtoIndex, customer.id)
					c = Customer(length(IDtoIndex), customer.orig, customer.dest, 0, tmin, tmaxt, customer.price)
					push!(currentCustomers, c)
				end
			elseif customer.tmin < finish
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
	offlineSolution = TaxiSolution(om.pb,localDescent(om.pb, 100))

	onlineTaxiActions = TaxiActions[TaxiActions(Tuple{ Float64, Road}[], CustomerAssignment[]) for i in 1:length(om.pb.taxis)]
	# Not taken customers should be carried over, modifying tmaxt or tmin as necessary
	for (k, TaxiAction) in enumerate(offlineSolution.taxis)
		for (i, customer) in enumerate(TaxiAction.custs)
			if TaxiAction.custs[i].timeIn + startOffline > endTime
				break
			else
				om.notTaken[IDtoIndex[customer.id]] = false
				c = CustomerAssignment(IDtoIndex[customer.id], customer.timeIn + startOffline, customer.timeOut + startOffline)
				push!(onlineTaxiActions[k].custs, c)
			end
		end
		for (t, road) in TaxiAction.path
			if t + startOffline >= onlineTaxiActions[k].custs[end].timeOut - EPS
				break
			else
				push!(onlineTaxiActions[k].path, (t + startOffline, road))
			end
		end
		(t, road) = onlineTaxiActions[k].path[end]
		newt = max(t + om.pb.roadTime[src(road), dst(road)] - startOffline, 0.0)
		om.pb.taxis[k] = Taxi(om.pb.taxi[k].id, dst(road), newt)
	end
	
	om.startTime = endTime

	# Returns new TaxiActions to OnlineSimulation
	return onlineTaxiActions
end

onlineSimulation(pb, IterativeOffline(30))

