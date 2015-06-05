#----------------------------------------
#--Full optimisation model (not tractable)
#----------------------------------------

using JuMP, Gurobi


function fullOpt(pb::TaxiProblem)

  taxi = pb.taxis
  cust = pb.custs
  n    = pb.network

  nTime = pb.nTime
  nTaxis = length(taxi)
  nCusts = length(cust)
  tc = copy(pb.roadCost)
  tt = int(pb.roadTime)

  for i in vertices(n)
    tt[i,i] = 1
    tc[i,i] = pb.waitingCost
  end
  out = [copy(out_neighbors(n,i)) for i in vertices(n)]

  for i in vertices(n)
    push!(out[i],i)
  end
  #Solver : Gurobi (modify parameters)
  m = Model(solver=GurobiSolver(TimeLimit=100,MIPFocus=1))

  # =====================================================
  # Decision variables
  # =====================================================
  @defVar(m, w[k=1:nTaxis,
               t=1:nTime,
               i= vertices(n),
               j= out[i]], Bin)
  @defVar(m, x[k=1:nTaxis,
               c=1:nCusts,
               t=cust[c].tmin : cust[c].tmax], Bin)
  @defVar(m, y[k=1:nTaxis,
               c=1:nCusts,
               t=cust[c].tmin : cust[c].tmax], Bin)

  # =====================================================
  # Objective
  # =====================================================

  #Price paid by customers
  @defExpr(customersIncome, sum{cust[c].price*x[k,c,cust[c].tmax],
                         k=1:nTaxis,
                         c=1:nCusts})

  #Costs of taxi path
  @defExpr(roadcost, sum{tc[i,j]*w[k,t,i,j],
                         k=1:nTaxis,
                         t=1:nTime,
                         i= vertices(n),
                         j= out[i]})

  #Penalizing time with client inside
  @defExpr(clientInside, sum{x[k,c,t] - y[k,c,t],
                         k=1:nTaxis,
                         c=1:nCusts,
                         t=cust[c].tmin:cust[c].tmax})

   #Penalizing time with client waiting
   @defExpr(clientWaiting, sum{ 1- x[k,c,t],
                          k=1:nTaxis,
                          c=1:nCusts,
                          t=cust[c].tmin:cust[c].tmaxt})
  @setObjective(m, Min, roadcost - customersIncome + 0.01 * clientInside + 0.001 * clientWaiting)


  # =====================================================
  # Constraints : PATH
  # =====================================================


  #Travel time after one link, only one link at the same time
  @addConstraint(m, cTaxi1[k=1:nTaxis, t=1:nTime, i= vertices(n),
        j = out[i], tbis= (t+1):min(( t + tt[i,j] -1),nTime)],
                    sum{w[k,tbis,g,h], g= vertices(n), h = out[g]} <= 1 - w[k,t,i,j])

  #A taxi has to take a new link immediately after the previous one
  @addConstraint(m,cTaxi2[k=1:nTaxis, t=1:nTime, i= vertices(n),
        j = out[i]], sum{ w[k, t+tt[i,j], j, g], g in out[j];
      t + tt[i,j] <= nTime} + (((t+tt[i,j]) <= nTime)?0:1) >= w[k,t,i,j])

  #Only one move at the same time
  @addConstraint(m,cTaxi3[k=1:nTaxis, t=1:nTime],
                   sum{w[k,t,i,j], i= vertices(n), j = out[i]} <= 1)

  #Original taxi positions
  @addConstraint(m,cTaxi4[k=1:nTaxis],
                   sum{w[k,1,taxi[k].initPos,j], j in out[taxi[k].initPos]} == 1)


  # =====================================================
  # Constraints : CUSTOMERS
  # =====================================================

  #Variables are increasing in time
  @addConstraint(m,cCust1[k=1:nTaxis, c=1:nCusts, t=cust[c].tmin:(cust[c].tmax-1)],
                   x[k,c,t] <= x[k,c,t+1])

  @addConstraint(m,cCust2[k=1:nTaxis, c=1:nCusts, t=cust[c].tmin:(cust[c].tmax-1)],
                   y[k,c,t] <= y[k,c,t+1])

  #A customer is taken before being dropped
  @addConstraint(m,cCust3[k=1:nTaxis, c=1:nCusts, t=cust[c].tmin:cust[c].tmax],
                   y[k,c,t] <= x[k,c,t])

  #A customer is either taken and dropped or neither
  @addConstraint(m,cCust4[k=1:nTaxis, c=1:nCusts],
                   x[k,c,cust[c].tmax] == y[k,c,cust[c].tmax])

  #A customer cannot be taken twice
  @addConstraint(m,cCust5[c=1:nCusts],
                   sum{x[k,c,cust[c].tmax], k=1:nTaxis}<= 1)

  #A customer can only be taken before the max departure time
  @addConstraint(m,cCust6[k=1:nTaxis, c=1:nCusts, t=cust[c].tmaxt:(cust[c].tmax - 1)],
                   x[k,c,t] == x[k,c,t+1])

  #A taxi cannot have 2 customers at the same time
  @addConstraint(m,cCust7[k=1:nTaxis, t=1:nTime],
        sum{x[k,c,t] - y[k,c,t], c=1:nCusts; cust[c].tmin <= t <= cust[c].tmax} <= 1)

  # =====================================================
  # Constraints : CUSTOMERS AND PATH
  # =====================================================

  #Taking a customer at the right place
  @addConstraint(m,cTaxCust1[k=1:nTaxis, c=1:nCusts, t=(cust[c].tmin+1):(cust[c].tmax)],
        sum{w[k,t,cust[c].orig,j], j in out[cust[c].orig]} >= x[k,c,t] - x[k,c,t-1])

  #Special case : if customer taken immediately
  @addConstraint(m,cTaxCust2[k=1:nTaxis, c=1:nCusts],
      sum{w[k,cust[c].tmin,cust[c].orig, j], j in out[cust[c].orig]} >= x[k,c,cust[c].tmin])

  #Dropping a customer at the right place
  @addConstraint(m,cTaxCust3[k=1:nTaxis, c=1:nCusts, t=(cust[c].tmin + 1):(cust[c].tmax)],
            sum{w[k,t,cust[c].dest,j], j in out[cust[c].dest]} >= y[k,c,t] - y[k,c,t-1])

  #Special case : if customer dropped immediately
  @addConstraint(m,cTaxCust4[k=1:nTaxis, c=1:nCusts],
            sum{w[k, cust[c].tmin,cust[c].dest,j], j in out[cust[c].dest]}
             >= y[k,c,cust[c].tmin])

  status = solve(m)

  tx = getValue(x)
  ty = getValue(y)
  tw = getValue(w)

  sol_c = [ CustomerAssignment[] for i =1:nTaxis]
  notTaken = trues(nCusts)

  for c in 1:nCusts, k in 1:nTaxis
    t1, t2 = 0, 0
    if tx[k,c, cust[c].tmin] > 0.9
      t1 = cust[c].tmin
    end
    for t in cust[c].tmin : cust[c].tmax - 1
      if tx[k,c,t+1] - tx[k,c,t]  > 0.9
        t1 = t+1
      end
      if ty[k,c,t+1] - ty[k,c,t]  > 0.9
        t2 = t+1
      end
    end
    if (t1, t2) != (0,0)

      push!(sol_c[k], CustomerAssignment(c,t1,t2))

      notTaken[c] = false
    end
  end

  for k in 1:nTaxis
    sort!(sol_c[k], by= x->x.timeIn)
  end

  actions = Array(TaxiActions, nTaxis)

  for k in 1:nTaxis
    path = Array(Road, nTime)
    for t in 1:nTime, i= vertices(n), j = out[i]
      if tw[k,t,i,j] > 0.9
        for t2 = t:(t+tt[i,j]-1)
          path[t2] = Road(i,j)
        end
      end
    end
    actions[k] = TaxiActions(path, sol_c[k])
  end
  return TaxiSolution(actions, notTaken, getObjectiveValue(m))
end
