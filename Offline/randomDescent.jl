#----------------------------------------
#-- Random "gradient descent"
#----------------------------------------
include("offlineAssignment.jl")

function randomDescentOrder(pb::TaxiProblem, n::Int, start::Vector{Int} = [1:length(pb.custs)])
  initT = time()
  sp = pb.sp

  order = start
  bestCost = Inf
  bestSol = 0

  bestCost, bestSol = offlineAssignmentQuick(pb, order)
  println("Try: 1, $(-bestCost) dollars")

  for trys in 2:n
    #We do only on transposition from the best costn
    i = rand(1:length(order))
    j = i
    while i == j
      j = rand(1:length(order))
    end

    order[i], order[j] = order[j], order[i]

    cost, sol = offlineAssignmentQuick(pb, order)
    if cost <= bestCost
      if cost < bestCost
        println("====Try: $(trys), $(-cost) dollars")
        bestSol = sol
      end
      bestCost = cost
      order[i], order[j] = order[j], order[i]
    end
    order[i], order[j] = order[j], order[i]
  end
  println("Final: $(-bestCost) dollars")

  return (offlineAssignmentSolution(pb, bestSol, bestCost), order)
end

randomDescent(pb::TaxiProblem, n::Int, start::Vector{Int} = [1:length(pb.custs)]) =
  randomDescentOrder(pb,n,start)[1]
