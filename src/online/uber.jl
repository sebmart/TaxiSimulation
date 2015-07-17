type Uber <: OnlineMethod
	pb::TaxiProblem

	noTcall::Bool
	noTmaxt::Bool	
	function Uber(tHorizon::Float64)
		offline = new()
		offline.noTcall = true
		offline.noTmaxt = true
		return offline
	end
end

"""
Initializes a given OnlineMethod with a selected taxi problem without customers
"""
function onlineInitialize!(om::Uber, pb::TaxiProblem)
	om.pb = pb
	om.pb.taxis = copy(om.pb.taxis)
end

"""
Updates OnlineMethod to account for new customers, returns a list of TaxiActions 
since the last update. Needs initial information to start from. 
"""
function onlineUpdate!(om::Uber, endTime::Float64, newCustomers::Vector{Customer})
	# Sets up travel times for later use
	tt = TaxiSimulation.traveltimes(om.pb)
	
	# Maps customer IDs to their indices
	om.pb.custs = newCustomers
	IDtoIndex = Dict{Int64, Int64}()
	for (i, c) in enumerate(om.pb.custs)
		IDtoIndex[c.id] = i
	end

	# Initializes onlineTaxiActions to update accordingly
	onlineTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(om.pb.taxis)]
	updatedTaxis = Int64[]

	# Iterates through all customers and assigns them to the closest free taxi, if available
	for (i, c) in enumerate(om.pb.custs)
		minPickupTime, index = Inf, 0
		startNode, finishNode = 0, 0
		first = false
		# Free taxis can have either driven no customers at all or dropped off their last customer before the new customer's appearence
		for (j, t) in enumerate(onlineTaxiActions)
			if isempty(t.custs) && c.tmin <= om.pb.taxis[j].initTime + tt[om.pb.taxis[j].initPos, c.orig] <= c.tmaxt
				startNode = om.pb.taxis[j].initPos	
				finishNode = c.orig
				PickupTime = om.pb.taxis[j].initTime + tt[om.pb.taxis[j].initPos, c.orig]
				if PickupTime < minPickupTime
					minPickupTime, index = PickupTime, j
					first = true
				end
			elseif !isempty(t.custs) && t.custs[end].timeOut <= c.tmin && (c.tmin <= t.custs[end].timeOut + tt[om.pb.custs[IDtoIndex[t.custs[end].id]].dest, c.orig] <= c.tmaxt)
				startNode = om.pb.custs[IDtoIndex[t.custs[end].id]].dest
				finishNode = om.pb.custs[IDtoIndex[c.id]].orig
				# PickupTime = t.custs[end].timeOut + tt[om.pb.custs[IDtoIndex[onlineTaxiActions[j].custs[end].id]].dest, c.orig]
				PickupTime = om.pb.taxis[j].initTime + tt[om.pb.taxis[j].initPos, c.orig]
				if PickupTime < minPickupTime
					minPickupTime, index = PickupTime, j
					first = false
				end
			else
				continue
			end
		end
		# If there is no closest free taxi, then this customer is not picked up at all
		if index == 0
			continue
		else
			# Updates the online taxi actions depending on whether this is the first customer for the taxi or not
			t = onlineTaxiActions[index]
			push!(updatedTaxis, index)
			if first
				# Adds the path from the taxi's initial location to its new customer
				pickupT = om.pb.taxis[index].initTime + tt[om.pb.taxis[index].initPos, c.orig]
				dropoffT = pickupT + tt[c.orig, c.dest] + 2 * om.pb.customerTime
			else
				# Adds the path from the destination of the previous customer to the origin of the new customer
				pickupT = t.custs[end].timeOut + tt[om.pb.custs[IDtoIndex[t.custs[end].id]].dest, c.orig]
				dropoffT = pickupT + tt[c.orig, c.dest] + 2 * om.pb.customerTime
			end
			# Adds the path from the origin to the destination of the new customer
			append!(t.path, TaxiSimulation.getPath(om.pb, om.pb.taxis[index].initPos, c.orig, om.pb.taxis[index].initTime))
			append!(t.path, TaxiSimulation.getPath(om.pb, c.orig, c.dest, pickupT + om.pb.customerTime))
			# Adds the customer assignment to the taxi's customers
			push!(onlineTaxiActions[index].custs, CustomerAssignment(c.id, pickupT, dropoffT))
			# Updates the taxi's initial location and time
			om.pb.taxis[index] = Taxi(om.pb.taxis[index].id, c.dest, max(dropoffT, endTime))
		end
	end
	
	# Updates the remaining taxis
	for (i, taxiAction) in enumerate(onlineTaxiActions)
		if !in(i, updatedTaxis)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, om.pb.taxis[i].initPos, endTime)
		end
	end

	# println("===============")
	# @printf("%.2f %% solved", 100 * endTime / om.pb.nTime)

	# Returns new TaxiActions to OnlineSimulation
	return onlineTaxiActions
end

