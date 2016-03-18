###################################################
## online/insertonly.jl
## online algorithm that just performs insertions
###################################################

"""
	`InsertOnly`, OfflinePlanning that just performs insertions in taxis timelines
"""
type InsertOnly <: OfflinePlanning
	pb::TaxiProblem
	sol::OfflineSolution
	currentCusts::IntSet

	"Do we perform earliest insertions?"
	earliest::Bool

    function InsertOnly(;earliest::Bool=false)
        io = new()
		io.earliest = earliest
        return io
    end
end

function initialPlanning!(io::InsertOnly)
	sol = OfflineSolution(io.pb)
	sol.rejected = copy(io.currentCusts)
	orderedInsertions!(io.sol, earliest=io.earliest)
end


function updatePlanning!(io::InsertOnly, endTime::Float64, newCustomers::Vector{Int})
	#Insert new customers
    for c in newCustomers
        insertCustomer!(io.sol,c, earliest=io.earliest)
    end
end
