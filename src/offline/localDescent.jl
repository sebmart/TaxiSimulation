#-------------------------------------------------------------
#-- Local changes on window solution to look for a better one
#--------------------------------------------------------------

function localDescent(pb::TaxiProblem, start::IntervalSolution = orderedInsertions(pb);
     verbose::Bool = true, random::Bool = false, benchmark::Bool = false, iterations=typemax(Int),
      maxTime::Float64=Inf)
    initT = time()

    if maxTime == Inf && iterations == typemax(Int)
        maxTime = 5.
    end
    nTaxis = length(pb.taxis)
    #if no customer
    if start.notTaken == trues(length(pb.custs))
        ordered = orderedInsertions(pb)
        if ordered.notTaken == trues(length(pb.custs))
            best = IntervalSolution(pb)
            verbose && print("\nFinal: $(-best.cost) dollars\n")
            return best
        end
        start = ordered
    end

    verbose && println("Start, $(-start.cost) dollars")
    sol =  copySolution(start)
    success = 0

    benchmark && (benchData = BenchmarkPoint[BenchmarkPoint(0.,-start.cost,Inf)])
    for trys in 1:iterations
        if time()-initT > maxTime
            break
        end
        k = rand(1:nTaxis)
        while isempty(sol.custs[k])
            k = rand(1:nTaxis)
        end
        i = rand(1:length(sol.custs[k]))

        tempSol = copySolution(sol)
        if random
             k2 = rand(1:(nTaxis-1))
             k2 >= k && (k2 +=1)
             switchCustomers!(pb, tempSol, k, i,k2)
        else
            switchCustomers!(pb, tempSol, k, i)
        end
        if tempSol.cost < sol.cost
            sol = tempSol
            success += 1
            minutes = (time()-initT)/60
            benchmark && push!(benchData, BenchmarkPoint(time()-initT,-sol.cost,Inf))
            verbose && @printf("\r====Try: %i, %.2f dollars (%.2fmin, %.2f tests/min, %.3f%% successful)      ",trys, -sol.cost, minutes, trys/minutes, 100*success/trys)
        end
    end
    expandWindows!(pb, sol)
    verbose && print("\n====Final: $(-sol.cost) dollars \n")
    benchmark && push!(benchData, BenchmarkPoint(time()-initT,-sol.cost,Inf))
    benchmark && return (sol,benchData)
    return sol
end
