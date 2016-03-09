###################################################
## offline/localdescent.jl
## introduce local changes in solution to find a better one
###################################################

"""
    `localDescent`: switches two taxis timelines to locally optimize a solution
     (fast on large instances)
     - parameter `random = true` to try any combination, = false to do the best one
"""
function localDescent!(pb::TaxiProblem, sol::OfflineSolution;
     verbose::Bool = true, maxSearch::Int = 1, iterations::Int=typemax(Int),
      maxTime::Float64=Inf)

    sol = localDescentWithStats!(pb, sol, verbose, maxSearch, benchmark, iterations, maxTime)[1]
    updateTimeWindows!(sol)
    sol.profit = solutionProfit(pb,sol.custs)
    return sol
end

function localDescent(pb::TaxiProblem, start::OfflineSolution = orderedInsertions(pb); args...)
    sol = copySolution(start)
    localDescent!(pb,sol; args...)
    return sol
end

function localDescentWithStats!(pb::TaxiProblem, sol::OfflineSolution, verbose::Bool,
            maxSearch::Int, iterations::Int, maxTime::Float64)
    initT = time()

    if maxTime == Inf && iterations == typemax(Int)
        maxTime = 5.
    end

    nTaxis = length(pb.taxis)
    #if no customer
    if noassignment(sol)
        orderedInsertions!(sol)
        if noassignment(sol)
            verbose && println("Final: $(sol.profit) dollars")
            return sol
        end
        start = ordered
    end

    success = 0
    totalTrys = 0
    for trys in 1:iterations
        if time()-initT > maxTime
            break
        end
        ##############
        # Selecting first taxi and customer to split on (purely random!)
        k1 = rand(1:nTaxis)
        while isempty(sol.custs[k1])
            k1 = rand(1:nTaxis)
        end
        i1 = rand(eachindex(sol.custs[k1]))

        #################
        # Selecting second taxi and customer: randomly in the maxSearch best possibilities...
        searchBest = Tuple{Float64, Int}[(Inf,-1) for i in 1:maxSearch]
        countWait = rand(Bool)
        costOrderF(x::Tuple{Float64, Int}) = x[1]
        costOrder = Base.Order.ReverseOrdering(Base.Order.By(costOrderF))
        switch = sol.custs[k1][i1]
        for k2 in eachindex(pb.taxis)
            if k2 != k1
                cost, _ = switchCost(sol, k2, switch, countWait)
                if cost < searchBest[1][1]
                    Collections.heappop!(searchBest, costOrder)
                    Collections.heappush!(searchBest, (cost, k2), costOrder)
                end
            end
        end
        cost, k2 = rand(searchBest)
        if cost == Inf
            continue
        end
        _, i2 = switchCost(sol, k2, switch, countWait) # need to recompute i2

        #################
        # Finally switching!
        revertSol = switchTimelines!(sol, k1, i1 - 1, k2, i2) # -1 because we need to give at least one cust 1=>2

        updateProfit = profitDiff(sol,revertSol)
        if updateProfit > 0.
            sol.profit += updateProfit
            success += 1
            t = time()-initT
            min,sec = minutesSeconds(t)
            verbose && (@printf("\r====Try: %i, %.2f dollars (%dm%ds, %.2f tests/min, %.3f%% successful)   ",
            trys, sol.profit, min, sec, 60.*trys/t, success/(trys-1.)*100.))
        else
            updateSolution!(sol,revertSol)
        end
        totalTrys = trys
    end
    return sol, success, totalTrys
end

"""
    `smartSearch!`, localSearch with maxSearch parameter automatically and smartly updated
"""
function smartSearch!(pb::TaxiProblem, sol::OfflineSolution; verbose::Bool = true, maxTime::Float64=Inf)
     initT = time()
     updateFreq = 1. # Update frequency in seconds (increase progressively)
     maxSearch = 1
     noProgress = 0
     prevRatio = 0.
     goingUp = true
     success, trys = 1, 1
     totalTrys = 0
     while time() - initT <= maxTime
         min,sec = minutesSeconds(time() - initT)
         @printf("\r\$%.2f, %dm%02ds, %d trys, %.3f%% successful, search depth: %d, update: %.2fs    ",
         sol.profit, min,sec, totalTrys, 100*success/trys, maxSearch, updateFreq)
         sol, success, trys = localDescentWithStats!(pb, sol, false, maxSearch, typemax(Int), updateFreq)
         success <= 5  && (updateFreq *= 1.5)# randomly set
         noProgress = (success==0) ? noProgress + 1 : 0
         if noProgress == 3 #stopping criterion
             verbose && println("No more improvements: stop                         ")
             break
         end
         newRatio = success / trys
         if newRatio < prevRatio
             goingUp = !goingUp
         end
         maxSearch += goingUp ? 1 : - 1
         maxSearch = max(1, maxSearch)
         prevRatio = newRatio
         totalTrys += trys
     end
     updateTimeWindows!(sol)
     sol.profit = solutionProfit(pb,sol.custs)
     return sol
end
