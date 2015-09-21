#-------------------------------------------------------------
#-- Local changes on window solution to look for a better one
#--------------------------------------------------------------

function localDescent(pb::TaxiProblem, maxTry::Int, start::IntervalSolution = orderedInsertions(pb); verbose = true)
    nTaxis = length(pb.taxis)
    #if no customer
    ordered = orderedInsertions(pb)
    if ordered.notTaken == trues(length(pb.custs))
        best = IntervalSolution(pb)
        verbose && print("\nFinal: $(-best.cost) dollars\n")
        return best
    end
    if start.notTaken == trues(length(pb.custs))
        start = ordered
    end

    verbose && println("Start, $(-start.cost) dollars")
    sol =  copySolution(start)
    best = sol.cost
    success = 0
    startTime = time_ns()
    for trys in 1:maxTry
        k = rand(1:nTaxis)
        while isempty(sol.custs[k])
            k = rand(1:nTaxis)
        end
        k2 = rand( 1 :(nTaxis-1))
        k2 =  k2 >= k ? k2+1 : k2

        i = rand(1:length(sol.custs[k]))
        sol = splitAndMove!(pb, sol, k, i, k2)
        if sol.cost < best
            success += 1
            minutes = (time_ns()-startTime)/(60*1.0e9)
            verbose && @printf("\r====Try: %i, %.2f dollars (%.2fmin, %.2f tests/min, %.3f%% successful)      ",trys, -sol.cost, minutes, trys/minutes, success/(trys-1)*100)
            best = sol.cost
        end
    end
    expandWindows!(pb, sol)
    verbose && print("\n====Final: $(-sol.cost) dollars \n")
    return sol
end
