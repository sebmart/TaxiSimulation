###################################################
## offline/localheuristics.jl
## introduce local changes in solution to find a better one
###################################################
"""
    `localDescent`: switches two taxis timelines to locally optimize a solution
     (fast on large instances)
     - parameter `random = true` to try any combination, = false to do the best one
"""
function localDescent!(pb::TaxiProblem, sol::OfflineSolution;
     verbose::Bool = true, maxSearch::Int = 1, iterations::Int=typemax(Int),
      maxTime::Real=Inf)

    sol = localDescentWithStats!(pb, sol, verbose, maxSearch, iterations, maxTime)[1]
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
            maxSearch::Int, iterations::Int, maxTime::Real)
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
            return sol, 0, 0
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
function smartSearch!(pb::TaxiProblem, sol::OfflineSolution; verbose::Bool = true,
     maxTime::Float64=Inf, updateFreq::Float64 = 1., maxSearch=1)
     initT = time()
     noProgress = 0
     prevRatio = 0.
     goingUp = true
     success, trys = 1, 1
     totalTrys = 0
     totalSuccess = 0
     momentum = 0
     while time() - initT <= maxTime
         min,sec = minutesSeconds(time() - initT)
         verbose && @printf("\r\$%.2f, %dm%02ds, %d/%d, %.3f%% successful, search depth: %d(%d), update: %.2fs  ",
         sol.profit, min, sec, totalSuccess, totalTrys, 100*success/trys, maxSearch, momentum, updateFreq)
         sol, success, trys = localDescentWithStats!(pb, sol, false, maxSearch, typemax(Int), updateFreq)
         if success <= 5
             updateFreq *= 1.5
             momentum = 0 # to avoid getting trapped
         end
         noProgress = (success==0) ? noProgress + 1 : 0
         if noProgress == 2 #stopping criterion
             verbose && println("No more improvements: stop                         ")
             break
         end
         newRatio = success / trys

         if momentum >= 1
             momentum += (newRatio < prevRatio) ? -1 : 1
             prevRatio = newRatio/50. + prevRatio*1.08
             goingUp = newRatio >= prevRatio
         elseif momentum <= -1
             momentum += (newRatio < prevRatio) ? 1 : -1
             prevRatio = newRatio/50. + prevRatio*1.08
             goingUp = newRatio < prevRatio
         else # =0
             prevRatio = newRatio
             momentum += goingUp ? 1 : -1
         end
         maxSearch += momentum
         maxSearch = max(1, maxSearch)

         totalTrys += trys
         totalSuccess += success
     end
     updateTimeWindows!(sol)
     sol.profit = solutionProfit(pb,sol.custs)
     return sol
end

function smartSearch(pb::TaxiProblem, start::OfflineSolution = orderedInsertions(pb); args...)
    sol = copySolution(start)
    smartSearch!(pb,sol; args...)
    return sol
end

"""
    `backboneSearch` searches is a local search that iteratively solves LPs to find a good
     backbone, and MIPs to update the solution
"""
function backboneSearch(fpb::FlowProblem, start::FlowSolution;
                            maxEdges::Int=typemax(Int),
                            localityRatio::Real = 0.5,
                            maxTime::Real = 60,
                            maxExplorationTime::Real=20,
                            verbose::Int=1, args...)
    i = 0
    sol = copySolution(start)
    verbose > 0 && @printf("Initial profit: \$%.2f\n", solutionApproxProfit(fpb, sol))
    initT = time()
    value::Float64 = Inf
    while time() - initT < maxTime
        iterStart = time()
        i += 1
        verbose > 0 && @printf("Iteration %d: ", i)
        # backbone search phase
        backbone = emptyFlow(fpb)
        addLinks!(backbone, sol)
        tw = timeWindows(fpb, sol)
        while ne(backbone.g) <= maxEdges * localityRatio && (time()-iterStart) <= maxExplorationTime
            lpSol = lpFlow(fpb, randPickupTimes(fpb, tw), verbose=false)
            addLinks!(backbone, lpSol)
        end

        while ne(backbone.g) <= maxEdges && (time()-iterStart) <= maxExplorationTime
            lpSol = lpFlow(fpb, randPickupTimes(fpb), verbose=(verbose > 2))
            addLinks!(backbone, lpSol)
        end
        verbose > 0 && @printf("%.1fs exploration - ", time() - iterStart)

        sol = mipFlow(backbone, sol, MIPGap=1e-7, Presolve=2, FlowCoverCuts=2, verbose=(verbose>1); args...)

        verbose > 0 && @printf("%.1fs total - \$%.2f profit\n", time() - iterStart, solutionApproxProfit(fpb, sol))
    end
    return sol
end

function backboneSearch(pb::TaxiProblem, start::OfflineSolution = orderedInsertions(pb); args...)
    fpb = FlowProblem(pb)
    sol = backboneSearch(fpb, FlowSolution(fpb, start); args...)
    return OfflineSolution(pb, fpb, sol)
end
