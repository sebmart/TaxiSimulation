###################################################
## online/nearesttaxi.jl
## baseline for pure-online solving
###################################################

"""
	`NearestTaxi`, OnlineAlgorithm that continuously improves best solution, constrained by time of search
	- uses an offline solution. Customers that are not rejected yet are either already taken,
	taken in the future or already rejected
"""
type NearestTaxi <: OnlineAlgorithm
	pb::TaxiProblem
	startTime::Float64

	freeTaxiOnly::Bool
	function NearestTaxi(;freeTaxiOnly::Bool=false)
		nt = new()
		nt.startTime = 0.0
		nt.freeTaxiOnly = freeTaxiOnly
		return nt
	end
end

function onlineInitialize!(nt::NearestTaxi, pb::TaxiProblem)
	tminOrderF(x::Customer) = x.tmin
	tminOrder = Base.Order.By(tminOrderF)

	nt.pb = pb
	nt.pb.taxis = copy(nt.pb.taxis)
	nt.pb.custs = Collections.heapify!(nt.pb.custs, tminOrder)
end


function onlineUpdate!(nt::NearestTaxi, endTime::Float64, newCustomers::Vector{Customer})
	pb=nt.pb
	tminOrderF(x::Customer) = x.tmin
	tminOrder = Base.Order.By(tminOrderF)
	tt = getPathTimes(pb.times)

	for c in newCustomers
		Collections.heappush!(pb.custs, c, tminOrder)
	end

	actions = emptyActions(pb)
	# Iterates through all customers and assigns them to the closest free taxi, if available
	while !isempty(pb.custs) && pb.custs[1].tmin <= endTime
		c = Collections.heappop!(pb.custs, tminOrder)
		
		taxiIndex = 0
		minPickupTime = Inf
		# Free taxis can have either driven no customers at all or dropped off their last customer before the new customer's appearence
		for (k,t) in enumerate(pb.taxis)
			if (!nt.freeTaxiOnly || t.initTime <= c.tmin + 2*EPS) && max(t.initTime, c.tmin) + tt[t.initPos, c.orig] <= c.tmax
				pickupTime = max(t.initTime, c.tmin) + tt[t.initPos, c.orig]
				if pickupTime < minPickupTime
					minPickupTime = pickupTime; taxiIndex = k
				end
			end
		end
		# If there is no closest free taxi, then this customer is not picked up at all
		if taxiIndex == 0
			continue
		else
			k = taxiIndex; t = pb.taxis[k]
			path, times = getPathWithTimes(pb.times, t.initPos, c.orig, startTime=max(t.initTime, c.tmin))
			append!(actions[k].path, path[2:end])
			append!(actions[k].times, times)
			path, times = getPathWithTimes(pb.times, c.orig, c.dest, startTime=minPickupTime + pb.customerTime)
			append!(actions[k].path, path[2:end])
			append!(actions[k].times, times)

			dropoffT = minPickupTime + tt[c.orig, c.dest] + 2 * pb.customerTime
			push!(actions[k].custs, CustomerAssignment(c.id, minPickupTime, dropoffT))
			# Updates the taxi's initial location and time
			pb.taxis[k] = Taxi(pb.taxis[k].id, c.dest, dropoffT)
		end
	end

	# Updates the remaining taxis (stay at the same place)
	for (k,t) in enumerate(pb.taxis)
		if t.initTime < endTime
			pb.taxis[k] = Taxi(t.id, t.initPos, endTime)
		end
	end

	# Returns new TaxiActions to OnlineSimulation
	nt.startTime = endTime
	return actions
end
