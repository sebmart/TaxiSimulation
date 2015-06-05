#----------------------------------------
#-- Try random orders, keep the best one
#----------------------------------------
include("offlineAssignment.jl")
resRandom = (Float64,Float64)[]
function randomAssignment(pb::TaxiProblem, n::Int)
  initT = time()
  sp = pb.sp
  order = randomOrder(pb)
  bestCost = Inf
  bestSol = 0
  for trys in 1:n
    cost, sol = offlineAssignmentQuick(pb, order)

    if cost < bestCost
      push!(resRandom, (time()-initT, -cost))
      println("Try: $trys, $(-cost) dollars")
      bestSol = sol
      bestCost=cost
    end

    order = randomOrder(pb)
  end
  println("Final: $(-bestCost) dollars")
  return offlineAssignmentSolution(pb, bestSol, bestCost)
end
