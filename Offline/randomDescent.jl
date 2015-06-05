#----------------------------------------
#-- Random "gradient descent"
#----------------------------------------
include("offlineAssignment.jl")
results = (Float64,Float64)[]
function randomDescentOrder(pb::TaxiProblem, n::Int, start::Vector{Int} = [1:length(pb.custs)])
  initT = time()
  sp = pb.sp

  order = start

  best = offlineAssignmentQuick(pb, order)
  println("Try: 1, $(-best.cost) dollars")

  for trys in 2:n
    #We do only on transposition from the best costn
    i = rand(1:length(order))
    j = i
    while i == j
      j = rand(1:length(order))
    end

    order[i], order[j] = order[j], order[i]

    sol = offlineAssignmentQuick(pb, order)
    if sol.cost <= best.cost
      if sol.cost < best.cost
        push!(results, (time()-initT, -sol.cost))
        println("====Try: $(trys), $(-sol.cost) dollars")
        best = sol
      end
      order[i], order[j] = order[j], order[i]
    end
    order[i], order[j] = order[j], order[i]
  end
  println("Final: $(-best.cost) dollars")

  return (TaxiSolution(pb, best), order)
end

randomDescent(pb::TaxiProblem, n::Int, start::Vector{Int} = [1:length(pb.custs)]) =
  randomDescentOrder(pb,n,start)[1]
