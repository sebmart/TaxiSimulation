"iterate offline algorithm, simulating until tHorizon"
type IterativeOffline <: OnlineMethod
	tHorizon::Float64
	startTime::Float64

	pb::TaxiProblem
	customers::Vector{Customer}
	notTaken::Dict{Int64, Bool}

	noTcall::Bool
	noTmaxt::Bool
	period::Float64

	beforeEndTime::Bool
	function IterativeOffline(tHorizon::Float64, period::Float64, before::Bool;)
		offline = new()
		offline.tHorizon = tHorizon
		offline.startTime = 0.0
		offline.customers = Customer[]
		offline.notTaken = Dict{Int64, Bool}()
		offline.noTcall = false
		offline.noTmaxt = false
		offline.period = period
		offline.beforeEndTime = before
		return offline
	end
end

"""
Initializes a given OnlineMethod with a selected taxi problem without customers
"""
function onlineInitialize!(om::IterativeOffline, pb::TaxiProblem)
	om.pb = pb
	om.pb.taxis = copy(om.pb.taxis)
	om.pb.custs = Customer[]
end

"""
Updates OnlineMethod to account for new customers, returns a list of TaxiActions
since the last update. Needs initial information to start from.
"""
function onlineUpdate!(om::IterativeOffline, endTime::Float64, newCustomers::Vector{Customer})

	# Sets the time window for the offline solver
	tt = TaxiSimulation.traveltimes(om.pb)
	startOffline = om.startTime
	finishOffline = min(om.pb.nTime,startOffline + om.tHorizon)

	# Adds the new customers to the problem's customers
	for c in newCustomers
		om.notTaken[c.id] = true
	end
	append!(om.customers, newCustomers)

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

	offlineSolution = intervalOpt(om.pb)

	onlineTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(om.pb.taxis)]
	# Processes offline solution to fit it to online simulation
	for (i, assignments) in enumerate(offlineSolution.custs)
		# Selects for customers who are picked up before the start of the next time window
		startPos = om.pb.taxis[i].initPos
		for (j, customer) in enumerate(assignments)
			c = om.pb.custs[customer.id]
			if customer.tInf - tt[startPos,c.dest] + startOffline > endTime
				break
			elseif om.beforeEndTime && customer.tInf + startOffline > endTime
				path = getPath(om.pb, startPos, c.orig, customer.tInf + startOffline - tt[startPos, c.orig])
				for (t,r) in path
					if t < endTime
						push!(onlineTaxiActions[i].path, (t,r))
					else
						break
					end
				end
				break
			else
				c = om.pb.custs[customer.id]
				om.notTaken[IDtoIndex[customer.id]] = false
				timeOut = customer.tInf + startOffline + 2 * om.pb.customerTime + tt[c.orig, c.dest]
				assignment = CustomerAssignment(IDtoIndex[customer.id], customer.tInf + startOffline, timeOut)
				push!(onlineTaxiActions[i].custs, assignment)
				append!(onlineTaxiActions[i].path, getPath(om.pb, startPos, c.orig, assignment.timeIn - tt[startPos, c.orig]))
				append!(onlineTaxiActions[i].path, getPath(om.pb, c.orig, c.dest, assignment.timeIn + om.pb.customerTime))
				startPos = c.dest
			end
		end

		# Updates the initial taxi locations and paths for the next time window
		if !isempty(onlineTaxiActions[i].custs)
			(t, road) = onlineTaxiActions[i].path[end]
			newt = max(onlineTaxiActions[i].custs[end].timeOut - endTime, 0.0)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, dst(road), newt)
		elseif !isempty(onlineTaxiActions[i].path)
			(t, road) = onlineTaxiActions[i].path[end]
			newt = max(t + om.pb.roadTime[src(road), dst(road)] - endTime, 0.0)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, dst(road), newt)
		else
			newt = max(om.pb.taxis[i].initTime - endTime + startOffline, 0.0)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, om.pb.taxis[i].initPos, newt)
		end
	end

	# Updates the start time for the next time window
	om.startTime = endTime

	println("===============")
	@printf("%.2f %% solved", 100 * min(1.,endTime / om.pb.nTime))

	# Returns new TaxiActions to OnlineSimulation
	return onlineTaxiActions
end
