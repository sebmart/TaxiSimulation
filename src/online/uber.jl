type Uber <: OnlineMethod
	pb::TaxiProblem
	function Uber(tHorizon::Float64)
		offline = new()
		return offline
	end
end

"""
Initializes a given OnlineMethod with a selected taxi problem without customers
"""
function initialize!(om::Uber, pb::TaxiProblem)
	om.pb = pb
end

"""
Updates OnlineMethod to account for new customers, returns a list of TaxiActions 
since the last update. Needs initial information to start from. 
"""
function update!(om::Uber, endTime::Float64, newCustomers::Vector{Customer})
	tt = TaxiSimulation.traveltimes(om.pb)
	
	# Include assert so that tcall always equals tmin (throw an error otherwise)

	# Sets the problem's customers to the new taxis
	om.pb.custs = newCustomers
	IDtoIndex = Dict{Int64, Int64}()
	for (i, c) in enumerate(om.pb.custs)
		IDtoIndex[c.id] = i
	end

	onlineTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(om.pb.taxis)]

	for (i, c) in enumerate(om.pb.custs)
		minWaitTime, index = Inf, 0
		startNode, finishNode = 0, 0
		first = false
		for (j, t) in enumerate(onlineTaxiActions)
			if isempty(t.custs) && c.tmin <= om.pb.taxis[j].initTime + tt[om.pb.taxis[j].initPos, c.orig] <= c.tmaxt
				first = true
				startNode = om.pb.taxis[j].initPos	
				finishNode = om.pb.custs[IDtoIndex[c.id]].orig
				WaitTime = tt[startNode, finishNode]
				if WaitTime < minWaitTime
					minWaitTime, index = WaitTime, j
				end
			elseif !isempty(t.custs) && t.custs[end].timeOut <= c.tmin && (c.tmin <= t.custs[end].timeOut + tt[om.pb.custs[IDtoIndex[t.custs[end].id]].dest, c.orig] <= c.tmaxt)
				startNode = om.pb.custs[IDtoIndex[t.custs[end].id]].dest
				finishNode = om.pb.custs[IDtoIndex[c.id]].orig
				WaitTime = tt[startNode, finishNode]
				if WaitTime < minWaitTime
					minWaitTime, index = WaitTime, j
				end
			else
				continue
			end
		end
		if index == 0
			break
		else
			t = onlineTaxiActions[index]
			if first
				pickupT = om.pb.taxis[index].initTime + tt[om.pb.taxis[index].initPos, c.orig]
				dropoffT = pickupT + tt[c.orig, c.dest]
				append!(onlineTaxiActions[index].path, TaxiSimulation.getPath(om.pb, om.pb.taxis[index].initPos, c.orig, om.pb.taxis[index].initTime))
				append!(onlineTaxiActions[index].path, TaxiSimulation.getPath(om.pb, c.orig, c.dest, pickupT))
				push!(onlineTaxiActions[index].custs, CustomerAssignment(c.id, pickupT, dropoffT))
			else
				pickupT = t.custs[end].timeOut + tt[om.pb.custs[IDtoIndex[t.custs[end].id]].dest, c.orig]
				dropoffT = pickupT + tt[c.orig, c.dest]
				append!(onlineTaxiActions[index].path, TaxiSimulation.getPath(om.pb, om.pb.custs[IDtoIndex[t.custs[end].id]].dest, c.orig, t.custs[end].timeOut))
				append!(onlineTaxiActions[index].path, TaxiSimulation.getPath(om.pb, c.orig, c.dest, pickupT))
				push!(onlineTaxiActions[index].custs, CustomerAssignment(c.id, pickupT, dropoffT))
			end
			(time, road) = onlineTaxiActions[index].path[end]
			newTime = time + om.pb.roadTime[src(road), dst(road)]
			om.pb.taxis[index] = Taxi(om.pb.taxis[index].id, dst(road), newTime)
		end
	end

	# println("===============")
	# @printf("%.2f %% solved", 100 * endTime / om.pb.nTime)

	# Returns new TaxiActions to OnlineSimulation
	return onlineTaxiActions
end

