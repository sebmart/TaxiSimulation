#----------------------------------------
#-- Try random orders, keep the best one
#----------------------------------------
include("offlineAssignment.jl")
function randomAssignment(pb::TaxiProblem, n::Int)
  initT = time()
  order = randomOrder(pb)
  best = offlineAssignmentQuick(pb, order)
  println("Try: 1, $(-best.cost) dollars")
  for trys in 2:n
    sol = offlineAssignmentQuick(pb, order)

    if sol.cost < best.cost
      push!(resRandom, (time()-initT, -sol.cost))
      println("Try: $trys, $(-sol.cost) dollars")
      best = sol
    end

    order = randomOrder(pb)
  end
  println("Final: $(-best.cost) dollars")
  return TaxiSolution(pb, best)
end
