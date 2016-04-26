###################################################
## offline/insertionsheuristics.jl
## offline heuristics using only insertions
###################################################

"""
    `orderedInsertions`, create solution by inserting customers with given order
"""
function orderedInsertions(pb::TaxiProblem, order::Vector{Int} = timeOrderedCustomers(pb);
     earliest::Bool=false, verbose::Bool=false)
    nTaxis, nCusts = length(pb.taxis), length(pb.custs)

    sol = OfflineSolution(pb)
    for i in 1:nCusts
        if verbose && i%100 == 0
            @printf("\r%.2f%% customers inserted", 100 * i/nCusts)
        end
        c = order[i]
        insertCustomer!(sol, c, earliest=earliest)
    end
    verbose && print("\n")
    sol.profit = solutionProfit(pb,sol.custs)
    return sol
end

"""
    `orderedInsertions!`: try to insert all rejected customers in solution
    - for now, ordered by tmin
"""
function orderedInsertions!(s::OfflineSolution; earliest::Bool=false)
    customers = sort(collect(s.rejected), by=c->s.pb.custs[c].tmin)
    for c in customers
        insertCustomer!(s, c, earliest=earliest)
    end
    s
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
                    iterations::Int=typemax(Int), earliest::Bool = false)
    if maxTime == Inf && iterations == typemax(Int)
        maxTime = 10.
    end
    order = start

    initT = time()
    best = orderedInsertions(pb, order, earliest=earliest)

    #if no customer or only one in problem: stop
    if best.rejected == IntSet(eachindex(pb.custs)) || length(pb.custs) == 1
        verbose && println("Final profit: $(best.profit) dollars")
        return best
    end

    verbose && println("Try: 1, $(best.profit) dollars")
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

        sol = orderedInsertions(pb, order, earliest=earliest)
        if sol.profit >= best.profit # in case of equality, update order
            if sol.profit > best.profit
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
    verbose && println("\nFinal profit: $(best.profit) dollars")
    return best
end

"""
    `randomInsertions`, tries random insertions order and keep the best
"""
function randomInsertions(pb::TaxiProblem; benchmark=false, verbose=true, maxTime= Inf, iterations=typemax(Int))
    if maxTime == Inf && iterations == typemax(Int)
        maxTime = 5.
    end
    initT = time()
    order = shuffle(collect(eachindex(pb.custs))) # random order
    best = orderedInsertions(pb, order)
    verbose && println("Try: 1, $(best.profit) dollars")
    benchmark && (benchData = BenchmarkPoint[BenchmarkPoint(time()-initT,best.profit,Inf)])
    for trys in 2:iterations
        if time()-initT > maxTime
            break
        end
        sol = orderedInsertions(pb, order)

        if sol.profit > best.profit
            verbose && print("\r====Try: $(trys), $(sol.profit) dollars                  ")
            benchmark && push!(benchData, BenchmarkPoint(time()-initT,sol.profit,Inf))
            best = sol
        end

        order = shuffle(collect(eachindex(pb.custs)))
    end
    verbose && println("\r====Final: $(best.profit) dollars              ")
    benchmark && push!(benchData, BenchmarkPoint(time()-initT,best.profit,Inf))
    benchmark && return (best,benchData)
    return best
end

"""
    `greedyInsertions`, select best customer to insert at each step
"""
function greedyInsertions(pb::TaxiProblem; verbose::Bool=false)
    nCusts = length(pb.custs)
    sol = OfflineSolution(pb)
    tt = getPathTimes(pb.times)

    initPos  = [t.initPos for t in pb.taxis]
    initTime = [t.initTime for t in pb.taxis]
    allTime = Array(Float64, (nCusts, length(pb.taxis)))
    bestTime = Array(Float64, nCusts)
    bestTaxi = Array(Int, nCusts)
    remainCusts = IntSet(1:nCusts)

    verbose && print("First Computations...")
    bTime = Inf; bCust = 0
    for c in 1:nCusts
        bestTime[c] = Inf
        bestTaxi[c] = 0
        for k in eachindex(pb.taxis)
            minTime = initTime[k] + tt[initPos[k], pb.custs[c].orig]
            if minTime <= pb.custs[c].tmax
                allTime[c,k] = max(minTime, pb.custs[c].tmin) - initTime[k]
                if allTime[c,k] < bestTime[c]
                    bestTime[c] = allTime[c,k]
                    bestTaxi[c] = k
                end
            else
                allTime[c,k] = Inf
            end
        end

        if bestTaxi[c] == 0
            delete!(remainCusts, c)
        elseif bestTime[c] < bTime
            bTime = bestTime[c]
            bCust = c
        end
    end
    i=1
    while !isempty(remainCusts)
        if bCust == 0
            break
        end
        c = pb.custs[bCust]; k =bestTaxi[bCust]; t = bTime
        push!(sol.custs[k], CustomerTimeWindow(c.id, initTime[k] + t, c.tmax))
        delete!(sol.rejected, bCust)
        delete!(remainCusts, bCust)
        initTime[k] = max(c.tmin, initTime[k] + tt[initPos[k],c.orig]) + tt[c.orig, c.dest] + 2*pb.customerTime
        initPos[k] = c.dest

        bTime = Inf; bCust = 0
        # update all customers for this taxi
        for c in remainCusts
            minTime = initTime[k] + tt[initPos[k], pb.custs[c].orig]
            if minTime <= pb.custs[c].tmax
                allTime[c,k] = max(minTime, pb.custs[c].tmin) - initTime[k]
            else
                allTime[c,k] = Inf
            end
            if bestTaxi[c] == k
                bestTaxi[c] = indmin(allTime[c,:])
                bestTime[c] = allTime[c,bestTaxi[c]]
            elseif allTime[c,k] < bestTime[c]
                bestTime[c] = allTime[c,k]
                bestTaxi[c] = k
            end

            if bestTime[c] == Inf
                delete!(remainCusts, c)
            elseif bestTime[c] < bTime
                bTime = bestTime[c]
                bCust = c
            end
        end

        verbose && i%100 == 0 && @printf("\r%d / %d customers inserted", i, nCusts); i+=1
    end
    verbose && print("\n")
    sol.profit = solutionProfit(pb,sol.custs)
    # updateTimeWindows!(pb, sol.custs)
    return sol
end
