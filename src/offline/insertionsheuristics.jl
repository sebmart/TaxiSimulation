###################################################
## offline/insertionsheuristics.jl
## offline heuristics using only insertions
###################################################

"""
    `orderedInsertions`, create solution by inserting customers with given order
"""
function orderedInsertions(pb::TaxiProblem, order::Vector{Int} = timeOrderedCustomers(pb); earliest::Bool=false)
    nTaxis, nCusts = length(pb.taxis), length(pb.custs)

    sol = OfflineSolution(pb)
    for i in 1:nCusts
        c = order[i]
        insertCustomer!(sol, c, earliest=earliest)
    end
    sol.profit = solutionProfit(pb,sol.custs)
    return sol
end

"""
    `timeOrderedCustomers`, order customers id by tmin
"""
timeOrderedCustomers(pb::TaxiProblem) =
sort(collect(1:length(pb.custs)), by = i -> pb.custs[i].tmin)


"""
    `insertionsDescent`: locally optimizes the order of insertions to find better solution
"""
function insertionsDescent(pb::TaxiProblem, start::Vector{Int} =  timeOrderedCustomers(pb);
                    benchmark::Bool=false, verbose::Bool=true, maxTime::Float64=Inf,
                    iterations::Int=typemax(Int))
    if benchmark
        return insertionsDescentWithBench(pb,start, benchmark, verbose, maxTime, iterations)
    else
        return insertionsDescentWithBench(pb,start, benchmark, verbose, maxTime, iterations)[1]
    end
end

function insertionsDescentWithBench(pb::TaxiProblem, start::Vector{Int}, benchmark::Bool,
                                verbose::Bool, maxTime::Float64, iterations::Int)
    if maxTime == Inf && iterations == typemax(Int)
        maxTime = 10.
    end
    order = start

    initT = time()
    best = orderedInsertions(pb, order)
    benchData = BenchmarkPoint[]
    benchmark && (push!(benchData, BenchmarkPoint(time()-initT,best.profit,Inf)))

    #if no customer or only one in problem: stop
    if best.rejected == IntSet(eachindex(pb.custs)) || length(pb.custs) == 1
        verbose && print("\nFinal profit: $(best.profit) dollars\n")
        return best
    end

    verbose && println("Try: 1, $(best.profit) dollars\n")
    success = 0.
    for trys in 2:iterations
        if time()-initT > maxTime
            break
        end
        #We do only on transposition from the best solution so far
        i = rand(1:length(order))
        j = rand(1:length(order) - 1)
        j = (j>=i) ? j+1 : j

        order[i], order[j] = order[j], order[i]

        sol = orderedInsertions(pb, order)
        if sol.profit >= best.profit # in case of equality, update order
            if sol.profit > best.profit
                benchmark && push!(benchData, BenchmarkPoint(time()-initT,sol.profit,Inf))
                success += 1
                t = time()-initT
                min,sec = minutesSeconds(t)
                verbose && (@printf("\r====Try: %i, %.2f dollars (%dm%ds, %.2f tests/min, %.3f%% successful)   ",
                trys, sol.profit, min, sec, 60.*trys/t, success/(trys-1.)*100.))
            end
            best = sol
            order[i], order[j] = order[j], order[i]
        end
        order[i], order[j] = order[j], order[i]
    end
    verbose && print("\nFinal profit: $(best.profit) dollars\n")
    benchmark && push!(benchData, BenchmarkPoint(time()-initT, best.profit,Inf))
    return (best,benchData)
end
