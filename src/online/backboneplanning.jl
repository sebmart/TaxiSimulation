###################################################
## online/backboneplanning.jl
## specific online algorithm that maintain an offline solution in the form of a backbone
## and use local backbone search to optimize the current solution
###################################################


"""
    `BackbonePlanning` : OnlineAlgorithm subtype that maintains a FlowProblem and an offline
    FlowSolution. Use local backbone search to solve the problem at each iteration.
"""
type BackbonePlanning <: OnlineAlgorithm


end

function initialize!(bp::BackbonePlanning, pb::TaxiProblem)

end

function onlineUpdate!(bp::BackbonePlanning, endTime::Float64, newCustomers::Vector{Customer})
    return nothing
end
