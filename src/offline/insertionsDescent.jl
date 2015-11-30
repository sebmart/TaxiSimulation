#----------------------------------------
#-- Random "gradient descent"
#----------------------------------------
include("orderedInsertions.jl")
function insertionsDescent(pb::TaxiProblem, start::Vector{Int} =  timeOrderedCustomers(pb); benchmark=false, verbose=true, maxTime=Inf, iterations=typemax(Int))
    if maxTime = Inf && iterations == typemax(Int)
        maxTime = 5.
    end

    order = start

    initT = time()
    best = orderedInsertions(pb, order)
    benchmark && (benchData = BenchmarkPoint[BenchmarkPoint(time()-initT,-best.cost,Inf)])

    #if no customer
    if best.notTaken == trues(length(pb.custs))
        best = IntervalSolution(pb)
        verbose && print("\nFinal: $(-best.cost) dollars\n")
        return best
    end
    if length(pb.custs) == 1
        verbose && print("\nFinal: $(-best.cost) dollars\n")
        return best
    end
    verbose && println("Try: 1, $(-best.cost) dollars\n")
    success = 0.
    for trys in 2:iterations
        if time()-initT > maxTime
            break
        end
        #We do only on transposition from the best costn
        i = rand(1:length(order))
        j = i
        while i == j
            j = rand(1:length(order))
        end

        order[i], order[j] = order[j], order[i]

        sol = orderedInsertions(pb, order)
        if sol.cost <= best.cost
            if sol.cost < best.cost
                benchmark && push!(benchData, BenchmarkPoint(time()-initT,-sol.cost,Inf))
                success += 1
                minutes = (time()-initT)/60
                verbose && @printf("\r====Try: %i, %.2f dollars (%.2fmin, %.2f tests/min, %.3f%% successful)   ",trys, -sol.cost, minutes, trys/minutes, success/(trys-1)*100)
            end
            best = sol
            order[i], order[j] = order[j], order[i]
        end
        order[i], order[j] = order[j], order[i]
    end
    verbose && print("\nFinal: $(-best.cost) dollars\n")
    benchmark && push!(benchData, BenchmarkPoint(time()-initT,-best.cost,Inf))
    expandWindows!(pb,best)
    benchmark && return (best,benchData)
    return best
end
