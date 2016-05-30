###################################################
## offline/mipsolve.jl
## mixed integer optimisation, time-window based
###################################################
"""
    `mipSolve`: MIP formulation of offline taxi assignment
    can be warmstarted with a solution
"""

mipSolve(pb::TaxiProblem; args...) =
    mipSolve(pb, FlowProblem(pb), Nullable{OfflineSolution}(); args...)
mipSolve(pb::TaxiProblem, s::OfflineSolution; args...) =
    mipSolve(pb, FlowProblem(pb), Nullable{OfflineSolution}(s); args...)

function mipSolve(pb::TaxiProblem, l::FlowProblem, s::Nullable{OfflineSolution}; args...)
    if !isnull(s)
        return OfflineSolution(pb, l, mipFlow(l, FlowSolution(l, s); args...))
    else
        return OfflineSolution(pb, l, mipFlow(l; args...))
    end
end

"""
    `mipFlow`: take FlowProblem, give Flow Solution
    the different methods to implement the time-window restrictions can be:
    - "pickuptime" (by default) : continuous variables for each pick-up time
    - "allinfpaths": precompute all infeasible paths
"""
mipFlow(l::FlowProblem; args...) = mipFlow(l, Nullable{FlowSolution}(); args...)
mipFlow(l::FlowProblem, s::FlowSolution; args...) =
    mipFlow(l, Nullable{FlowSolution}(s); args...)
function mipFlow(l::FlowProblem, s::Nullable{FlowSolution}; verbose::Bool=true, method::AbstractString="pickuptime", solverArgs...)

    edgeList = collect(edges(l.g))
    if method == "allinfpaths"
        fi = allInfeasibilities(l)
    end

    #Solver : Gurobi (modify parameters)
    of = verbose ? 1:0
    m = Model(solver= GurobiSolver(OutputFlag=of; solverArgs...))
    # =====================================================
    # Decision variables
    # =====================================================

    # Edge of flow graph is used
    @variable(m, x[e = edgeList], Bin)
    # customer c picked-up only once
    @variable(m, p[v = vertices(l.g)], Bin)

    if method == "pickuptime"
        @variable(m, l.tw[v][1] <= t[v = vertices(l.g)] <= l.tw[v][2])
    end


    # =====================================================
    # Warmstart
    # =====================================================
    if !isnull(s)
        for e in edgeList
            setValue(x[e], 0)
        end
        for e in get(s).edges
            setValue(x[e], 1)
        end
    end

    @objective(m, Max, sum{x[e]*l.profit[e], e = edgeList})

    # =====================================================
    # Constraints
    # =====================================================

    # first nodes : entry
    @constraint(m, cs1[v = l.taxiInit], p[v] == 1)

    # customer nodes : entry
    @constraint(m, cs2[v = setdiff(vertices(l.g), l.taxiInit)],
    sum{x[e], e = in_edges(l.g, v)} == p[v])

    # all nodes : exit
    @constraint(m, cs3[v = vertices(l.g)],
    sum{x[e], e = out_edges(l.g, v)} <= p[v])

    if method == "pickuptime" #Time limits rules
        @constraint(m, cs4[e = edgeList],
        t[dst(e)] - t[src(e)] >= (l.tw[dst(e)][1] - l.tw[src(e)][2]) +
        (l.time[e] - (l.tw[dst(e)][1] - l.tw[src(e)][2])) * x[e])
    elseif method == "allinfpaths"
        @constraint(m, cs4[ ik in fi, j=1:size(ik)[2]],
        sum{x[e], e in ik[:,j]} <= size(ik)[1] - 1)
    end



    status = solve(m)
    if status == :Infeasible
        error("Model is infeasible")
    end

    sol = Set{Edge}()

    for e in edgeList
        if getvalue(x[e]) > 0.9
            push!(sol, e)
        end
    end
    return FlowSolution(sol)
end
