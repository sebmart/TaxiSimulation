
using JuMP
using Gurobi

#The MILP formulation, needs the previous computation of the shortest paths
function intervalOpt(pb::TaxiProblem, robust::Int, dumb=false)
  #We need the shortestPaths
  if !spComputed(pb)
    shortestPath!(pb)
  end

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
      push!(nextCusts[j],(i,id))
    end
  end


  #Solver : Gurobi (modify parameters)
  m = Model(solver=GurobiSolver(TimeLimit=100))

  # =====================================================
  # Decision variables
  # =====================================================

  #Taxi k takes customer c, right after customer c0
  @defVar(m, x[k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c])], Bin)
  #Taxi k takes customer c, as a first customer
  @defVar(m, y[k=1:nTaxis,c=1:nCusts], Bin)
  #Lower bound of pick-up time window
  @defVar(m, i[c=1:nCusts] >= cust[c].tmin)
  #Upper bound of pick-up time window
  @defVar(m, s[c=1:nCusts] <= cust[c].tmaxt)


  # =====================================================
  # Objective
  # =====================================================
  #Price paid by customers
  @defExpr(customerCost, sum{
  (tc[cust[pCusts[c][c0]].dest, cust[c].orig] +
  tc[cust[c].orig, cust[c].dest] - cust[c].price)*x[k,c,c0],
  k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c])})

  #Price paid by "first customers"
  @defExpr(firstCustomerCost, sum{
  (tc[taxi[k].initPos, cust[c].orig] +
  tc[cust[c].orig, cust[c].dest] - cust[c].price)*y[k,c],
  k=1:nTaxis, c=1:nCusts})


  #Busy time
  @defExpr(busyTime, sum{
  (tt[cust[pCusts[c][c0]].dest, cust[c].orig] +
  tt[cust[c].orig, cust[c].dest])*(-pb.waitingCost)*x[k,c,c0],
  k=1:nTaxis,c=1:nCusts,c0=1:length(pCusts[c])})

  #Busy time during "first customer"
  @defExpr(firstBusyTime, sum{
  (tt[taxi[k].initPos, cust[c].orig] +
  tt[cust[c].orig, cust[c].dest])*(-pb.waitingCost)*y[k,c],
  k=1:nTaxis, c=1:nCusts})

  @setObjective(m,Min, customerCost + firstCustomerCost +
   busyTime + firstBusyTime + nTime*nTaxis*pb.waitingCost )

  # =====================================================
  # Constraints
  # =====================================================

  #Each customer can only be taken at most once and can only have one other customer before
  @addConstraint(m, c1[c=1:nCusts],
  sum{x[k,c,c0], k=1:nTaxis, c0=1:length(pCusts[c])} +
  sum{y[k,c], k=1:nTaxis} <= 1)

  #Each customer can only have one next customer
  @addConstraint(m, c2[c0=1:nCusts],
  sum{x[k,c,id], k=1:nTaxis, (c,id) = nextCusts[c0]} <= 1)

  #Only one first customer per taxi
  @addConstraint(m, c3[k=1:nTaxis],
  sum{y[k,c], c = 1:nCusts} <= 1)

  #c0 has been taken before by the same taxi
  @addConstraint(m, c4[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c])],
  sum{x[k,pCusts[c][c0],c1], c1=1:length(pCusts[pCusts[c][c0]])} +
  y[k,pCusts[c][c0]] >= x[k,c,c0])

  M = 1000 #For bigM method

  #inf <= sup
  @addConstraint(m, c5[c=1:nCusts],
  i[c] <= s[c])

  if dumb
    #Sup bounds rules
    @addConstraint(m, c6[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c])],
    s[pCusts[c][c0]] + tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] +
    tt[cust[pCusts[c][c0]].dest, cust[c].orig] + 2*robust - s[c] <= M*(1 - x[k, c, c0]))

    #Inf bounds rules
    @addConstraint(m, c7[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c])],
    i[pCusts[c][c0]] + tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] +
    tt[cust[pCusts[c][c0]].dest, cust[c].orig] + 2*robust - i[c] <= M*(1 - x[k, c, c0]))
    #First move constraint
    @addConstraint(m, c8[k=1:nTaxis,c=1:nCusts],
    i[c] - robust - tt[taxi[k].initPos, cust[c].orig] >= M*(y[k, c] - 1))
  else
    #Sup bounds rules
    @addConstraint(m, c6[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c])],
    s[pCusts[c][c0]] + tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] +
    tt[cust[pCusts[c][c0]].dest, cust[c].orig] - s[c] <= M*(1 - x[k, c, c0]))

    #Inf bounds rules
    @addConstraint(m, c7[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c])],
    i[pCusts[c][c0]] + tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] +
    tt[cust[pCusts[c][c0]].dest, cust[c].orig] - i[c] <= M*(1 - x[k, c, c0]))
    #First move constraint
    @addConstraint(m, c8[k=1:nTaxis,c=1:nCusts],
    i[c] - tt[taxi[k].initPos, cust[c].orig] >= M*(y[k, c] - 1))
  end
  if !dumb
    #Make it robust
    @addConstraint(m, c9[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c])],
    s[c] - i[pCusts[c][c0]] - tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] -
    tt[cust[pCusts[c][c0]].dest, cust[c].orig] -  robust >= M*(x[k, c, c0] - 1))

    #Same for beginning
    @addConstraint(m, c10[k=1:nTaxis,c=1:nCusts],
    s[c] - tt[taxi[k].initPos, cust[c].orig] - robust >= M*(y[k, c] - 1))
    #Each customer must have the time to be dropped before the end
    #We do not implement
  end
  status = solve(m)
  tx = getValue(x)
  ty = getValue(y)
  ti = getValue(i)
  ts = getValue(s)

  notTaken = Int[]
  chain = [0 for i in 1:nCusts]
  first = [0 for i in 1:nTaxis]
  custs = [Int[] for k in 1:nTaxis]

  intervals = [(int(ti[c]), int(ts[c])) for c=1:nCusts]


  for c =1:nCusts, k = 1:nTaxis
    if ty[k,c] == 1
      first[k] = c
    end
  end

  for c =1:nCusts, k = 1:nTaxis, c0=1:length(pCusts[c])
    if tx[k,c,c0] == 1
      chain[pCusts[c][c0]] = c
    end
  end

  println(first)
  println(chain)
  for c=1:nCusts
    if !in(c, chain) && !in(c, first)
      push!(notTaken,c)
    end
  end
  for k=1:nTaxis
    if first[k] != 0
      tempC = first[k]
      while tempC != 0
        push!(custs[k], tempC)
        tempC = chain[tempC]
      end
    end
  end
  return IntervalSolution(custs,notTaken, intervals,getObjectiveValue(m) )
end

immutable IntervalSolution
  custs::Vector{Vector{Int}}
  notTaken::Vector{Int}
  intervals::Vector{(Int,Int)}
  cost::Float64
end
function printIntervalSolution(sol::IntervalSolution)
    for k in 1:length(sol.custs)
    println("=== TAXI $k")
    println("==========================")
    for c in sol.custs[k]
      println("Takes customer $c in time-window [$(sol.intervals[c][1]),$(sol.intervals[c][2])]")
    end
  end
  if length(sol.notTaken) != 0
    println("=== NOT TAKEN")
    println("==========================")
    if length(sol.notTaken) == 1
      print("Customer $(sol.notTaken[1])")
    else
      print("Customers $(sol.notTaken[1])")
    end
    for i in 2:length(sol.notTaken)
      print(", $(sol.notTaken[i])")
    end
    print("\n")
  end
  println("=== REVENUE OF THE DAY")
  println("==========================")
  @printf("%.2f dollars\n",-sol.cost)
end
