#----------------------------------------
#-- mixed integer optimisation,
#-- "taxi k takes customer c after customer d"
#-- and time intervals to take each customer (continuous)
#----------------------------------------

using JuMP, Gurobi

if !isdefined(:TimeWindow)
  #represent a time window
  immutable TimeWindow
    inf::Int
    sup::Int
  end
  if !isdefined(:x)
    x = 2
  end
  #represent a time-window solution
  immutable IntervalSolution
    custs::Vector{Vector{Int}}
    notTaken::Vector{Int}
    intervals::Vector{TimeWindow}
    cost::Float64
  end
end

function intervalBinOpt(pb::TaxiProblem)
  sol = solveBinIntervals(pb)
  custs = [[CustomerAssignment(c, sol.intervals[c].inf, sol.intervals[c].inf +
   pb.sp.traveltime[pb.custs[c].orig,pb.custs[c].dest]) for c in sol.custs[k]] for k in 1:nTaxis]
  return TaxiSolution(
  [ TaxiActions( taxi_path(pb,k,custs[k]), custs[k]) for k in 1:length(pb.taxis)],
    sol.notTaken,
    sol.cost
  )
end

#The MILP formulation, needs the previous computation of the shortest paths
function solveBinIntervals(pb::TaxiProblem)

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
  m = Model(solver= GurobiSolver(TimeLimit=100))

  # =====================================================
  # Decision variables
  # =====================================================

  #Taxi k takes customer c, right after customer c0
  @defVar(m, x[k=1:nTaxis, c=1:nCusts, c0= 1:length(pCusts[c]) ], Bin)
  #Taxi k takes customer c, as a first customer
  @defVar(m, y[k=1:nTaxis,c=1:nCusts], Bin)
  #Time window timesteps
  @defVar(m, tw[c=1:nCusts, t=cust[c].tmin : cust[c].tmaxt] >= cust[c].tmin)



  # =====================================================
  # Objective (do not depend on time windows!)
  # =====================================================
  #Price paid by customers
  @defExpr(customerCost, sum{
  (tc[cust[pCusts[c][c0]].dest, cust[c].orig] +
  tc[cust[c].orig, cust[c].dest] - cust[c].price)*x[k,c,c0],
  k=1:nTaxis, c=1:nCusts, c0= 1:length(pCusts[c])})

  #Price paid by "first customers"
  @defExpr(firstCustomerCost, sum{
  (tc[taxi[k].initPos, cust[c].orig] +
  tc[cust[c].orig, cust[c].dest] - cust[c].price)*y[k,c],
  k=1:nTaxis, c=1:nCusts})


  #Busy time
  @defExpr(busyTime, sum{
  (tt[cust[pCusts[c][c0]].dest, cust[c].orig] +
  tt[cust[c].orig, cust[c].dest] )*(-pb.waitingCost)*x[k,c,c0],
  k=1:nTaxis,c=1:nCusts, c0= 1:length(pCusts[c])})

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
  sum{x[k,c,c0], k=1:nTaxis, c0= 1:length(pCusts[c])} +
  sum{y[k,c], k=1:nTaxis} <= 1)

  #Each customer can only have one next customer
  @addConstraint(m, c2[c0=1:nCusts],
  sum{x[k,c,id], k=1:nTaxis, (c,id) = nextCusts[c0]} <= 1)

  #Only one first customer per taxi
  @addConstraint(m, c3[k=1:nTaxis],
  sum{y[k,c], c = 1:nCusts} <= 1)

  #c0 has been taken before by the same taxi
  @addConstraint(m, c4[k=1:nTaxis,c=1:nCusts, c0= 1:length(pCusts[c])],
  sum{x[k,pCusts[c][c0],c1], c1= 1:length(pCusts[pCusts[c][c0]])} +
  y[k,pCusts[c][c0]] >= x[k,c,c0])

  M = 1000 #For bigM method

  #Time window not empty
  @addConstraint(m, c5[c=1:nCusts],
   sum{tw[c,t], t=cust[c].tmin : cust[c].tmaxt} > 0)

  #Compatibility rules
  @addConstraint(m, c6[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c]), t=cust[c].tmin : cust[c].tmaxt],
   sum{tw[c,t2], t2= cust[c].tmin : min(cust[c].tmaxt,
    t - tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] -
   tt[cust[pCusts[c][c0]].dest, cust[c].orig])} >= tw[c, t] + x[k,c,c0] - 1)


  #First move constraint
  @addConstraint(m, c8[k=1:nTaxis,c=1:nCusts,
   t=cust[c].tmin : min(cust[c].tmaxt, tt[taxi[k].initPos, cust[c].orig])],
  tw[c,t] <= 1 - y[k, c])

  status = solve(m)
  tx = getValue(x)
  ty = getValue(y)
  ttw = getValue(tw)

  chain = [0 for i in 1:nCusts]
  first = [0 for i in 1:nTaxis]
  custs = [Int[] for k in 1:nTaxis]

  intervals = Array(TimeWindow,nCusts)
  for c = 1:nCusts
    minT = 0
    for t=cust[c].tmin : cust[c].tmaxt
      if ttw[c,t] >0.9
        minT = t
        break
      end
    end
    maxT = 0
    for t=cust[c].tmaxt : -1 : cust[c].tmin
      if ttw[c,t] >0.9
        maxT = t
        break
      end
    end
    intervals[c] = TimeWindow(minT,maxT)  
  end


  for c =1:nCusts, k = 1:nTaxis
    if ty[k,c] > 0.9
      first[k] = c
    end
  end

  for c =1:nCusts, k = 1:nTaxis, c0=1:length(pCusts[c])
    if tx[k,c,c0] > 0.9
      chain[pCusts[c][c0]] = c
    end
  end

  notTakenMask = trues(nCusts)
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
  notTaken = [1:nCusts][notTakenMask]

  for k=1:nTaxis
    if first[k] != 0
      tempC = first[k]
      while tempC != 0
        push!(custs[k], tempC)
        tempC = chain[tempC]
      end
    end
  end
  return IntervalSolution(custs,notTaken, intervals, getObjectiveValue(m) )
end
