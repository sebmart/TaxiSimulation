###################################################
## offline/mipsolve.jl
## mixed integer optimisation, time-window based
###################################################
"""
    `mipSolve`: MIP formulation of offline taxi assignment
    can be warmstarted with a solution
"""

mipSolve(pb::TaxiProblem, links::FlowLinks=allLinks(pb); args...) =
    mipSolve(pb, Nullable{OfflineSolution}(), links; args...)
mipSolve(pb::TaxiProblem, s::OfflineSolution, links::FlowLinks=allLinks(pb); args...) =
    mipSolve(pb, Nullable{OfflineSolution}(s), links; args...)

function mipSolve(pb::TaxiProblem, init::Nullable{OfflineSolution}, l::FlowLinks=allLinks(pb); verbose::Bool=true, solverArgs...)
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
