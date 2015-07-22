#-------------------------------------------------------------
#-- Local changes on window solution to look for a better one
#--------------------------------------------------------------

function localDescent(pb::TaxiProblem, maxTry::Int, start::IntervalSolution = orderedInsertions(pb))
    nTaxis = length(pb.taxis)
    #if no customer
    if orderedInsertions(pb).notTaken == trues(length(pb.custs))
        best = IntervalSolution(pb)
        print("\nFinal: $(-best.cost) dollars\n")
        return best
    end
    println("Start, $(-start.cost) dollars")
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
            @printf("\r====Try: %i, %.2f dollars (%.2fmin, %.2f tests/min, %.3f%% successful)      ",trys, -sol.cost, minutes, trys/minutes, success/(trys-1)*100)
            best = sol.cost
        end
    end
    expandWindows!(pb, sol)
    print("\n====Final: $(-sol.cost) dollars \n")
    return sol
end
