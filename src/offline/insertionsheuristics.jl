###################################################
## offline/insertionsheuristics.jl
## offline heuristics using only insertions
###################################################

"""
    `orderedInsertions`, create solution by inserting customers with given order
"""
function orderedInsertions(pb::TaxiProblem, order::Vector{Int} = timeOrderedCustomers(pb); earliest::Bool=false)
    nTaxis, nCusts = length(pb.taxis), length(pb.custs)

    sol = OfflineSolution(pb)
    for i in 1:nCusts
        c = order[i]
        insertCustomer!(sol, c, earliest=earliest)
    end
    sol.profit = solutionProfit(pb,sol.custs)
    return sol
end

timeOrderedCustomers(pb::TaxiProblem) =
sort(collect(1:length(pb.custs)),by = i -> pb.custs[i].tmin)
