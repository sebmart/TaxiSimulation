###################################################
## online/nearesttaxi.jl
## baseline for pure-online solving
###################################################

"""
	`NearestTaxi`, Baseline: Taxi wait after drop-off, closest available taxi chosen when
	new customer
	- pure online
"""
mutable struct NearestTaxi <: OfflinePlanning
	pb::TaxiProblem
	sol::OfflineSolution
	currentCusts::DataStructures.IntSet

	freeTaxiOnly::Bool
	customerHeap::Vector{Int}
	function NearestTaxi(;freeTaxiOnly::Bool=false)
		nt = new()
		nt.freeTaxiOnly = freeTaxiOnly
		return nt
	end
end

function initialPlanning!(nt::NearestTaxi) #just heapify the customer list by tmin
	tminOrderF(c::Int) = nt.pb.custs[c].tmin
	tminOrder = Base.Order.By(tminOrderF)
	nt.customerHeap = Collections.heapify!(collect(nt.currentCusts), tminOrder)
	nt.sol = OfflineSolution(nt.pb)
end


function updatePlanning!(nt::NearestTaxi, endTime::Float64, newCustomers::Vector{Int})
	tminOrderF(c::Int) = nt.pb.custs[c].tmin
	tminOrder = Base.Order.By(tminOrderF)
	tt = getPathTimes(nt.pb.times)

	for c in newCustomers
		Collections.heappush!(nt.customerHeap, c, tminOrder)
	end

	# Iterates through all customers that appear during interval
	# and assigns them to the closest free taxi, if available
	while !isempty(nt.customerHeap) && nt.pb.custs[nt.customerHeap[1]].tmin <= endTime
		c = nt.pb.custs[Collections.heappop!(nt.customerHeap, tminOrder)]
		taxiIndex = 0; minPickupTime = Inf
		# Free taxis can have either driven no customers at all or dropped off their last customer before the new customer appears
		for k in eachindex(nt.pb.taxis)
			if isempty(nt.sol.custs[k])
				tloc = nt.pb.taxis[k].initPos
				tfree = nt.pb.taxis[k].initTime
			else
				tw = nt.sol.custs[k][end]
				tloc = nt.pb.custs[tw.id].dest
				tfree = tw.tInf + tt[nt.pb.custs[tw.id].orig, tloc] + 2*nt.pb.customerTime
			end
			if (!nt.freeTaxiOnly || tfree <= c.tmin + 2*EPS) &&
					max(tfree, c.tmin) + tt[tloc, c.orig] <= c.tmax
				pickupTime = max(tfree, c.tmin) + tt[tloc, c.orig]
				if pickupTime < minPickupTime
					minPickupTime = pickupTime; taxiIndex = k
				end
			end
		end
		# If there is no closest free taxi, then this customer is not picked up at all
		taxiIndex == 0 && continue
		push!(nt.sol.custs[taxiIndex], CustomerTimeWindow(c.id, minPickupTime, nt.pb.custs[c.id].tmax))
		delete!(nt.sol.rejected, c.id)
	end
end
