###################################################
## offline/mipsolve.jl
## mixed integer optimisation, time-window based
###################################################
"""
    `mipSolve`: MIP formulation of offline taxi assignment
    can be warmstarted with a solution
"""

mipSolve(pb::TaxiProblem; args...) =
    mipSolve(pb, FlowProblem(pb), Union{OfflineSolution, Nothing}(); args...)
mipSolve(pb::TaxiProblem, s::OfflineSolution; args...) =
    mipSolve(pb, FlowProblem(pb), Union{OfflineSolution, Nothing}(s); args...)

function mipSolve(pb::TaxiProblem, l::FlowProblem, s::Union{OfflineSolution, Nothing}; args...)
    if !isnull(s)
        return OfflineSolution(pb, l, mipFlow(l, FlowSolution(l, get(s)); args...))
    else
        return OfflineSolution(pb, l, mipFlow(l; args...))
    end
end

"""
    `mipFlow`: take FlowProblem, give Flow Solution
    the different methods to implement the time-window restrictions can be:
    - "pickuptime" (by default) : continuous variables for each pick-up time
    - "allinfpaths": precompute all infeasible paths
    - "lazyinfpaths": add path infeasibility in a lazy way
    - "oainfpaths": outer approximation
    - "cutinfpaths"
"""
mipFlow(l::FlowProblem; args...) = mipFlow(l, Union{FlowSolution, Nothing}(); args...)
mipFlow(l::FlowProblem, s::FlowSolution; args...) =
    mipFlow(l, Union{FlowSolution, Nothing}(s); args...)
function mipFlow(l::FlowProblem, s::Nullable{FlowSolution}; verbose::Bool=true, method::AbstractString="pickuptime", solverArgs...)


    edgeList = collect(edges(l.g))
    if method == "allinfpaths"
        fi = allInfeasibilities(l)
    end
    
    # Re-initialize condition to minimal range of valid range for initial solution
    function lazyinfpaths_callback(cb_data)
        # m as model
        fs = emptyFlow(l)
        for e in edgeList
            if getvalue(x[e]) > 0.9
                add_edge!(fs.g, e)
            end
        end

        fi = allInfeasibilities(fs)
        for ik in fi, j=1:size(ik)[2]
            # Porting to generic API 
            cond = @build_constraint(sum{x[e], e in ik[:,j]} <= size(ik)[1] - 1)
            MOI.submit(m, MOI.LazyConstraint(cb_data), cond)
        end
    end

    # User-cut algorithm
    function cutinfpaths_callback(cb_data)
        fs = emptyFlow(l)
        for e in edgeList
            if getvalue(x[e]) > 0.01
                add_edge!(fs.g, e)
            end
        end
        fi = allInfeasibilities(fs)
        for ik in fi, j=1:size(ik)[2]
            if sum([getvalue(x[e]) for e in ik[:,j]]) > size(ik)[1] - 1

                # Port to generic API
                cond = @build_constraint(sum{x[e], e in ik[:,j]} <= size(ik)[1] - 1)
                MOI.submit(m, MOI.UserCut(cb_data), cond)
            end
        end
    end

    #Solver : Gurobi (modify parameters)
    of = verbose ? 1 : 0
    m = Model(Gurobi.Optimizer)
    #(OutputFlag=of, Method=1; solverArgs...)
    set_attribute(m, "OutputFlag", of)
    # =====================================================
    # Decision variables
    # =====================================================

    # Edge of flow graph is used
    @variable(m, x[e = edgeList], Bin)

    # customer c picked-up only once
    @variable(m, p[v = vertices(l.g)], Bin)

    if method == "pickuptime" || method == "cutinfpaths"
        @variable(m, l.tw[v][1] <= t[v = vertices(l.g)] <= l.tw[v][2])
    end


    # =====================================================
    # Warmstart
    # =====================================================
    if !isnull(s)
        for e in edgeList
            setvalue(x[e], 0)
        end
        for e in get(s).edges
            setvalue(x[e], 1)
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

    if method == "pickuptime"
        @constraint(m, cs4[e = edgeList],
        t[dst(e)] - t[src(e)] >= (l.tw[dst(e)][1] - l.tw[src(e)][2]) +
        (l.time[e] - (l.tw[dst(e)][1] - l.tw[src(e)][2])) * x[e])
    elseif method == "allinfpaths"
        @constraint(m, cs4[ ik in fi, j=1:size(ik)[2]],
        sum{x[e], e in ik[:,j]} <= size(ik)[1] - 1)
    elseif method == "lazyinfpaths"
        # Undefined
        # addlazycallback(m,lazyinfpaths)
        set_attribute(m, MOI.LazyConstraintCallback(), lazyinfpaths_callback)

    elseif method == "cutinfpaths"

        # Undefined
        # addcutcallback(m, cutinfpaths)
        set_attribute(m, MOI.UserCutCallback(), cutinfpaths_callback)

        @constraint(m, cs4[e = edgeList],
        t[dst(e)] - t[src(e)] >= (l.tw[dst(e)][1] - l.tw[src(e)][2]) +
        (l.time[e] - (l.tw[dst(e)][1] - l.tw[src(e)][2])) * x[e])
    end


    if method=="oainfpaths"
        outside = true
        while outside
            outside = false
            status = solve(m)
            fs = emptyFlow(l)
            for e in edgeList
                if getvalue(x[e]) > 0.9
                    add_edge!(fs.g, e)
                end
            end
            fi = allInfeasibilities(fs)
            for ik in fi, j=1:size(ik)[2]
                outside = true
                @constraint(m, sum{x[e], e in ik[:,j]} <= size(ik)[1] - 1)
            end
        end
    else
        status = solve(m)
    end
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
