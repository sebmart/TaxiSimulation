#----------------------------------------
#-- 0-1 optimisation, "taxi k takes customer c at time t after customer d"
#----------------------------------------

#The MILP formulation, needs the previous computation of the shortest paths
function simpleOpt(pb::TaxiProblem, init::TaxiSolution =TaxiSolution(TaxiActions[],Int[],0.))

  sp = pb.sp

  taxi = pb.taxis
  cust = pb.custs
  nTime = pb.nTime

  nTaxis = length(taxi)
  nCusts = length(cust)

  #short alias
  tt = int(sp.traveltime)
  tc = sp.travelcost

  #Compute the list of the lists of customers that can be picked-up
  #before each customer
  pCusts, nextCusts = customersCompatibility(pb::TaxiProblem)



  #Solver : Gurobi (modify parameters)
  m = Model( solver= GurobiSolver( TimeLimit=150,MIPFocus=1))

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
  if length(init.taxis) == length(pb.taxis)
    for k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c]), t=cust[c].tmin : cust[c].tmaxt
      setValue(x[k,c,c0,t],0)
    end
    for k=1:nTaxis, c=1:nCusts, t=cust[c].tmin : cust[c].tmaxt
      setValue(y[k,c,t],0)
    end

    for (k,t) in enumerate(init.taxis)
      l = t.custs
      if length(l) > 0
        setValue(y[k,l[1].id,l[1].timeIn], 1)
      end
      for i=2:length(l)
        setValue(
        x[k, l[i].id, findfirst(pCusts[l[i].id], l[i-1].id), l[i].timeIn], 1)
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

  return simpleOpt_solution( pb, pCusts, nextCusts, getValue(x), getValue(y), getObjectiveValue(m))
end


#Gives return the solution in the right form given the solution of the optimisation problem

function simpleOpt_solution(pb::TaxiProblem, pCusts::Vector{Vector{Int}}, nextCusts::Vector{ Vector{ (Int,Int)}}, x, y, cost::Float64)
  nTaxis, nCusts = length(pb.taxis), length(pb.custs)

  chain = [(0,0) for i in 1:nCusts]
  first = [(0,0) for i in 1:nTaxis]

  for c =1:nCusts, k = 1:nTaxis, t = pb.custs[c].tmin : pb.custs[c].tmaxt
    if y[k,c,t] > 0.9
      first[k] = (c,t)
    end
  end

  for c =1:nCusts, t=pb.custs[c].tmin : pb.custs[c].tmaxt, k = 1:nTaxis,
     c0= 1:length(pCusts[c])
    if x[k,c,c0,t] > 0.9
      chain[pCusts[c][c0]] = (c,t)
    end
  end

  notTaken = trues(nCusts)
  for k= 1:nTaxis
    if first[k][1] > 0
      notTaken[first[k][1]] = false
    end
  end
  for c= 1:nCusts
    if chain[c][1] > 0
      notTaken[chain[c][1]] = false
    end
  end

  actions = Array(TaxiActions, nTaxis)
  for k=1:nTaxis
    custs = CustomerAssignment[]
    c, t = first[k]
    while c != 0
      push!( custs, CustomerAssignment(c,t,t+pb.sp.traveltime[pb.custs[c].orig,pb.custs[c].dest]))
      c,t  = chain[c]
    end
    actions[k] = TaxiActions( taxi_path(pb,k,custs), custs)
  end

  return TaxiSolution(actions, notTaken, cost)
end
