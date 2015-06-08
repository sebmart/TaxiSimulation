#-------------------------------------------------------------
#-- Local changes on window solution to look for a better one
#--------------------------------------------------------------
include("insertCustomer.jl")



function localOpt(pb::TaxiProblem, maxTry::Int, removed::Int = 2, start::IntervalSolution = offlineAssignmentQuick(pb))
  nTaxis = length(pb.taxis)
  nCusts = length(pb.custs)
  println("Try: 1, $(-start.cost) dollars")
  best = copySolution(start)

  for trys in 1:maxTry
    sol = copySolution(best)
    freeCusts = [1:nCusts][sol.notTaken]
    for r in 1:min(removed, nCusts - length(freeCusts))
      #taxi to remove the customer from
      k = rand(1:nTaxis)
      while length(sol.custs[k]) == 0
        k = rand(1:nTaxis)
      end
      i = rand(1: length(sol.custs[k]))
      removeCustomer!(pb,sol,k,i)
    end
    freeCusts = [1:nCusts][sol.notTaken]
    order = randomOrder( length(freeCusts))

    for i in 1:length(freeCusts)
      c = freeCusts[order[i]]
      insertCustomer!(pb, sol, c)
    end
    cost = solutionCost(pb, sol.custs)
    if cost <= best.cost
      if cost < best.cost
        println("====Try: $(trys), $(-cost) dollars")
      end
      best = sol
      best.cost = cost
    end
  end
  println("Final: $(-best.cost) dollars")

  return best
end
