###################################################
## offline/mip.jl
## mixed integer optimisation, time-window based
###################################################



"""
    `mipOpt`: MIP formulation of offline taxi assignment
    can be warmstarted with a solution
"""
mipOpt(pb::TaxiProblem, init::OfflineSolution; arg...) =
mipOpt(pb, Nullable{OfflineSolution}(init), arg...)
mipOpt(pb::TaxiProblem, init::TaxiSolution; args...) =
mipOpt(pb, OfflineSolution(init), args...)


function mipOpt(pb::TaxiProblem, init::Nullable{OfflineSolution} = Nullable{OfflineSolution}(); benchmark=false, solverArgs...)

    taxi = pb.taxis
    cust = pb.custs
    nTime = pb.simTime
    nTaxis = length(taxi)
    nCusts = length(cust)
    if length(cust) == 0.
        return OfflineSolution(pb)
    end

    #short alias
    tt(i::Int, j::Int) = traveltime(pb.times,i,j)
    tc(i::Int, j::Int) = traveltime(pb.costs,i,j)

    #Compute the list of the lists of customers that can be taken
    #before each customer
    pCusts, nextCusts = customersCompatibility(pb::TaxiProblem)

    #Solver : Gurobi (modify parameters)
    m = Model(solver= GurobiSolver(MIPFocus=1, Method=1; solverArgs...))

    # =====================================================
    # Decision variables
    # =====================================================

    #Taxi k takes customer c, right after customer c0
    @defVar(m, x[c=1:nCusts, c0= 1:length(pCusts[c])], Bin)
    #Taxi k takes customer c, as a first customer
    @defVar(m, y[k=1:nTaxis,c=1:nCusts], Bin)
    #Lower bound of pick-up time window
    @defVar(m, i[c=1:nCusts] >= cust[c].tmin)
    #Upper bound of pick-up time window
    @defVar(m, s[c=1:nCusts] <= cust[c].tmax)

    # =====================================================
    # Initialisation
    # =====================================================

    if !isnull(init)
        init = get(init)
        for c=1:nCusts, c0 =1:length(pCusts[c])
            setValue(x[c,c0],0)
        end
        for k=1:nTaxis, c=1:nCusts
            setValue(y[k,c],0)
        end
        for (c,w) in enumerate(pb.custs)
            setValue(i[c],w.tmin)
            setValue(s[c],w.tmax)
        end
        for (k,l) in enumerate(init.custs)
            if length(l) > 0
                setValue(y[k,l[1].id], 1)
                setValue(i[l[1].id],l[1].tInf)
                setValue(s[l[1].id],l[1].tSup)
            end
            for j= 2:length(l)
                setValue(x[l[j].id, findfirst(pCusts[l[j].id], l[j-1].id)], 1)
                setValue(i[l[j].id],l[j].tInf)
                setValue(s[l[j].id],l[j].tSup)
            end
        end
    end

    # =====================================================
    # Objective (do not depend on time windows!)
    # =====================================================
    #Price paid by customers
    @defExpr(customerCost, sum{
    (tc(cust[pCusts[c][c0]].dest, cust[c].orig) +
    tc(cust[c].orig, cust[c].dest) - cust[c].fare)*x[c,c0],
    c=1:nCusts, c0= 1:length(pCusts[c])})

    #Price paid by "first customers"
    @defExpr(firstCustomerCost, sum{
    (tc(taxi[k].initPos, cust[c].orig) +
    tc(cust[c].orig, cust[c].dest) - cust[c].fare)*y[k,c],
    k=1:nTaxis, c=1:nCusts})

    #Busy time
    @defExpr(busyTime, sum{
    (tt(cust[pCusts[c][c0]].dest, cust[c].orig) +
    tt(cust[c].orig, cust[c].dest) )*(-pb.waitingCost)*x[c,c0],
    c=1:nCusts, c0= 1:length(pCusts[c])})

    #Busy time during "first customer"
    @defExpr(firstBusyTime, sum{
    (tt(taxi[k].initPos, cust[c].orig) +
    tt(cust[c].orig, cust[c].dest))*(-pb.waitingCost)*y[k,c],
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

    # M = 100*pb.nTime #For bigM method
    M = 2 * pb.simTime + 2 * longestPathTime(pb.times)
    #inf <= sup
    @addConstraint(m, c5[c=1:nCusts],
    i[c] <= s[c])

    #Sup bounds rules
    @addConstraint(m, c6[c=1:nCusts, c0=1:length(pCusts[c])],
    s[pCusts[c][c0]] + tt(cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest) +
    tt(cust[pCusts[c][c0]].dest, cust[c].orig) + 2*pb.customerTime - s[c] <= M*(1 - x[c, c0]))

    #Inf bounds rules
    @addConstraint(m, c7[c=1:nCusts, c0=1:length(pCusts[c])],
    i[pCusts[c][c0]] + tt(cust[pCusts[c][c0]].orig, cust[pCusts[c][c0]].dest) +
    tt(cust[pCusts[c][c0]].dest, cust[c].orig) + 2*pb.customerTime - i[c] <= M*(1 - x[c, c0]))

    #First move constraint
    @addConstraint(m, c8[k=1:nTaxis,c=1:nCusts],
    i[c] - tt(taxi[k].initPos, cust[c].orig) - taxi[k].initTime >= M*(y[k, c] - 1))

    #to get information
    tstart = time()
    benchData = BenchmarkPoint[]
    function infocallback(cb)
        cost = MathProgBase.cbgetobj(cb)
        bestbound = MathProgBase.cbgetbestbound(cb)
        seconds = time()-tstart
        push!(benchData, BenchmarkPoint(seconds,-cost,-bestbound))
    end
    benchmark && addInfoCallback(m,infocallback)


    status = solve(m)
    if status == :Infeasible
        error("Model is infeasible")
    end

    tx = getValue(x)
    ty = getValue(y)
    ti = getValue(i)
    ts = getValue(s)

    chain = [0 for i in 1:nCusts]
    first = [0 for i in 1:nTaxis]
    custs = [CustomerTimeWindow[] for k in 1:nTaxis]



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

    rejected = IntSet(1:nCusts)
    for k= 1:nTaxis
        if first[k] > 0
            delete!(rejected, first[k])
        end
    end
    for c= 1:nCusts
        if chain[c] > 0
            delete!(rejected, chain[c])
        end
    end

    for k=1:nTaxis
        if first[k] != 0
            tempC = first[k]
            while tempC != 0
                push!(custs[k], CustomerTimeWindow(tempC, ti[tempC], ts[tempC]))
                tempC = chain[tempC]
            end
        end
    end
    s = OfflineSolution(pb,custs, rejected, - getObjectiveValue(m) )

    if benchmark
        o = -s.cost - benchData[end].revenue
        for (i,p) in enumerate(benchData)
            benchData[i] = BenchmarkPoint(p.time,p.revenue + o, p.bound + o)
        end
    end
    benchmark && return (s,benchData)
    return updateTimeWindows!(s)
end

"""
    `customersCompatibility`, returns customers that can be taken before other customers
    - returns: array of previous custs and  next custs for each customer
"""
function customersCompatibility(pb::TaxiProblem)
    cust = pb.custs; nCusts = length(cust)
    tt(i::Int, j::Int) = traveltime(pb.times,i,j)

    pCusts = Array( Vector{Int}, nCusts)
    nextCusts = Array(Vector{Tuple{Int,Int}},nCusts)
    for i=1:nCusts
        nextCusts[i] = Tuple{Int,Int}[]
    end

    for (i,c1) in enumerate(cust)
        pCusts[i]= filter(c2->c2 != i && cust[c2].tmin + 2*pb.customerTime +
        tt(cust[c2].orig, cust[c2].dest) + tt(cust[c2].dest, c1.orig) <= c1.tmax,
        1:nCusts)
        for (id,j) in enumerate(pCusts[i])
            push!(nextCusts[j], (i,id))
        end
    end
    return pCusts, nextCusts
end
