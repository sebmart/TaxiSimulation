using JuMP
using Gurobi

#The MILP formulation, needs the previous computation of the shortest paths
function simpleOpt(pb::TaxiProblem, init::TaxiSolution; useInit = true)

  sp = pb.sp

  taxi = pb.taxis
  cust = pb.custs
  nTime = pb.nTime

  nTaxis = length(taxi)
  nCusts = length(cust)

  #short alias
  tt = sp.traveltime
  tc = sp.travelcost

  #Compute the list of the lists of customers that can be before each customer
  pCusts = Array(Array{Int,1},nCusts)
  nextCusts = Array(Array{(Int,Int),1},nCusts)
  for i=1:nCusts
    nextCusts[i] = (Int,Int)[]
  end

  for (i,c1) in enumerate(cust)
    pCusts[i]= filter(c2->c2 != i && cust[c2].tmin +
    tt[cust[c2].orig, cust[c2].dest] + tt[cust[c2].dest, c1.orig] <= c1.tmaxt,
    [1:nCusts])
    for (id,j) in enumerate(pCusts[i])
      push!(nextCusts[j], (i,id))
    end
  end


  #Solver : Gurobi (modify parameters)
  m = Model( solver= GurobiSolver( TimeLimit=100,MIPFocus=1))

  # =====================================================
  # Decision variables
  # =====================================================

  #Taxi k takes customer c at time t, after customer c0
  @defVar(m, x[k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c]),
  t=cust[c].tmin : cust[c].tmaxt], Bin)
  #Taxi k takes customer c at time t, as a first customer
  @defVar(m,y[k=1:nTaxis,c=1:nCusts, t=cust[c].tmin : cust[c].tmaxt], Bin)

  # =====================================================
  # Initialisation
  # =====================================================
  if useInit
    for k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c]), t=cust[c].tmin : cust[c].tmaxt
      setValue(x[k,c,c0,t],0)
    end
    for k=1:nTaxis, c=1:nCusts, t=cust[c].tmin : cust[c].tmaxt
      setValue(y[k,c,t],0)
    end

    for (k,t) in enumerate(init.taxis)
      l = t.custs
      if length(l) > 0
        setValue(y[k,l[1],init.custs[l[1]].timeIn], 1)
      end
      for i=2:length(l)
        setValue(
        x[k,l[i],findfirst(pCusts[l[i]],l[i-1]),init.custs[l[i]].timeIn], 1)
      end
    end
  end
  # =====================================================
  # Objective
  # =====================================================
  #Price paid by customers
  @defExpr(customerCost, sum{
  (tc[cust[pCusts[c][c0]].dest, cust[c].orig] +
  tc[cust[c].orig, cust[c].dest] - cust[c].price)*x[k,c,c0,t],
  k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c]),
  t=cust[c].tmin : cust[c].tmaxt})

  #Price paid by "first customers"
  @defExpr(firstCustomerCost, sum{
  (tc[taxi[k].initPos, cust[c].orig] +
  tc[cust[c].orig, cust[c].dest] - cust[c].price)*y[k,c,t],
  k=1:nTaxis, c=1:nCusts,
  t=cust[c].tmin : cust[c].tmaxt})


  #Busy time
  @defExpr(busyTime, sum{
  (tt[cust[pCusts[c][c0]].dest, cust[c].orig] +
  tt[cust[c].orig, cust[c].dest])*(-pb.waitingCost)*x[k,c,c0,t],
  k=1:nTaxis,c=1:nCusts,c0=1:length(pCusts[c]), t=cust[c].tmin : cust[c].tmaxt})

  #Busy time during "first customer"
  @defExpr(firstBusyTime, sum{
  (tt[taxi[k].initPos, cust[c].orig] +
  tt[cust[c].orig, cust[c].dest])*(-pb.waitingCost)*y[k,c,t],
  k=1:nTaxis, c=1:nCusts, t=cust[c].tmin : cust[c].tmaxt})

  @setObjective(m,Min, customerCost + firstCustomerCost +
   busyTime + firstBusyTime + nTime*nTaxis*pb.waitingCost )

  # =====================================================
  # Constraints
  # =====================================================

  #Each customer can only be taken at most once and can only have one other customer before
  @addConstraint(m, c1[c=1:nCusts],
  sum{x[k,c,c0,t],
  k=1:nTaxis, c0=1:length(pCusts[c]), t=cust[c].tmin : cust[c].tmaxt} +
  sum{y[k,c,t],
  k=1:nTaxis, t=cust[c].tmin : cust[c].tmaxt} <= 1
  )

  #Each customer can only have one next customer
  @addConstraint(m, c2[c0=1:nCusts],
  sum{x[k,c,id,t],
  k=1:nTaxis, (c,id) = nextCusts[c0],
  t=cust[c].tmin : cust[c].tmaxt} <= 1
  )

  #Each taxi can only have one first customer
  @addConstraint(m, c3[k=1:nTaxis],
  sum{y[k,c,t], c=1:nCusts,t=cust[c].tmin : cust[c].tmaxt} <= 1
  )

  #c0 has been taken before, at the right time
  @addConstraint(m, c4[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c]),
  t=cust[c].tmin : cust[c].tmaxt],
  sum{x[k,pCusts[c][c0],c1,t1],
  c1=1:length(pCusts[pCusts[c][c0]]),
  t1=cust[pCusts[c][c0]].tmin:min(cust[pCusts[c][c0]].tmaxt,
  t - tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] -
  tt[cust[pCusts[c][c0]].dest, cust[c].orig])} +
  sum{y[k,pCusts[c][c0],t1],
  t1=cust[pCusts[c][c0]].tmin:min(cust[pCusts[c][c0]].tmaxt,
  t - tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] -
  tt[cust[pCusts[c][c0]].dest, cust[c].orig])} >= x[k,c,c0,t])

  #For the special case of a taxi's first customer, the taxis has to have the
  #time to go from its origin to the customer origin

  @addConstraint(m, c5[k=1:nTaxis, c=1:nCusts,
  t=cust[c].tmin:min(cust[c].tmaxt,tt[taxi[k].initPos, cust[c].orig])],
  y[k,c,t] == 0)

  #Each customer must have the time to be dropped before the end
  @addConstraint(m, c6[k=1:nTaxis, c=1:nCusts,
   t=max(cust[c].tmin, nTime - tt[cust[c].orig, cust[c].dest ]):(cust[c].tmaxt)],
  y[k,c,t] == 0
  )
  @addConstraint(m, c7[k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c]),
   t=max(cust[c].tmin, nTime - tt[cust[c].orig, cust[c].dest ]):(cust[c].tmaxt)],
  x[k,c,c0,t] == 0
  )

  status = solve(m)
  tx = getValue(x)
  ty = getValue(y)

  #custs is (taxi, time_taken, time_dropped) for each customer, with (0,0) if not taken
  res = [CustomerAssignment(0,0,0) for i in 1:nCusts]

  for k=1:nTaxis, c=1:nCusts, t=cust[c].tmin : cust[c].tmaxt
    if ty[k,c,t] == 1
      res[c] = CustomerAssignment(k,t,t+tt[cust[c].orig, cust[c].dest])
    end
  end
  for k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c]), t=cust[c].tmin : cust[c].tmaxt
    if tx[k,c,c0,t] == 1
      res[c] = CustomerAssignment(k,t,t+tt[cust[c].orig, cust[c].dest])
    end
  end
  cpt, nt = customers_per_taxi(nTaxis,res)
  tp = taxi_paths(pb,res,cpt)

  taxiActs = Array(TaxiActions,nTaxis)
  for i = 1:nTaxis
    taxiActs[i] = TaxiActions(tp[i],cpt[i])
  end
  println( getObjectiveValue(m))
  println( solutionCost(pb,taxiActs,res))

  return simpleOpt_solution( pb, getValue(x), getValue(y), getObjectiveValue(m))
end


#several aliases to simplify calls


simpleOpt(pb::TaxiProblem, init::TaxiSolution) =
  simpleOpt(pb,init; useInit = true)

simpleOpt(pb::TaxiProblem) =
    simpleOpt(pb,TaxiSolution(TaxiActions[],Int[],CustomerAssignment[],0.); useInit = false)

function simpleOpt_solution(pb::TaxiProblem, x, y, cost::Float64)
  nTaxis, nCusts = length(pb.taxis), length(pb.custs)
  actions = Array(TaxiActions, nTaxis)
  notTaken = IntSet(1:nCusts)
  for k in 1:nTaxis
    custs = CustomerAssignment[]
    nbCusts =0
    for c=1:nCusts, t=1:pb.cust[c].tmin : pb.cust[c].tmaxt
      if y[k,c,t] > 0.9
        push!( custs, CustomerAssignment(c,t,t+pb.sp.traveltime[pb.custs[c].orig,pb.custs[c].dest]))
        symdiff!(notTaken, c) #remove customer c from the non-taken
      end
    end
    while nbCusts < length(custs)
      nbCusts +=1
      c0 = custs[end].id
      for c=1:nCusts, t=1:pb.cust[c].tmin : pb.cust[c].tmaxt
        if x[k,c,c0,t] > 0.9
          push!( custs, CustomerAssignment(c,t,t+pb.sp.traveltime[pb.custs[c].orig,pb.custs[c].dest]))
          symdiff!(notTaken, c)
        end
      end
    end
    actions[k] = TaxiActions( taxi_path(pb,k,custs), custs)
  end
  return TaxiSolution(actions, collect(notTaken), cost)
end
