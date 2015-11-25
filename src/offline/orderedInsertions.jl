#----------------------------------------
#-- Compute a solution, given an order on customers (multiple insertions)
#----------------------------------------

#Only return cost and list of assignment, given problem and order on customers
function orderedInsertions(pb::TaxiProblem, order::Vector{Int} = timeOrderedCustomers(pb))
    nTaxis, nCusts = length(pb.taxis), length(pb.custs)

    custs = [CustomerAssignment[] for k in 1:nTaxis]
    sol = IntervalSolution(pb)
    for i in 1:nCusts
        c = order[i]
        insertCustomer!(pb, sol, c)
    end
    sol.cost = solutionCost(pb,sol.custs)
    return sol
end

timeOrderedCustomers(pb::TaxiProblem) =
sort(collect(1:length(pb.custs)),by = i -> pb.custs[i].tmin)
