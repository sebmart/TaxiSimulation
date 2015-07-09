type IterativeOffline <: OnlineMethod
	solver::Function
	tHorizon::Float64

	pb::TaxiProblem
	endTime::Float64
	newCustomers::Vector{Customer}
	newTaxiActions::Vector{TaxiActions}

	function IterativeOffline(solver::Function, tHorizon::Float64)
		offline = new()
		offline.solver =  solver
		offline.tHorizon = tHorizon
		return offline
	end
end

# Should store endtime as well
# Change to initialize with no customers at all

# Initializes a given OnlineMethod with a selected taxi problem without customers
function initialize!(om::OnlineMethod, pb::TaxiProblem)
	reducedPb = copy(pb)
end

# Updates OnlineMethod to account for new customers, returns a list of TaxiActions 
# since the last update
function update!(om::OnlineMethod, newEndTime::Float64, newCustomers::Vector{Customer})

end

onlineSimulation(pb, IterativeOffline(solver, 30))