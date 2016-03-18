###################################################
## online/tools.jl
## tools for online solving
###################################################

"""
    `partialSolution`, returns empty partial offline solution (some customers are not considered)
"""
partialOfflineSolution(pb::TaxiProblem, custs::IntSet) =
OfflineSolution(pb,
                [CustomerAssignment[] for k in 1:length(pb.taxis)],
                copy(custs),
                -length(pb.taxis)*pb.waitingCost*pb.simTime)
