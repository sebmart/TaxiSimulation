#----------------------------------------
#-- Random "gradient descent"
#----------------------------------------
include("orderedInsertions.jl")
function insertionsDescent(pb::TaxiProblem, n::Int, start::Vector{Int} =  timeOrderedCustomers(pb))
    order = start
    tic()
    best = orderedInsertions(pb, order)
    println("Try: 1, $(-best.cost) dollars\n")
    success = 0.
    for trys in 2:n
        #We do only on transposition from the best costn
        i = rand(1:length(order))
        j = i
        while i == j
            j = rand(1:length(order))
        end

        order[i], order[j] = order[j], order[i]

        sol = orderedInsertions(pb, order)
        if sol.cost <= best.cost
            success += 1
            if sol.cost < best.cost
                @printf("\r====Try: %i, %.2f dollars (%.2f tests/min, %.3f\% successful)                  ",trys, -sol.cost, trys*60/toq(), success/(trys-1)*100)
            end
            best = sol
            order[i], order[j] = order[j], order[i]
        end
        order[i], order[j] = order[j], order[i]
    end
    print("\rFinal: $(-best.cost) dollars             \n")
    expandWindows!(pb,best)
    return best
end
