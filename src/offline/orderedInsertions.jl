#----------------------------------------
#-- Compute a solution, given an order on customers (multiple insertions)
#----------------------------------------

include("moveCustomer.jl")


#Only return cost and list of assignment, given problem and order on customers
function orderedInsertions(pb::TaxiProblem, order::Vector{Int} = collect(1:length(pb.custs)))
  nTaxis, nCusts = length(pb.taxis), length(pb.custs)

  custs = [CustomerAssignment[] for k in 1:nTaxis]
  sol = IntervalSolution(custs, trues( length(pb.custs)), 0.)
  for i in 1:nCusts
    c = order[i]
    insertCustomer!(pb, sol, c)
  end
  sol.cost = solutionCost(pb,sol.custs)
  return sol
end
