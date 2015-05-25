#----------------------------------------
#-- Try random orders, keep the best one
#----------------------------------------
include("offlineAssignment.jl")

function randomAssignment(pb::TaxiProblem, n::Int)
  sp = pb.sp
  order = randomOrder(pb)
  bestCost = Inf
  bestSol = 0
  for trys in 1:n
    cost, sol = offlineAssignment(pb, order)

    if cost < bestCost
      println("Try: $trys, $(-cost) dollars")
      bestSol = sol
      bestCost=cost
    end

    order = randomOrder(pb)
  end
  println("Final: $(-bestCost) dollars")
  cpt, nt = customers_per_taxi(length(pb.taxis),bestSol)
  tp = taxi_paths(pb,bestSol,cpt)

  taxiActs = Array(TaxiActions,nTaxis)
  for i = 1:nTaxis
    taxiActs[i] = TaxiActions(tp[i],cpt[i])
  end
  return TaxiSolution(taxiActs, nt, bestSol, bestCost)
end
