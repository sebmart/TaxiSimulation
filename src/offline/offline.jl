###################################################
## offline/offline.jl
## basics of offline problem solving
###################################################

"""
    `CustomerTimeWindow`, the pickup time window of a customer
"""
mutable struct CustomerTimeWindow
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
struct OfflineSolution
    "corresponding TaxiProblem"
    pb::TaxiProblem
    "assignments to each taxi"
    custs::Vector{Vector{CustomerTimeWindow}}
    "rejected customers"
    rejected::DataStructures.IntSet
    "solution's profit"
    profit::Float64
end

function Base.show(io::IO, sol::OfflineSolution)
    nCusts = length(sol.pb.custs); nTaxis = length(sol.pb.taxis)
    println(io, "Offline Solution, problem with $nCusts customers and $nTaxis taxis")
    @printf(io, "Profit : %.2f dollars\n", sol.profit)
    println(io, "$(length(sol.rejected)) customers rejected. ")
    println(io, "==========================================")
    println(io, Metrics(sol))
end

"by default, all taxis wait"
OfflineSolution(pb::TaxiProblem) =
    OfflineSolution(pb,
                    [CustomerAssignment[] for k in 1:length(pb.taxis)],
                    DataStructures.IntSet(eachindex(pb.custs)),
                    -length(pb.taxis)*pb.waitingCost*pb.simTime)
OfflineSolution(pb::TaxiProblem, custs::Vector{Vector{CustomerTimeWindow}})=
OfflineSolution(pb, custs, getRejected(pb, custs), computeMetrics(pb, custs))

"""
    `BenchmarkPoint`, Benchmark points for offline solvers
"""
struct BenchmarkPoint
    "computation time"
    time::Float64
    "profit"
    profit::Float64
    "upper-bound on profit"
    bound::Float64
end

copySolution(sol::OfflineSolution) = OfflineSolution( sol.pb, deepcopy(sol.custs), copy(sol.rejected), sol.profit)
