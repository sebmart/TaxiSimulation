#----------------------------------------



"Represents the pickup time window of a customer"
type AssignedCustomer
    id::Int
    tInf::Float64
    tSup::Float64
end

"represents a time-window solution (only work with fixed timings)"
type IntervalSolution
    custs::Vector{Vector{AssignedCustomer}}
    notTaken::BitVector
    cost::Float64
end

"represents update to an Interval Solution"
type SolutionUpdate
    taxi::Int
    custs::Vector{AssignedCustomer}
end

"represents updates to an Interval Solution"
typealias PartialSolution Dict{Int,Vector{AssignedCustomer}}

"x and y coordinates, to represent ENU positions"
immutable Coordinates
    x::Float64
    y::Float64
end

"Benchmark points for offline solvers"
immutable BenchmarkPoint
    time::Float64
    revenue::Float64
    bound::Float64
end

const EmptyUpdate = PartialSolution()


"""
Type used to solve online simulation problems
Needs to implement initialize!(om::OnlineMethod, pb::TaxiProblem), update!(om::OnlineMethod,
    newEndTime::Float64, newCustomers::Vector{Customer})
    initialize! initializes a given OnlineMethod with a selected taxi problem without customers
    update! updates OnlineMethod to account for new customers, returns a list of TaxiActions
    since the last update
"""

abstract OnlineMethod

#time epsilon for float comparisons
