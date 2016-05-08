###################################################
## offline/mipsolve.jl
## mixed integer optimisation, time-window based
###################################################
"""
    `mipSolve`: MIP formulation of offline taxi assignment
    can be warmstarted with a solution
"""

mipSolve2(pb::TaxiProblem, links::FlowLinks=allLinks(pb); args...) =
    mipSolve2(pb, Nullable{OfflineSolution}(), links; args...)
mipSolve2(pb::TaxiProblem, s::OfflineSolution, links::FlowLinks=allLinks(pb); args...) =
    mipSolve2(pb, Nullable{OfflineSolution}(s), links; args...)

function mipSolve2(pb::TaxiProblem, init::Nullable{OfflineSolution}, l::FlowLinks=allLinks(pb); verbose::Bool=true, solverArgs...)
    if ne(l.g) == 0
        return OfflineSolution(pb)
    end

    edgeList = collect(edges(l.g))

    #Solver : Gurobi (modify parameters)
    of = verbose ? 1:0
    m = Model(solver= GurobiSolver(OutputFlag=of; solverArgs...))
    # =====================================================
    # Decision variables
    # =====================================================

    # Edge of flow graph is used
    @defVar(m, x[e = edgeList], Bin)
    # customer c picked-up only once
    @defVar(m, p[v = vertices(l.g)], Bin)
    # Pick-up time
    @defVar(m, l.tw[v][1] <= t[v = vertices(l.g)] <= l.tw[v][2])


    # =====================================================
    # Initialisation
    # =====================================================
    if !isnull(init)
        init2 = get(init)

        for e in edges(l.g)
            setValue(x[e],0)
        end
        for v in vertices(l.g)
            setValue(p[v], 0)
        end
        for (k,ll) in enumerate(init2.custs)
            setValue(p[l.cust2node[-k]], 1)
            if length(ll) > 0
                e = Edge(l.cust2node[-k], l.cust2node[ll[1].id])
                if ! has_edge(l.g, e)
                    error("Warmstart link not in flow graph!")
                end
                setValue(x[e], 1)
                setValue(p[dst(e)], 1)
                for j= 2:length(ll)
                    e = Edge(l.cust2node[ll[j-1].id], l.cust2node[ll[j].id])
                    if ! has_edge(l.g, e)
                        error("Warmstart link not in flow graph!")
                    end
                    setValue(x[e], 1)
                    setValue(p[dst(e)], 1)

                end
            end
        end
    end

    @setObjective(m, Max, sum{x[e]*(l.profit[e] + (l.time[e] - 2*pb.customerTime)*pb.waitingCost), e = edgeList} -
    pb.simTime*length(pb.taxis)*pb.waitingCost )

    # =====================================================
    # Constraints
    # =====================================================

    # first nodes : entry
    @addConstraint(m, cs1[v = l.taxiInit], p[v] == 1)

    # customer nodes : entry
    @addConstraint(m, cs2[v = setdiff(vertices(l.g), l.taxiInit)],
    sum{x[e], e = in_edges(l.g, v)} == p[v])

    # all nodes : exit
    @addConstraint(m, cs3[v = vertices(l.g)],
    sum{x[e], e = out_edges(l.g, v)} <= p[v])

    #Time limits rules
    @addConstraint(m, cs4[e = edgeList],
    t[dst(e)] - t[src(e)] >= (l.tw[dst(e)][1] - l.tw[src(e)][2]) +
    (l.time[e] - (l.tw[dst(e)][1] - l.tw[src(e)][2])) * x[e])

    status = solve(m)
    if status == :Infeasible
        error("Model is infeasible")
    end

    custs = [CustomerTimeWindow[] for k in eachindex(pb.taxis)]
    rejected = IntSet(eachindex(pb.custs))
    # reconstruct solution
    for k=eachindex(pb.taxis), e = out_edges(l.g, l.cust2node[-k])
        if getValue(x[e]) > 0.9
            c = l.node2cust[dst(e)]
            push!(custs[k], CustomerTimeWindow(c, 0., 0.))
            delete!(rejected, c)
            anotherCust = true
            while anotherCust
                anotherCust = false
                for e2 in out_edges(l.g, dst(e))
                    if getValue(x[e2]) > 0.9
                        c = l.node2cust[dst(e2)]
                        push!(custs[k], CustomerTimeWindow(c, 0., 0.))
                        delete!(rejected, c)
                        anotherCust = true; e = e2; break;
                    end
                end
            end
        end
    end

    return OfflineSolution(pb, updateTimeWindows!(pb, custs), rejected, getObjectiveValue(m))
end

"""
    `mipSolve`: MIP formulation of offline taxi assignment
    can be warmstarted with a solution
"""

mipSolve(pb::TaxiProblem, links::CustomerLinks=allLinks(pb); args...) =
    mipSolve(pb, Nullable{OfflineSolution}(), links; args...)
mipSolve(pb::TaxiProblem, s::OfflineSolution, links::CustomerLinks=allLinks(pb); args...) =
    mipSolve(pb, Nullable{OfflineSolution}(s), links; args...)
mipSolve(s::OfflineSolution, links::CustomerLinks=allLinks(pb); args...) =
    mipSolve(s.pb, Nullable{OfflineSolution}(s), links; args...)

function mipSolve(pb::TaxiProblem, init::Nullable{OfflineSolution},  l::CustomerLinks=allLinks(pb); verbose::Bool=true, solverArgs...)
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
    prv, nxt = l.prv, l.nxt

    #Solver : Gurobi (modify parameters)
    of = verbose ? 1:0
    m = Model(solver= GurobiSolver(OutputFlag=of; solverArgs...))

    # =====================================================
    # Decision variables
    # =====================================================

    #Taxi k takes customer c2, right after customer c1
    @defVar(m, x[c1=keys(prv), c2 = nxt[c1]], Bin)
    #Taxi k takes customer c, as a first customer
    @defVar(m, y[k=eachindex(taxi), c=nxt[-k]], Bin)
    # customer c picked-up only once
    @defVar(m, p[c=keys(prv)], Bin)
    # Pick-up time
    @defVar(m, cust[c].tmin <= t[c=keys(prv)] <= cust[c].tmax)


    # =====================================================
    # Initialisation
    # =====================================================
    if !isnull(init)
        init2 = get(init)

        for c1=keys(prv), c2 = nxt[c1]
            setValue(x[c1, c2],0)
        end
        for k=eachindex(taxi), c=nxt[-k]
            setValue(y[k, c],0)
        end
        for c in keys(prv)
            setValue(t[c], cust[c].tmin)
            setValue(p[c], 0)
        end
        for (k,l) in enumerate(init2.custs)
            if length(l) > 0
                if ! (l[1].id in nxt[-k])
                    break
                end
                setValue(y[k, l[1].id], 1)
                setValue(t[l[1].id],l[1].tInf)
                setValue(p[l[1].id], 1)
                for j= 2:length(l)
                    if !(l[j].id in nxt[l[j-1].id])
                        break
                    end
                    setValue(x[l[j-1].id, l[j].id], 1)
                    setValue(t[l[j].id],l[j].tInf)
                    setValue(p[l[j].id], 1)

                end
            end
        end
    end
    # =====================================================
    # Objective (do not depend on time windows!)
    # =====================================================
    #Price paid by customers
    @defExpr(m, customerCost, sum{
    (tc[cust[c1].dest, cust[c2].orig] +
    tc[cust[c2].orig, cust[c2].dest] - cust[c2].fare) * x[c1, c2],
    c1=keys(prv), c2 = nxt[c1]})

    #Price paid by "first customers"
    @defExpr(m, firstCustomerCost, sum{
    (tc[taxi[k].initPos, cust[c].orig] +
    tc[cust[c].orig, cust[c].dest] - cust[c].fare) * y[k, c],
    k=eachindex(taxi), c=nxt[-k]})

    #Busy time
    @defExpr(m, busyTime, sum{
    (tt[cust[c1].dest, cust[c2].orig] +
    tt[cust[c2].orig, cust[c2].dest] )*(-pb.waitingCost) * x[c1, c2],
    c1=keys(prv), c2 = nxt[c1]})

    #Busy time during "first customer"
    @defExpr(m, firstBusyTime, sum{
    (tt[taxi[k].initPos, cust[c].orig] +
    tt[cust[c].orig, cust[c].dest])*(-pb.waitingCost) * y[k, c],
    k=eachindex(taxi), c=nxt[-k]})

    @setObjective(m, Min, customerCost + firstCustomerCost +
    busyTime + firstBusyTime + pb.simTime*length(taxi)*pb.waitingCost )

    # =====================================================
    # Constraints
    # =====================================================
    # taxi nodes (entering one flow, might exit immediately)
    @addConstraint(m, cs1[k=eachindex(taxi)],
    sum{y[k, c], c=nxt[-k]} <= 1)

    # customer nodes : entry
    @addConstraint(m, cs2[c=keys(prv)],
    sum{x[c1, c], c1 = filter(x->x>0, prv[c])} +
    sum{y[-k, c], k  = filter(x->x<0, prv[c])} == p[c])

    # customer nodes : exit
    @addConstraint(m, cs2[c=keys(prv)],
    sum{x[c, c1], c1= nxt[c]} <= p[c])

    #Time limits rules
    @addConstraint(m, cs5[c1=keys(prv), c2 = nxt[c1]],
    t[c2] - t[c1] >= (cust[c2].tmin - cust[c1].tmax) +
    (tt[cust[c1].orig, cust[c1].dest] + tt[cust[c1].dest, cust[c2].orig] + 2*pb.customerTime -
    (cust[c2].tmin - cust[c1].tmax)) * x[c1, c2])

    #First move constraint
    @addConstraint(m, cs6[k=eachindex(taxi), c=nxt[-k]],
    t[c] >= cust[c].tmin +
    (taxi[k].initTime + tt[taxi[k].initPos, cust[c].orig] - cust[c].tmin)* y[k, c])

    status = solve(m)
    if status == :Infeasible
        error("Model is infeasible")
    end

    tx = getValue(x)
    ty = getValue(y)
    ttime = getValue(t)

    custs = [CustomerTimeWindow[] for k in eachindex(taxi)]
    rejected = IntSet(keys(prv))
    # reconstruct solution
    for k=eachindex(taxi), c=nxt[-k]
        if ty[k, c] > 0.9
            push!(custs[k], CustomerTimeWindow(c, ttime[c], ttime[c]))
            c1 = c
            delete!(rejected, c)
            anotherCust = true
            while anotherCust
                anotherCust = false
                for c2 in nxt[c1]
                    if tx[c1, c2] > 0.9
                        push!(custs[k], CustomerTimeWindow(c2, ttime[c2], ttime[c2]))
                        delete!(rejected, c2)
                        anotherCust = true; c1 = c2; break;
                    end
                end
            end
        end
    end

    return OfflineSolution(pb, updateTimeWindows!(pb, custs), rejected, - getObjectiveValue(m))
end
