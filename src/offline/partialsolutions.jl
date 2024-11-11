###################################################
## offline/partialsolutions.jl
## implements sparse solutions for mor efficient algorithms
###################################################
"""
    `PartialSolution`: selected taxis assigned customers
    (used to sparsily represent solution changes)
"""
const PartialSolution=Dict{Int,Vector{CustomerTimeWindow}}

"""
 `EmptyUpdate` partial solution object to avoid constructing it when not using it
 """
const EmptyUpdate = PartialSolution()

"""
    `addPartialSolution!`, add an update to a Partial solution
    reverse update : only store if not stored before (we want to remember the past)
"""
function addPartialSolution!(sol::PartialSolution, k::Int, u::Vector{CustomerTimeWindow})
    if !haskey(sol,k)
        sol[k] = deepcopy(u)
    end
end
function addPartialSolution!(sol::PartialSolution, sol2::PartialSolution)
    for (k,u) in sol2
        addPartialSolution!(sol,k,u)
    end
end

"""
    `updateSolution!`, reverts an OfflineSolution to a previous state
    Updates in place an OfflineSolution, given a list of changes (do not update cost!)
"""
function updateSolution!(sol::OfflineSolution, updateSol::PartialSolution)
    for (k,u) in updateSol
        for c in sol.custs[k]
            if c.id in sol.rejected
                delete!(sol.rejected,c.id)
            else
                push!(sol.rejected,c.id)
            end
        end
        for c in u
            if c.id in sol.rejected
                delete!(sol.rejected,c.id)
            else
                push!(sol.rejected,c.id)
            end
        end
        sol.custs[k] = u
    end
    sol
end

"""
    `profitDiff`
    returns profit difference between solution and update
"""
function profitDiff(sol::OfflineSolution, updateSol::PartialSolution)
    profit = 0.
    for (k,u) in updateSol
        profit +=  taxiProfit(sol.pb,sol.custs[k],k) - taxiProfit(sol.pb,u,k)
    end
    return profit
end
