###################################################
## offline/lpsolve.jl
## Fix pick-up time => network flow problem
###################################################

"""
    `lpFlow`: takes FlowProblem and pick-up times, give Flow Solution
"""

function lpFlow(l::FlowProblem, t::Vector{Float64}; verbose::Bool=true, solverArgs...)

    edgeSet = Set(feasibleEdges(l, t))

    #Solver : Gurobi (modify parameters)
    of = verbose ? 1 : 0

    m = Model(Gurobi.Optimizer)
    #(OutputFlag=of, Method=1; solverArgs...)
    set_attribute(m, "OutputFlag", of)
    set_attribute(m, "Method", 1)
    set_attributes(m, solverArgs)

     # Dual Simplex works well
    # =====================================================
    # Decision variables
    # =====================================================

    # Edge of flow graph is used
    @variable(m, 0 <= x[e = edgeSet]       <= 1)
    # customer c picked-up only once
    @variable(m, 0 <= p[v = vertices(l.g)] <= 1)

    @objective(m, Max, sum(x[e]*l.profit[e], e = edgeSet))

    # =====================================================
    # Constraints
    # =====================================================

    # first nodes : entry
    @constraint(m, cs1[v = l.taxiInit], p[v] == 1)

    # customer nodes : entry
    @constraint(m, cs2[v = setdiff(vertices(l.g), l.taxiInit)],
    sum(x[e], e = filter( x-> x in edgeSet, in_edges(l.g, v))) == p[v])

    # all nodes : exit
    @constraint(m, cs3[v = vertices(l.g)],
    sum(x[e], e = filter( x-> x in edgeSet, out_edges(l.g, v))) <= p[v])

    status = solve(m)
    if status == :Infeasible
        error("Model is infeasible")
    end


    sol = Set{Edge}()

    for e in edgeSet
        if getvalue(x[e]) > 0.9
            push!(sol, e)
        end
    end
    return FlowSolution(sol)
end

"""
    `feasibleEdges` returns  feasible edges given fixed pick-up times
"""
function feasibleEdges(fpb::FlowProblem, t::Vector{Float64})
    return (e for e in edges(fpb.g) if  t[dst(e)] - t[src(e)] >= fpb.time[e])
end
