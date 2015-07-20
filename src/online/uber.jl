type Uber <: OnlineMethod
	pb::TaxiProblem
	startTime::Float64

	noTcall::Bool
	noTmaxt::Bool
	bySteps::Bool	
	function Uber(steps::Bool)
		offline = new()
		offline.startTime = 0.0
		offline.noTcall = true
		offline.noTmaxt = true
		offline.bySteps = steps
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
	start = om.startTime

	# Sets up travel times for later use
	tt = TaxiSimulation.traveltimes(om.pb)

	# Initializes onlineTaxiActions to update accordingly
	onlineTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(om.pb.taxis)]
	
	# Iterates through all customers and assigns them to the closest free taxi, if available
	for (i, c) in enumerate(newCustomers)
		minPickupTime, index = Inf, 0
		# initTime = tStart
		# Free taxis can have either driven no customers at all or dropped off their last customer before the new customer's appearence
		for (j, t) in enumerate(onlineTaxiActions)
			if om.pb.taxis[j].initTime == start && c.tmin <= start + tt[om.pb.taxis[j].initPos, c.orig] <= c.tmaxt
				pickupTime = start + tt[om.pb.taxis[j].initPos, c.orig]
				if pickupTime < minPickupTime
					minPickupTime, index = pickupTime, j
				end
			end
		end
		# If there is no closest free taxi, then this customer is not picked up at all
		if index == 0
			continue
		else
			# Updates the online taxi actions depending on whether this is the first customer for the taxi or not
			t = onlineTaxiActions[index]

			# Adds the path from the destination of the previous customer to the origin of the new customer
			pickupT = minPickupTime
			dropoffT = pickupT + tt[c.orig, c.dest] + 2 * om.pb.customerTime
			
			# Adds the path from the origin to the destination of the new customer
			append!(t.path, TaxiSimulation.getPath(om.pb, om.pb.taxis[index].initPos, c.orig, start))
			append!(t.path, TaxiSimulation.getPath(om.pb, c.orig, c.dest, pickupT + om.pb.customerTime))
			
			# Adds the customer assignment to the taxi's customers
			push!(onlineTaxiActions[index].custs, CustomerAssignment(c.id, pickupT, dropoffT))
			# Updates the taxi's initial location and time
			om.pb.taxis[index] = Taxi(om.pb.taxis[index].id, c.dest, dropoffT)
		end
	end
	
	# Updates the remaining taxis
	for (i, taxiAction) in enumerate(onlineTaxiActions)
		if om.pb.taxis[i].initTime < endTime
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, om.pb.taxis[i].initPos, endTime)
		end
	end

	# println("===============")
	# @printf("%.2f %% solved", 100 * endTime / om.pb.nTime)

	# Returns new TaxiActions to OnlineSimulation
	om.startTime = endTime
	return onlineTaxiActions
end

