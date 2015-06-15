#----------------------------------------
#-- mixed integer optimisation,
#-- "taxi k takes customer c after customer d"
#-- and time intervals to take each customer (continuous)
#-- NOT GUARANTED FOR SOLVING DISCRETE TIME!
#----------------------------------------

using JuMP, Gurobi


function intervalOpt(pb::TaxiProblem)
  sol = solveIntervalsBis(pb)
  custs = [[CustomerAssignment(c.id, c.tInf, c.tInf +
   pb.sp.traveltime[pb.custs[c.id].orig,pb.custs[c.id].dest]) for c in sol.custs[k]] for k in 1:length(pb.taxis)]
  return TaxiSolution(
  [ TaxiActions( taxi_path(pb,k,custs[k]), custs[k]) for k in 1:length(pb.taxis)],
    sol.notTaken,
    sol.cost
  )
end

#The MILP formulation, needs the previous computation of the shortest paths
function solveIntervals(pb::TaxiProblem, init::TaxiSolution =TaxiSolution(TaxiActions[],Int[],0.))

  taxi = pb.taxis
  cust = pb.custs
  nTime = pb.nTime

  nTaxis = length(taxi)
  nCusts = length(cust)

  #short alias
  tt = pb.sp.traveltime
  tc = pb.sp.travelcost

  #Compute the list of the lists of customers that can be taken
  #before each customer
  pCusts, nextCusts = customersCompatibility(pb::TaxiProblem)


  #Solver : Gurobi (modify parameters)
  m = Model(solver= GurobiSolver(TimeLimit=250,MIPFocus=1))

  # =====================================================
  # Decision variables
  # =====================================================

  #Taxi k takes customer c, right after customer c0
  @defVar(m, x[c=1:nCusts, c0= 1:length(pCusts[c]) ], Bin)
  #Taxi k takes customer c, as a first customer
  @defVar(m, y[k=1:nTaxis,c=1:nCusts], Bin)
  #Lower bound of pick-up time window
  @defVar(m, i[c=1:nCusts] >= cust[c].tmin)
  #Upper bound of pick-up time window
  @defVar(m, s[c=1:nCusts] <= cust[c].tmaxt)

  # =====================================================
  # Initialisation
  # =====================================================
  if length(init.taxis) == length(pb.taxis)
    for c=1:nCusts, c0 =1:length(pCusts[c])
      setValue(x[c,c0],0)
    end
    for k=1:nTaxis, c=1:nCusts
      setValue(y[k,c],0)
    end

    windows = timeWindows(pb,init)
    for (c,w) in enumerate(pb.custs)
        setValue(i[c],w.tmin)
        setValue(s[c],w.tmaxt)
    end
    for (k,l) in enumerate(windows)
      if length(l) > 0
        setValue(y[k,l[1].id], 1)
        setValue(i[l[1].id],l[1].tInf)
        setValue(s[l[1].id],l[1].tSup)
      end
      for i= 2:length(l)
        setValue(
        x[l[i].id, findfirst(pCusts[l[i].id], l[i-1].id)], 1)
        setValue(i[l[i].id],l[i].tInf)
        setValue(s[l[i].id],l[i].tSup)
      end

    end
  end

  # =====================================================
  # Objective (do not depend on time windows!)
  # =====================================================
  #Price paid by customers
  @defExpr(customerCost, sum{
  (tc[cust[pCusts[c][c0]].dest, cust[c].orig] +
  tc[cust[c].orig, cust[c].dest] - cust[c].price)*x[c,c0],
  c=1:nCusts, c0= 1:length(pCusts[c])})

  #Price paid by "first customers"
  @defExpr(firstCustomerCost, sum{
  (tc[taxi[k].initPos, cust[c].orig] +
  tc[cust[c].orig, cust[c].dest] - cust[c].price)*y[k,c],
  k=1:nTaxis, c=1:nCusts})


  #Busy time
  @defExpr(busyTime, sum{
  (tt[cust[pCusts[c][c0]].dest, cust[c].orig] +
  tt[cust[c].orig, cust[c].dest] )*(-pb.waitingCost)*x[c,c0],
  c=1:nCusts, c0= 1:length(pCusts[c])})

  #Busy time during "first customer"
  @defExpr(firstBusyTime, sum{
  (tt[taxi[k].initPos, cust[c].orig] +
  tt[cust[c].orig, cust[c].dest] )*(-pb.waitingCost)*y[k,c],
  k=1:nTaxis, c=1:nCusts})

  @setObjective(m,Min, customerCost + firstCustomerCost +
   busyTime + firstBusyTime + nTime*nTaxis*pb.waitingCost )

  # =====================================================
  # Constraints
  # =====================================================

  #Each customer can only be taken at most once and can only have one other customer before
  @addConstraint(m, c1[c=1:nCusts],
  sum{x[c,c0], c0= 1:length(pCusts[c])} +
  sum{y[k,c], k=1:nTaxis} <= 1)

  #Each customer can only have one next customer
  @addConstraint(m, c2[c0=1:nCusts],
  sum{x[c,id], (c,id) = nextCusts[c0]} <= 1)

  #Only one first customer per taxi
  @addConstraint(m, c3[k=1:nTaxis],
  sum{y[k,c], c = 1:nCusts} <= 1)

  #c0 has been taken before by the same taxi
  @addConstraint(m, c4[c=1:nCusts, c0= 1:length(pCusts[c])],
  sum{x[pCusts[c][c0],c1], c1= 1:length(pCusts[pCusts[c][c0]])} +
  sum{y[k,pCusts[c][c0]], k=1:nTaxis} >= x[c,c0])

  M = 1000 #For bigM method

  #inf <= sup
  @addConstraint(m, c5[c=1:nCusts],
  i[c] <= s[c])

  #Sup bounds rules
  @addConstraint(m, c6[c=1:nCusts, c0=1:length(pCusts[c])],
  s[pCusts[c][c0]] + tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] +
  tt[cust[pCusts[c][c0]].dest, cust[c].orig] - s[c] <= M*(1 - x[c, c0]))

  #Inf bounds rules
  @addConstraint(m, c7[c=1:nCusts, c0=1:length(pCusts[c])],
  i[pCusts[c][c0]] + tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] +
  tt[cust[pCusts[c][c0]].dest, cust[c].orig] - i[c] <= M*(1 - x[c, c0]))
  #First move constraint
  @addConstraint(m, c8[k=1:nTaxis,c=1:nCusts],
  i[c] - tt[taxi[k].initPos, cust[c].orig] >= M*(y[k, c] - 1))

  status = solve(m)
  tx = getValue(x)
  ty = getValue(y)
  ti = getValue(i)
  ts = getValue(s)

  chain = [0 for i in 1:nCusts]
  first = [0 for i in 1:nTaxis]
  custs = [AssignedCustomer[] for k in 1:nTaxis]



  for c =1:nCusts, k = 1:nTaxis
    if ty[k,c] > 0.9
      first[k] = c
    end
  end

  for c =1:nCusts,  c0=1:length(pCusts[c])
    if tx[c,c0] > 0.9
      chain[pCusts[c][c0]] = c
    end
  end

  notTaken = trues(nCusts)
  for k= 1:nTaxis
    if first[k] > 0
      notTakenMask[first[k]] = false
    end
  end
  for c= 1:nCusts
    if chain[c] > 0
      notTakenMask[chain[c]] = false
    end
  end

  for k=1:nTaxis
    if first[k] != 0
      tempC = first[k]
      while tempC != 0
        push!(custs[k], IntervalSolution(tempC, int(ti[tempC]), int(ts[tempC])))
        tempC = chain[tempC]
      end
    end
  end
  return IntervalSolution(custs,notTaken, getObjectiveValue(m) )
end
