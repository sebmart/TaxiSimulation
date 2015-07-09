#----------------------------------------
#-- 0-1 optimisation, "taxi k takes customer c at time t after customer d"
#----------------------------------------

#The MILP formulation, needs the previous computation of the shortest paths
function fixedTimeOpt(pb::TaxiProblem, init::TaxiSolution =TaxiSolution(TaxiActions[],Int[],0.))
    if !pb.discreteTime
        error("fixedTimeOpt needs a city with discrete times")
    end
    taxi = pb.taxis
    cust = pb.custs
    nTime = toInt(pb.nTime)

    nTaxis = length(taxi)
    nCusts = length(cust)

    #short alias
    tt = round(Int,traveltimes(pb))
    tc = travelcosts(pb)

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
    t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)], Bin)
    #Taxi k takes customer c at time t, as a first customer
    @defVar(m,y[k=1:nTaxis,c=1:nCusts, t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)], Bin)

    # =====================================================
    # Initialisation
    # =====================================================
    if length(init.taxis) == length(pb.taxis)
        for k=1:nTaxis, c=1:nCusts, c0=1:length(pCusts[c]), t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)
            setValue(x[k,c,c0,t],0)
        end
        for k=1:nTaxis, c=1:nCusts, t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)
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
    t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)})

    #Price paid by "first customers"
    @defExpr(firstCustomerCost, sum{
    (tc[taxi[k].initPos, cust[c].orig] +
    tc[cust[c].orig, cust[c].dest] - cust[c].price)*y[k,c,t],
    k=1:nTaxis, c=1:nCusts,
    t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)})


    #Busy time
    @defExpr(busyTime, sum{
    (tt[cust[pCusts[c][c0]].dest, cust[c].orig] +
    tt[cust[c].orig, cust[c].dest])*(-pb.waitingCost)*x[k,c,c0,t],
    k=1:nTaxis,c=1:nCusts,c0=1:length(pCusts[c]), t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)})

    #Busy time during "first customer"
    @defExpr(firstBusyTime, sum{
    (tt[taxi[k].initPos, cust[c].orig] +
    tt[cust[c].orig, cust[c].dest])*(-pb.waitingCost)*y[k,c,t],
    k=1:nTaxis, c=1:nCusts, t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)})

    @setObjective(m,Min, customerCost + firstCustomerCost +
    busyTime + firstBusyTime + nTime*nTaxis*pb.waitingCost )

    # =====================================================
    # Constraints
    # =====================================================

    #Each customer can only be taken at most once and can only have one other customer before
    @addConstraint(m, c1[c=1:nCusts],
    sum{x[k,c,c0,t],
    k=1:nTaxis, c0=1:length(pCusts[c]), t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)} +
    sum{y[k,c,t],
    k=1:nTaxis, t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)} <= 1
    )

    #Each customer can only have one next customer
    @addConstraint(m, c2[c0=1:nCusts],
    sum{x[k,c,id,t],
    k=1:nTaxis, (c,id) = nextCusts[c0],
    t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)} <= 1
    )

    #Each taxi can only have one first customer
    @addConstraint(m, c3[k=1:nTaxis],
    sum{y[k,c,t], c=1:nCusts,t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)} <= 1
    )

    #c0 has been taken before, at the right time
    @addConstraint(m, c4[k=1:nTaxis,c=1:nCusts, c0=1:length(pCusts[c]),
    t=toInt(cust[c].tmin) : toInt(cust[c].tmaxt)],
    sum{x[k,pCusts[c][c0],c1,t1],
    c1=1:length(pCusts[pCusts[c][c0]]),
    t1=toInt(cust[pCusts[c][c0]].tmin):toInt(min(cust[pCusts[c][c0]].tmaxt,
    t - tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] -
    tt[cust[pCusts[c][c0]].dest, cust[c].orig]))} +
    sum{y[k,pCusts[c][c0],t1],
    t1=toInt(cust[pCusts[c][c0]].tmin):toInt(min(cust[pCusts[c][c0]].tmaxt,
    t - tt[cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest] -
    tt[cust[pCusts[c][c0]].dest, cust[c].orig]))} >= x[k,c,c0,t])

    #For the special case of a taxi's first customer, the taxis has to have the
    #time to go from its origin to the customer origin

    @addConstraint(m, c5[k=1:nTaxis, c=1:nCusts,
    t=toInt(cust[c].tmin):toInt(min(cust[c].tmaxt,tt[taxi[k].initPos, cust[c].orig]-1))],
    y[k,c,t] == 0)

    status = solve(m)
    tx = getValue(x)
    ty = getValue(y)

    rev = getObjectiveValue(m)

    println("Final revenue = $(-rev) dollars")


    return fixedTime_solution( pb, pCusts, getValue(x), getValue(y), rev)
end


#Gives return the solution in the right form given the solution of the optimisation problem

function fixedTime_solution(pb::TaxiProblem, pCusts::Vector{Vector{Int}}, x, y, cost::Float64)
    nTaxis, nCusts = length(pb.taxis), length(pb.custs)
    tt = traveltimes(pb)
    result = Vector{AssignedCustomer}[AssignedCustomer[] for k in 1:nTaxis]
    notTaken = trues(nCusts)

    for k=1:nTaxis
        for c =1:nCusts, t = toInt(pb.custs[c].tmin) : toInt(pb.custs[c].tmaxt)
            if y[k,c,t] > 0.9
                push!(result[k], AssignedCustomer(c,t,t))
                notTaken[c] = false
            end
        end

        for c =1:nCusts, t=toInt(pb.custs[c].tmin) : toInt(pb.custs[c].tmaxt),
            c0= 1:length(pCusts[c])
            if x[k,c,c0,t] > 0.9
                push!(result[k], AssignedCustomer(c,t,t))
                notTaken[c] = false
            end
        end
        sort!(result[k], by= x->x.tInf)
    end
    sol = IntervalSolution(result, notTaken, cost)
    expandWindows!(pb, sol)

    return sol
end
