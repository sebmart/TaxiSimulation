###################################################
## offline/mip.jl
## mixed integer optimisation, time-window based
###################################################



"""
    `mipOpt`: MIP formulation of offline taxi assignment
    can be warmstarted with a solution
"""
mipOpt(pb::TaxiProblem, init::OfflineSolution; arg...) =
mipOpt(pb, Nullable{OfflineSolution}(init); arg...)
mipOpt(pb::TaxiProblem, init::TaxiSolution; args...) =
mipOpt(pb, OfflineSolution(init); args...)


function mipOpt(pb::TaxiProblem, init::Nullable{OfflineSolution} = Nullable{OfflineSolution}(); benchmark=false, solverArgs...)

    taxi = pb.taxis
    cust = pb.custs
    if length(cust) == 0.
        return OfflineSolution(pb)
    end

    #short alias
    tt = getPathTimes(pb.times)
    tc = getPathTimes(pb.costs)

    #Compute the list of the lists of customers that can be taken
    #before each customer
    pairs, starts, cID, cRev, pRev, pRev1, pRev2, sRev, sRev1, sRev2 = customersLinks(pb::TaxiProblem)
    #Solver : Gurobi (modify parameters)
    m = Model(solver= GurobiSolver(MIPFocus=1, Method=1; solverArgs...))

    # =====================================================
    # Decision variables
    # =====================================================

    #Taxi k takes customer c, right after customer c0
    @defVar(m, x[k=eachindex(pairs)], Bin)
    #Taxi k takes customer c, as a first customer
    @defVar(m, y[k=eachindex(starts)], Bin)
    #Lower bound of pick-up time window
    @defVar(m, i[c=eachindex(cID)] >= cust[cID[c]].tmin)
    #Upper bound of pick-up time window
    @defVar(m, s[c=eachindex(cID)] <= cust[cID[c]].tmax)

    # =====================================================
    # Initialisation
    # =====================================================

    if !isnull(init)
        init2 = get(init)
        for k=eachindex(pairs)
            setValue(x[k],0)
        end
        for k=eachindex(starts)
            setValue(y[k],0)
        end
        for (c,id) in enumerate(cID)
            setValue(i[c], cust[id].tmin)
            setValue(s[c], cust[id].tmax)
        end
        for (k,l) in enumerate(init2.custs)
            if length(l) > 0
                cr = cRev[l[1].id]
                setValue(y[sRev[k,cr]], 1)
                setValue(i[cr],l[1].tInf)
                setValue(s[cr],l[1].tSup)
                for j= 2:length(l)
                    cr = cRev[l[j].id]
                    setValue(x[pRev[cRev[l[j-1].id],cr]], 1)
                    setValue(i[cr],l[j].tInf)
                    setValue(s[cr],l[j].tSup)
                end
            end
        end
    end

    # =====================================================
    # Objective (do not depend on time windows!)
    # =====================================================
    #Price paid by customers
    @defExpr(customerCost, sum{
    (tc[cust[cRev[p[1]]].dest, cust[cRev[p[2]]].orig] +
    tc[cust[cRev[p[2]]].orig, cust[cRev[p[2]]].dest] - cust[cRev[p[2]]].fare)*x[k],
    (k,p) in enumerate(pairs)})

    #Price paid by "first customers"
    @defExpr(firstCustomerCost, sum{
    (tc[taxi[s[1]].initPos, cust[cRev[s[2]]].orig] +
    tc[cust[cRev[s[2]]].orig, cust[cRev[s[2]]].dest] - cust[cRev[s[2]]].fare)*y[k],
    (k,s) in enumerate(starts)})

    #Busy time
    @defExpr(busyTime, sum{
    (tt[cust[cRev[p[1]]].dest, cust[cRev[p[2]]].orig] +
    tt[cust[cRev[p[2]]].orig, cust[cRev[p[2]]].dest] )*(-pb.waitingCost)*x[k],
    (k,p) in enumerate(pairs)})

    #Busy time during "first customer"
    @defExpr(firstBusyTime, sum{
    (tt[taxi[s[1]].initPos, cust[cRev[s[2]]].orig] +
    tt[cust[cRev[s[2]]].orig, cust[cRev[s[2]]].dest])*(-pb.waitingCost)*y[k],
    (k,s) in enumerate(starts)})

    @setObjective(m,Min, customerCost + firstCustomerCost +
    busyTime + firstBusyTime + pb.simTime*length(pb.taxis)*pb.waitingCost )


    # =====================================================
    # Constraints
    # =====================================================

    #Each customer can only be taken at most once and can only have one other customer before
    @addConstraint(m, c1[c=eachindex(cID)],
    sum{x[k], k= pRev2[c]} +
    sum{y[k], k= sRev2[c]} <= 1)

    #Each customer can only have one next customer
    @addConstraint(m, c2[c=eachindex(cID)],
    sum{x[k], k = pRev1[c]} <= 1)

    #Only one first customer per taxi
    @addConstraint(m, c3[t=eachindex(pb.taxis)],
    sum{y[k], k = sRev1[t]} <= 1)

    #c0 has been taken before c1
    @addConstraint(m, c4[pi in eachindex(pairs)],
    sum{x[k], k = pRev2[pairs[pi][1]]} +
    sum{y[k], k = sRev2[pairs[pi][1]]} >= x[pi])

    # M = 100*pb.simTime #For bigM method
    M = 2 * pb.simTime + 2 * longestPathTime(pb.times)

    #inf <= sup
    @addConstraint(m, c5[c=eachindex(cID)],
    i[c] <= s[c])

    #Sup bounds rules
    @addConstraint(m, c6[k in eachindex(pairs)],
    s[pairs[k][1]] + tt[cust[pairs[k][1]].orig, cust[pairs[k][1]].dest] +
    tt[cust[pairs[k][1]].dest, cust[pairs[k][2]].orig] +
    2*pb.customerTime - s[pairs[k][2]] <= M*(1 - x[k]))

    #Inf bounds rules
    @addConstraint(m, c7[k in eachindex(pairs)],
    i[pairs[k][1]] + tt[cust[pairs[k][1]].orig, cust[pairs[k][1]].dest] +
    tt[cust[pairs[k][1]].dest, cust[pairs[k][2]].orig] +
    2*pb.customerTime - i[pairs[k][2]] <= M*(1 - x[k]))

    #First move constraint
    @addConstraint(m, c8[k in eachindex(starts)],
    i[starts[k][2]] - tt[taxi[starts[k][1]].initPos, cust[starts[k][2]].orig] -
    taxi[starts[k][1]].initTime >= M*(y[k] - 1))

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

    custs = [CustomerTimeWindow[] for k in eachindex(taxi)]

    if !isnull(init) #trick to extract only future rejected
        init2 = get(init)
        trueRejected = getRejected(init2)
        toKeep = setdiff(trueRejected, init2.rejected)
        rejected = setdiff(IntSet(eachindex(cust)), toKeep)
    else
        rejected = IntSet(eachindex(cust))
    end
    # reconstruct solution
    for k in eachindex(starts)
        if ty[k] > 0.9
            t, c = starts[k]
            delete!(rejected, cID[c])
            push!(custs[t], CustomerTimeWindow(cID[c], ti[c], ts[c]))

            while (k2 = findfirst(x->x>0.9, [tx[p] for p in pRev1[c]])) != 0
                c  = pairs[pRev1[c][k2]][2]
                delete!(rejected, cID[c])
                push!(custs[t], CustomerTimeWindow(cID[c], ti[c], ts[c]))
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
function customersLinks(pb::TaxiProblem)
    tt = getPathTimes(pb.times)
    # all customers are considered
    cID = collect(eachindex(pb.custs))
    cRev = Dict([(i,i) for i in eachindex(pb.custs)])
    starts = Tuple{Int,Int}[]
    sRev   = Dict{Tuple{Int,Int},Int}()
    sRev1  = Vector{Int}[Int[] for i=eachindex(pb.taxis)]
    sRev2  = Vector{Int}[Int[] for i=eachindex(pb.custs)]
    pairs  = Tuple{Int,Int}[]
    pRev   = Dict{Tuple{Int,Int},Int}()
    pRev1  = Vector{Int}[Int[] for i=eachindex(pb.custs)]
    pRev2  = Vector{Int}[Int[] for i=eachindex(pb.custs)]

    # first customers
    for t in pb.taxis, c in pb.custs
        if t.initTime + tt[t.initPos, c.orig] <= c.tmax
            push!(starts, (t.id, c.id))
            sRev[t.id,c.id] = length(starts)
            push!(sRev1[t.id], length(starts))
            push!(sRev2[c.id], length(starts))
        end
    end
    # customer pairs
    for c1 in pb.custs, c2 in pb.custs
        if c1.id != c2.id &&
        c1.tmin + tt[c1.orig, c1.dest] + tt[c1.dest, c2.orig] + 2*pb.customerTime <= c2.tmax
            push!(pairs, (c1.id, c2.id))
            pRev[c1.id,c2.id] = length(pairs)
            push!(pRev1[c1.id], length(pairs))
            push!(pRev2[c2.id], length(pairs))
        end
    end
    return pairs, starts, cID, cRev, pRev, pRev1, pRev2, sRev, sRev1, sRev2
end
