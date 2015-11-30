#----------------------------------------
#-- Try random orders, keep the best one
#----------------------------------------
include("orderedInsertions.jl")
function randomInsertions(pb::TaxiProblem; benchmark=false, verbose=true, maxTime= Inf, iterations=typemax(Int))
    if maxTime = Inf && iterations == typemax(Int)
        maxTime = 5.
    end
    initT = time()


    order = randomOrder(pb)
    best = orderedInsertions(pb, order)
    verbose && println("Try: 1, $(-best.cost) dollars")
    benchmark && (benchData = BenchmarkPoint[BenchmarkPoint(time()-initT,-best.cost,Inf)])
    for trys in 2:iterations
        if time()-initT > maxTime
            break
        end
        sol = orderedInsertions(pb, order)

        if sol.cost < best.cost
            verbose && print("\r====Try: $(trys), $(-sol.cost) dollars                  ")
            benchmark && push!(benchData, BenchmarkPoint(time()-initT,-sol.cost,Inf))
            best = sol
        end

        order = randomOrder(pb)
    end
    verbose && print("\r====Final: $(-best.cost) dollars              \n")
    expandWindows!(pb,best)
    benchmark && return (best,benchData)
    return best
end
