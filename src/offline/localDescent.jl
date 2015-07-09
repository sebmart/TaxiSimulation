#-------------------------------------------------------------
#-- Local changes on window solution to look for a better one
#--------------------------------------------------------------
include("moveCustomer.jl")

function localDescent(pb::TaxiProblem, maxTry::Int, start::IntervalSolution = orderedInsertions(pb))
    nTaxis = length(pb.taxis)
    println("Start, $(-start.cost) dollars")
    sol =  copySolution(start)
    best = sol.cost
    success = 0
    tic()
    for trys in 1:maxTry
        k = rand(1:nTaxis)
        k2 = rand( 1 :(nTaxis-1))
        k2 =  k2 >= k ? k2+1 : k2
        if isempty(sol.custs[k])
            continue
        end
        i = rand(1:length(sol.custs[k]))
        sol = splitAndMove!(pb, sol, k, i, k2)
        if sol.cost < best
            @printf("\r====Try: %i, %.2f dollars (%.2f tests/min, %.3f\% successful)                  ",trys, -sol.cost, trys*60/toq(), success/trys*100)
            best = sol.cost
        end
    end
    expandWindows!(pb, sol)
    print("\r====Final: $(-sol.cost) dollars              \n")
    return sol
end
