###################################################
## offline/localdescent.jl
## introduce local changes in solution to find a better one
###################################################

"""
    `localDescent`: switches two taxis timelines to locally optimize a solution
     (fast on large instances)
     - parameter `random = true` to try any combination, = false to do the best one
"""
function localDescent(pb::TaxiProblem, start::OfflineSolution = orderedInsertions(pb);
     verbose::Bool = true, random::Bool = false, benchmark::Bool = false, iterations::Int=typemax(Int),
      maxTime::Float64=Inf)
    if benchmark
        return localDescentWithBench(pb, start, verbose, random, benchmark, iterations, maxTime)
    else
        return localDescentWithBench(pb, start, verbose, random, benchmark, iterations, maxTime)[1]
    end
end

function localDescentWithBench(pb::TaxiProblem, start::OfflineSolution, verbose::Bool,
            random::Bool, benchmark::Bool, iterations::Int, maxTime::Float64)
    initT = time()

    if maxTime == Inf && iterations == typemax(Int)
        maxTime = 5.
    end

    nTaxis = length(pb.taxis)
    #if no customer
    if length(start.rejected) == length(pb.custs)
        ordered = orderedInsertions(pb)
        if length(ordered.rejected) == length(pb.custs)
            verbose && println("Final: $(ordered.profit) dollars")
            return ordered
        end
        start = ordered
    end

    verbose && println("Start, $(start.profit) dollars")
    sol =  copySolution(start)
    success = 0

    benchData = BenchmarkPoint[]
    benchmark && (push!(benchData, BenchmarkPoint(0.,start.profit,Inf)))
    for trys in 1:iterations
        if time()-initT > maxTime
            break
        end
        k = rand(1:nTaxis)
        while isempty(sol.custs[k])
            k = rand(1:nTaxis)
        end
        i = rand(1:length(sol.custs[k]))

        if random
            k2 = rand(1:(nTaxis-1))
            k2 >= k && (k2 +=1)
            revertSol = switchCustomers!(sol, k, i,k2)
        else
            revertSol = switchCustomers!(sol, k, i)
        end
        updateProfit = profitDiff(sol,revertSol)
        if updateProfit > 0.
            sol.profit += updateProfit
            success += 1
            t = time()-initT
            min,sec = minutesSeconds(t)
            verbose && (@printf("\r====Try: %i, %.2f dollars (%dm%ds, %.2f tests/min, %.3f%% successful)   ",
            trys, sol.profit, min, sec, 60.*trys/t, success/(trys-1.)*100.))
            benchmark && push!(benchData, BenchmarkPoint(t,sol.profit,Inf))
        else
            updateSolution!(sol,revertSol)
        end
    end
    updateTimeWindows!(sol)
    sol.profit = solutionProfit(pb,sol.custs)
    benchmark && push!(benchData, BenchmarkPoint(time()-initT,sol.profit,Inf))
    return sol, benchData
end
