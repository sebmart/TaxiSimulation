#----------------------------------------
#-- Random "gradient descent"
#----------------------------------------
include("orderedInsertions.jl")
function insertionsDescent(pb::TaxiProblem, n::Int, start::Vector{Int} = [1:length(pb.custs)])
  order = start
  best = orderedInsertions(pb, order)
  println("Try: 1, $(-best.cost) dollars")

  for trys in 2:n
    #We do only on transposition from the best costn
    i = rand(1:length(order))
    j = i
    while i == j
      j = rand(1:length(order))
    end

    order[i], order[j] = order[j], order[i]

    sol = orderedInsertions(pb, order)
    if sol.cost <= best.cost
      if sol.cost < best.cost
        println("====Try: $(trys), $(-sol.cost) dollars")
      end
      best = sol
      order[i], order[j] = order[j], order[i]
    end
    order[i], order[j] = order[j], order[i]
  end
  println("Final: $(-best.cost) dollars")

  return best
end
