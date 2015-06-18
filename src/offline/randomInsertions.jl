#----------------------------------------
#-- Try random orders, keep the best one
#----------------------------------------
include("orderedInsertions.jl")
function randomInsertions(pb::TaxiProblem, n::Int)
  initT = time()
  order = randomOrder(pb)
  best = orderedInsertions(pb, order)
  println("Try: 1, $(-best.cost) dollars")
  for trys in 2:n
    sol = orderedInsertions(pb, order)

    if sol.cost < best.cost
      println("Try: $trys, $(-sol.cost) dollars")
      best = sol
    end

    order = randomOrder(pb)
  end
  println("Final: $(-best.cost) dollars")
  return best
end