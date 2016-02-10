###################################################
## offline/offline.jl
## basics of offline problem solving
###################################################

"""
    `CustTimeWindow`, the pickup time window of a customer
"""
type CustomerTimeWindow
    "customer's ID"
    id::Int
    "min pickup time"
    tInf::Float64
    "max pickup time"
    tSup::Float64
end

"""
    `OfflineSolution` : compact representation of offline solution
    - `profit = Inf` when not computed
"""
type OfflineSolution
    "corresponding TaxiProblem"
    pb::TaxiProblem
    "assignments to each taxi"
    custs::Vector{Vector{CustomerTimeWindow}}
    "rejected customers"
    rejected::IntSet
    "solution's profit"
    profit::Float64
end

function Base.show(io::IO, sol::OfflineSolution)
    nCusts = length(sol.pb.custs); nTaxis = length(sol.pb.taxis)
    println(io, "Offline Solution, problem with $nCusts customers and $nTaxis taxis")
    @printf(io, "Profit : %.2f dollars\n", sol.profit)
    println(io, "$(length(sol.rejected)) customers rejected. ")
end

"by default, all taxis wait"
OfflineSolution(pb::TaxiProblem) =
    OfflineSolution(pb,
                    [CustomerAssignment[] for k in 1:length(pb.taxis)],
                    trues(length(pb.custs)),
                    -pb.simTime * length(pb.taxis) * pb.waitingCost)
"""
    `PartialSolution`: selected taxis assigned customers
    (used to sparsily represent solution changes)
"""
typealias PartialSolution Dict{Int,Vector{CustomerTimeWindow}}


"""
    `BenchmarkPoint`, Benchmark points for offline solvers
"""
immutable BenchmarkPoint
    "computation time"
    time::Float64
    "profit"
    profit::Float64
    "upper-bound on profit"
    bound::Float64
end

"EmptyUpdate object, to avoid constructing it"
const EmptyUpdate = PartialSolution()
