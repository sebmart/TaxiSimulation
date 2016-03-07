###################################################
## offline/mip.jl
## mixed integer optimisation, time-window based
###################################################

"""
    `CustomerLink`, contain all customer link informations necessary to build mip
"""
type CustomerLinks
    "mip cust IDs => real cust IDs"
    cID::Vector{Int}
    "real cust IDs => mip cust IDs"
    cRev::Dict{Int,Int}
    "list of customer pairs (mipid2, mipid2)"
    pairs::Vector{Tuple{Int,Int}}
    "pair => pair id"
    pRev::Dict{Tuple{Int,Int},Int}
    "mip cust ID => list of pair IDs where on the left"
    pRev1::Vector{Vector{Int}}
    "mip cust ID => list of pair IDs where on the right"
    pRev2::Vector{Vector{Int}}
    "list of taxi/customer pairs (taxiid, mipid)"
    starts::Vector{Tuple{Int,Int}}
    "start pair => start id"
    sRev::Dict{Tuple{Int,Int},Int}
    "taxi ID => list of starts IDs where on the left"
    sRev1::Vector{Vector{Int}}
    "mip cust ID => list of starts IDs where on the right"
    sRev2::Vector{Vector{Int}}
end

"""
    `MIPSettings`, represents MIP settings: links that we allow between customers
    has to include:
        "The taxi problem"
        `pb::TaxiProblem`
        "the mip structure: customers links"
        `links::CustomerLinks`
        "warmstart"
        `warmstart::Nullable{OfflineSolution}`
    can overload to define
        mipInit!, mipEnd

"""
abstract MIPSettings

"""
    `mipSolve`: offline solver using mip. Can be overwritten!
"""
function mipSolve(pb::TaxiProblem, warmstart::Nullable{OfflineSolution}, s::MIPSettings, verbose::Bool, benchmark::Bool; solverArgs...)
    mipInit!(s, pb, warmstart)
    custs, rev = mipOpt(s.pb, s.links, s.warmstart, verbose=verbose, benchmark=benchmark; solverArgs...)
    return mipEnd(s, custs, rev)
end
mipSolve(pb::TaxiProblem, set::MIPSettings = Optimal(); verbose::Bool=true, benchmark::Bool=false, solverArgs...) =
    mipSolve(pb, Nullable{OfflineSolution}(), set, verbose, benchmark; solverArgs...)
mipSolve(pb::TaxiProblem, s::OfflineSolution, set::MIPSettings = Optimal(); verbose::Bool=true, benchmark::Bool=false, solverArgs...) =
    mipSolve(pb, Nullable{OfflineSolution}(s), set, verbose, benchmark; solverArgs...)
mipSolve(s::OfflineSolution, set::MIPSettings = Optimal(); verbose::Bool=true, benchmark::Bool=false, solverArgs...) =
    mipSolve(s.pb, Nullable{OfflineSolution}(s), set, verbose, benchmark; solverArgs...)

"""
    `mipInit!`: initialize mip settings with problem (to be overloaded)
"""
function mipInit!(s::MIPSettings, pb::TaxiProblem, warmstart::Nullable{OfflineSolution})
    error("mipInit! has to be defined")
end

"""
    `mipEnd`: return solution from mip output (can be overloaded)
"""
function mipEnd(s::MIPSettings, custs::Vector{Vector{CustomerTimeWindow}}, rev::Float64)
    rejected = getRejected(s.pb, custs)
    return OfflineSolution(s.pb, custs, rejected, rev)
end

"""
    `mipOpt`: MIP formulation of offline taxi assignment
    can be warmstarted with a solution
"""
function mipOpt(pb::TaxiProblem, l::CustomerLinks, init::Nullable{OfflineSolution}; verbose::Bool=false, benchmark::Bool=false, solverArgs...)
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
    cID,   cRev,   pairs,   pRev,   pRev1,   pRev2,   starts,   sRev,   sRev1,   sRev2   =
    l.cID, l.cRev, l.pairs, l.pRev, l.pRev1, l.pRev2, l.starts, l.sRev, l.sRev1, l.sRev2

    verbose && println("MIP with $(length(pairs)) pairs and $(length(starts)) starts")
    #Solver : Gurobi (modify parameters)
    of = verbose ? 1:0
    m = Model(solver= GurobiSolver(MIPFocus=1, OutputFlag=of, Method=1; solverArgs...))

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
                if !haskey(sRev,(k,cr))
                    break
                end
                setValue(y[sRev[k,cr]], 1)
                setValue(i[cr],l[1].tInf)
                setValue(s[cr],l[1].tSup)
                for j= 2:length(l)
                    cr = cRev[l[j].id]
                    if !haskey(pRev,(cRev[l[j-1].id],cr))
                        break
                    end
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
    (tc[cust[cID[p[1]]].dest, cust[cID[p[2]]].orig] +
    tc[cust[cID[p[2]]].orig, cust[cID[p[2]]].dest] - cust[cID[p[2]]].fare)*x[k],
    (k,p) in enumerate(pairs)})

    #Price paid by "first customers"
    @defExpr(firstCustomerCost, sum{
    (tc[taxi[s[1]].initPos, cust[cID[s[2]]].orig] +
    tc[cust[cID[s[2]]].orig, cust[cID[s[2]]].dest] - cust[cID[s[2]]].fare)*y[k],
    (k,s) in enumerate(starts)})

    #Busy time
    @defExpr(busyTime, sum{
    (tt[cust[cID[p[1]]].dest, cust[cID[p[2]]].orig] +
    tt[cust[cID[p[2]]].orig, cust[cID[p[2]]].dest] )*(-pb.waitingCost)*x[k],
    (k,p) in enumerate(pairs)})

    #Busy time during "first customer"
    @defExpr(firstBusyTime, sum{
    (tt[taxi[s[1]].initPos, cust[cID[s[2]]].orig] +
    tt[cust[cID[s[2]]].orig, cust[cID[s[2]]].dest])*(-pb.waitingCost)*y[k],
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
    s[pairs[k][1]] + tt[cust[cID[pairs[k][1]]].orig, cust[cID[pairs[k][1]]].dest] +
    tt[cust[cID[pairs[k][1]]].dest, cust[cID[pairs[k][2]]].orig] +
    2*pb.customerTime - s[pairs[k][2]] <= M*(1 - x[k]))

    #Inf bounds rules
    @addConstraint(m, c7[k in eachindex(pairs)],
    i[pairs[k][1]] + tt[cust[cID[pairs[k][1]]].orig, cust[cID[pairs[k][1]]].dest] +
    tt[cust[cID[pairs[k][1]]].dest, cust[cID[pairs[k][2]]].orig] +
    2*pb.customerTime - i[pairs[k][2]] <= M*(1 - x[k]))

    #First move constraint
    @addConstraint(m, c8[k in eachindex(starts)],
    i[starts[k][2]] - tt[taxi[starts[k][1]].initPos, cust[cID[starts[k][2]]].orig] -
    taxi[starts[k][1]].initTime >= M*(y[k] - 1))

    #to get information
    tstart = time()
    # benchData = BenchmarkPoint[]
    # function infocallback(cb)
    #     cost = MathProgBase.cbgetobj(cb)
    #     bestbound = MathProgBase.cbgetbestbound(cb)
    #     seconds = time()-tstart
    #     push!(benchData, BenchmarkPoint(seconds,-cost,-bestbound))
    # end
    # benchmark && addInfoCallback(m,infocallback)


    status = solve(m)
    if status == :Infeasible
        error("Model is infeasible")
    end

    tx = getValue(x)
    ty = getValue(y)
    ti = getValue(i)
    ts = getValue(s)

    custs = [CustomerTimeWindow[] for k in eachindex(taxi)]

    # reconstruct solution
    for k in eachindex(starts)
        if ty[k] > 0.9
            t, c = starts[k]
            push!(custs[t], CustomerTimeWindow(cID[c], ti[c], ts[c]))

            while (k2 = findfirst(x->x>0.9, [tx[p] for p in pRev1[c]])) != 0
                c  = pairs[pRev1[c][k2]][2]
                push!(custs[t], CustomerTimeWindow(cID[c], ti[c], ts[c]))
            end
        end
    end

    # if benchmark
    #     o = -s.cost - benchData[end].revenue
    #     for (i,p) in enumerate(benchData)
    #         benchData[i] = BenchmarkPoint(p.time,p.revenue + o, p.bound + o)
    #     end
    # end
    # benchmark && return (s,benchData)
    return updateTimeWindows!(pb, custs), - getObjectiveValue(m)  # returns assignments + profit
end
