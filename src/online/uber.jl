type Uber <: OnlineMethod
	pb::TaxiProblem
	startTime::Float64

	noTcall::Bool
	period::Float64
	freeTaxiOnly::Bool
	function Uber(; period::Float64 = 0.0, freeTaxiOnly::Bool=true)
		u = new()
		u.startTime = 0.0
		u.noTcall = true
		u.period = period
		u.freeTaxiOnly = freeTaxiOnly
		return u
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
			if (!om.freeTaxiOnly || om.pb.taxis[k].initTime == om.startTime) && c.tmin <= om.pb.taxis[k].initTime + tt[om.pb.taxis[k].initPos, c.orig] <= c.tmaxt
				pickupTime = om.pb.taxis[k].initTime + tt[om.pb.taxis[k].initPos, c.orig]
				if pickupTime < minPickupTime
					minPickupTime, taxiIndex = pickupTime, k
				end
			end
		end
		# If there is no closest free taxi, then this customer is not picked up at all
		if taxiIndex == 0
			continue
		else
			# Updates the online taxi actions depending on whether this is the first customer for the taxi or not
			t = onlineTaxiActions[taxiIndex]

			# Adds the path from the destination of the previous customer to the origin of the new customer
			pickupT = minPickupTime
			dropoffT = pickupT + tt[c.orig, c.dest] + 2 * om.pb.customerTime

			# Adds the path from the origin to the destination of the new customer
			append!(t.path, TaxiSimulation.getPath(om.pb, om.pb.taxis[taxiIndex].initPos, c.orig, om.pb.taxis[taxiIndex].initTime))
			append!(t.path, TaxiSimulation.getPath(om.pb, c.orig, c.dest, pickupT + om.pb.customerTime))

			# Adds the customer assignment to the taxi's customers
			push!(onlineTaxiActions[taxiIndex].custs, CustomerAssignment(c.id, pickupT, dropoffT))
			# Updates the taxi's initial location and time
			om.pb.taxis[taxiIndex] = Taxi(om.pb.taxis[taxiIndex].id, c.dest, dropoffT)
		end
	end

	# Updates the remaining taxis (stay at the same place)
	for (k,t) in enumerate(om.pb.taxis)
		if t.initTime < endTime
			om.pb.taxis[k] = Taxi(t.id, t.initPos, endTime)
		end
	end

	# Returns new TaxiActions to OnlineSimulation
	om.startTime = endTime
	return onlineTaxiActions
end
