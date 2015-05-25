#----------------------------------------
#--Separate the taxis decisions of an offline model
#----------------------------------------


function sepTaxis(pb::TaxiProblem, optFunction=simpleOpt)
  nTaxis = length(pb.taxis)
  nCusts = length(pb.custs)

  leftCustomers = copy(pb.custs)
  custIndices = [1:nCusts]
  sol_c = fill(CustomerAssignment(0,0,0),nCusts)
  sol_t = Array(TaxiActions, nTaxis)
  sol_cost = 0.

  newPb = clone(pb)

  for (k,tax) in enumerate(pb.taxis)
    newPb.custs =  leftCustomers
    newPb.taxis = [Taxi(1 ,tax.initPos)]
    sol = optFunction(newPb)
    sol_cost += sol.cost

    temp_custs = Array(Int,length(sol.taxis[1].custs))
    for (i,c) in enumerate(sol.taxis[1].custs)
      temp_custs[i] = custIndices[c]
    end

    sol_t[k] = TaxiActions(sol.taxis[1].path, temp_custs)

    temp = Int[]
    temp2= Int[]
    for (i,c) in enumerate(custIndices)
      if sol.custs[i].taxi != 0
        sol_c[c] = CustomerAssignment(k,sol.custs[i].timeIn,sol.custs[i].timeOut)
        push!(temp,i)
      else
        push!(temp2,i)
      end
    end
    deleteat!(custIndices,temp)

    leftCustomers = [leftCustomers[c] for c in temp2]
  end
  println(solutionCost(pb,sol_t,sol_c))
  println(sol_cost)
  return TaxiSolution(sol_t, custIndices, sol_c, sol_cost)
end
