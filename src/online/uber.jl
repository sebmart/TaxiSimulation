type Uber <: OnlineMethod
	pb::TaxiProblem
	startTime::Float64

	noTcall::Bool
	period::Float64
	function Uber(; removeTcall::Bool = true, period::Float64 = 0.0)
		offline = new()
		offline.startTime = 0.0
		offline.noTcall = removeTcall
		offline.period = period
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

	# Initializes onlineTaxiActions to update accordingly
	onlineTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for k in 1:length(om.pb.taxis)]

	# Iterates through all customers and assigns them to the closest free taxi, if available
	for c in newCustomers
		taxiIndex = 0
		minPickupTime = Inf
		# Free taxis can have either driven no customers at all or dropped off their last customer before the new customer's appearence
		for k = 1:length(om.pb.taxis)
			if c.tmin <= om.pb.taxis[k].initTime + tt[om.pb.taxis[k].initPos, c.orig] <= c.tmaxt
				pickupTime = start + tt[om.pb.taxis[k].initPos, c.orig]
				if pickupTime < minPickupTime
					minPickupTime, index = pickupTime, k
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
	for (k,t) in enumerate(om.pb.taxis)
		if t.initTime < endTime
			om.pb.taxis[k] = Taxi(t.id, t.initPos, endTime)
		end
	end

	# Returns new TaxiActions to OnlineSimulation
	om.startTime = endTime
	return onlineTaxiActions
end
