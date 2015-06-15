#-------------------------------------------------------------
#-- Local changes on window solution to look for a better one
#--------------------------------------------------------------
include("moveCustomer.jl")

function localOpt(pb::TaxiProblem, maxTry::Int, start::IntervalSolution = offlineAssignmentQuick(pb))
  println("Start, $(-start.cost) dollars")
  sol =  copySolution(start)
  best = sol.cost
  for trys in 1:maxTry
    k = rand(1:nTaxis)
    k2 = rand( 1 :(nTaxis-1))
    k2 =  k2 >= k ? k2+1 : k2
    if isempty(sol.custs[k])
      continue
    end
    i = rand(1:length(sol.custs[k]))
    sol = splitAndMove!(pb, sol, k, i, k2)
    if sol.cost < best
      println("====Try: $(trys), $(-sol.cost) dollars")
      best = sol.cost
    end
  end
  return sol
end
