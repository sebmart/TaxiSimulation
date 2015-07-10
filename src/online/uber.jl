type Uber <: OnlineMethod
	solver::Function
	tHorizon::Float64
	pb::TaxiProblem

	endTime::Float64
	newCustomers::Vector{Customer}
	newTaxiActions::Vector{TaxiActions}

	function Uber(solver::Function, tHorizon::Float64)
		method = new()
		method.solver =  solver
		offline.tHorizon = tHorizon
		return offline
	end
end

# Initializes a given OnlineMethod with a selected taxi problem without customers
function initialize!(om::OnlineMethod, pb::TaxiProblem)
	reducedPb = copy(pb)
	reducedPb.custs = Vector{Customer}
	om.pb = reducedPb
end

# Updates OnlineMethod to account for new customers, returns a list of TaxiActions 
# since the last update
function update!(om::OnlineMethod, newEndTime::Float64, newCustomers::Vector{Customer})

end

onlineSimulation(pb, Uber(UberSolver, 600), 30))

function UberSolver()
