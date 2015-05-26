#----------------------------------------
#--Full optimisation model (not tractable)
#----------------------------------------

using JuMP
using Gurobi


function fullOpt(pb::TaxiProblem, init=0)

  taxi = pb.taxis
  cust = pb.custs
  n    = pb.network
  road = edges(n)

  nTime = pb.nTime
  nTaxis = length(taxi)
  nCusts = length(cust)
  nRoads = num_edges(n)

  initPath = 0
  initCust = 0

  #Solver : Gurobi (modify parameters)
  m = Model(solver=GurobiSolver(TimeLimit=100,MIPFocus=1))

  # =====================================================
  # Decision variables
  # =====================================================
  @defVar(m, w[k=1:nTaxis,
               t=1:nTime,
               e=1:nRoads], Bin)
  @defVar(m, x[k=1:nTaxis,
               c=1:nCusts,
               t=cust[c].tmin : cust[c].tmax], Bin)
  @defVar(m, y[k=1:nTaxis,
               c=1:nCusts,
               t=cust[c].tmin : cust[c].tmax], Bin)

  # =====================================================
  # Warm start
  # =====================================================
  if init != 0
    for k in 1:nTaxis, t in 1:nTime, e=1:nRoads
      setValue(w[k,t,e],0)
    end
    for k in 1:nTaxis, c in 1:nCusts, t=(cust[c].tmin):(cust[c].tmax)
      setValue(x[k,c,t],0)
      setValue(y[k,c,t],0)
    end

    for k in 1:nTaxis
      previous_index = 0
      for t in 1:nTime
        e = init.taxis[k].path[t]
        if road[e].source == road[e].target || e != previous_index
          setValue(w[k,t,e],1)
        end
        previous_index = e
      end
    end

    for k in 1:nTaxis, c in init.taxis[k].custs
      for t = (init.custs[c].timeIn):(cust[c].tmax)
        setValue(x[k,c,t],1)
      end
      for t = (init.custs[c].timeOut):(cust[c].tmax)
        setValue(y[k,c,t],1)
      end
    end
  end

  # =====================================================
  # Objective
  # =====================================================

  #Price paid by customers
  @defExpr(customersIncome, sum{cust[c].price*x[k,c,cust[c].tmax],
                         k=1:nTaxis,
                         c=1:nCusts})

  #Costs of taxi path
  @defExpr(roadcost, sum{travelcost(road[e])*w[k,t,e],
                         k=1:nTaxis,
                         t=1:nTime,
                         e=1:nRoads})

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
  @addConstraint(m, cTaxi1[k=1:nTaxis, t=1:nTime, e=1:nRoads,
                           tbis=(t+1):min((t+traveltime(road[e])-1),nTime)],
                    sum{w[k,tbis,ebis], ebis=1:nRoads} <= 1 - w[k,t,e])

  #A taxi has to take a new link immediately after the previous one
  @addConstraint(m,cTaxi2[k=1:nTaxis, t=1:nTime, e=1:nRoads],
      sum{w[k,t+traveltime(road[e]),ebis], ebis in [ed.index for ed in out_edges(road[e].target,n)];
      t+traveltime(road[e]) <= nTime} + ((t+traveltime(road[e]) <= nTime)?0:1) >= w[k,t,e])

  #Only one move at the same time
  @addConstraint(m,cTaxi3[k=1:nTaxis, t=1:nTime],
                   sum{w[k,t,e], e=1:nRoads} <= 1)

  #Original taxi positions
  @addConstraint(m,cTaxi4[k=1:nTaxis],
                   sum{w[k,1,e], e in [ed.index for ed in out_edges(taxi[k].initPos,n)]} == 1)


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
        sum{w[k,t,e], e in [ed.index for ed in out_edges(cust[c].orig, n)]} >= x[k,c,t] - x[k,c,t-1])

  #Special case : if customer taken immediately
  @addConstraint(m,cTaxCust2[k=1:nTaxis, c=1:nCusts],
      sum{w[k,cust[c].tmin,e], e in [ed.index for ed in out_edges(cust[c].orig, n)]} >= x[k,c,cust[c].tmin])

  #Dropping a customer at the right place
  @addConstraint(m,cTaxCust3[k=1:nTaxis, c=1:nCusts, t=(cust[c].tmin + 1):(cust[c].tmax)],
            sum{w[k,t,e], e in [ed.index for ed in out_edges(cust[c].dest, n)]} >= y[k,c,t] - y[k,c,t-1])

  #Special case : if customer dropped immediately
  @addConstraint(m,cTaxCust4[k=1:nTaxis, c=1:nCusts],
            sum{w[k, cust[c].tmin, e], e in [ed.index for ed in out_edges(cust[c].dest,n)]}
             >= y[k,c,cust[c].tmin])

  status = solve(m)

  tx = getValue(x)
  ty = getValue(y)
  tw = getValue(w)

  sol_t = Array(TaxiActions, nTaxis)
  sol_c = Array(CustomerAssignment, nCusts)

  for c in 1:nCusts
    sol_c[c] = CustomerAssignment(0,0,0)
  end

  for c in 1:nCusts, k in 1:nTaxis
    if tx[k,c, cust[c].tmin] == 1
      sol_c[c] = CustomerAssignment(k,cust[c].tmin,0)
    end
    for t in cust[c].tmin : cust[c].tmax - 1
      if tx[k,c,t+1] - tx[k,c,t]  == 1
        sol_c[c] = CustomerAssignment(k,t+1,0)
      end
      if ty[k,c,t+1] - ty[k,c,t]  == 1
        sol_c[c] = CustomerAssignment(k,sol_c[c].timeIn,t+1)
      end
    end
  end

  temp_cpt, sol_ntc = customers_per_taxi(nTaxis,sol_c)

  for k in 1:nTaxis
    path = Array(Int, nTime)
    for t in 1:nTime, e in 1:nRoads
      if tw[k,t,e] == 1
        for t2 = t:(t+traveltime(road[e])-1)
          path[t2] = e
        end
      end
    end
    sol_t[k] = TaxiActions(path,temp_cpt[k])
  end
  return TaxiSolution(sol_t,sol_ntc,sol_c,solutionCost(pb,sol_t,sol_c))
end
