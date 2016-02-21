###################################################
## offline/solutionupdates.jl
## Methods to modify/update an Offline solution
###################################################

"""
    `insertCustomer` Take an offline sol. and insert a rejected customer, with minimal cost
    - !! do not update solution cost !! => set it to Inf
    - returns instruction to revert to previous solution
    - only consider the given taxis
"""
function insertCustomer!(sol::OfflineSolution, cID::Int, taxis = 1:length(sol.pb.taxis); earliest::Bool=false)
    if ! (cID in sol.rejected)
        error("Customer already inserted")
    end

    #We test the new customer for each taxi in the least, and we keep the best candidate
    bestCost = Inf
    bestPos  = -1
    bestTaxi = -1
    for k in taxis
        pos, cost = insertCost(sol.pb, cID, k, sol.custs[k], earliest)
        if pos != -1 && cost < bestCost # if insertion is possible and better
            bestCost = cost
            bestPos  = pos
            bestTaxi = k
        end
    end

    #If customer can be inserted, we insert it and return the revert update
    if bestTaxi == -1
        return EmptyUpdate
    else
        solUpdates = PartialSolution()
        addPartialSolution!(solUpdates, bestTaxi, sol.custs[bestTaxi])
        forceInsert!(sol.pb, cID, bestTaxi, sol.custs[bestTaxi], bestPos)
        delete!(sol.rejected,cID)
        return solUpdates
    end
end

"""
    `insertCost`, helper function that compute cost and position of inserting a customer
    in a taxi's timeline. pos = -1 if unfeasible.
    - Tractability bottleneck => really optimized
"""
function insertCost(pb::TaxiProblem, cID::Int, k::Int, tw::Vector{CustomerTimeWindow}, earliest::Bool)
@inbounds begin
    tt = getPathTimes(pb.times)
    tc = getPathTimes(pb.costs)
    c = pb.custs[cID]
    t = pb.taxis[k]

    #####
    # first step:  "easy" bounds to discard insertions without using tt (tractability)
    minC = 1
    while minC <= length(tw) && tw[minC].tSup < c.tmin
        minC += 1
    end
    maxC = length(tw)
    while maxC >= 1 && tw[maxC].tInf > c.tmax
        maxC -= 1
    end
    if maxC == 0 && t.initTime > c.tmax # special case for first pickup
        return -1, Inf
    end

    #####
    # second step: refine bounds using tt (but not too much)
    custTime = tt[c.orig, c.dest]
    while minC <= length(tw) &&
         tw[minC].tSup < c.tmin + custTime + tt[c.dest, pb.custs[tw[minC].id].orig] + 2*pb.customerTime
        minC += 1
    end
    while maxC >= minC-1 && maxC >= 1 &&
         tw[maxC].tInf + tt[pb.custs[tw[maxC].id].orig, pb.custs[tw[maxC].id].dest] + tt[pb.custs[tw[maxC].id].dest, c.orig] + 2*pb.customerTime > c.tmax
        maxC -= 1
    end
    if maxC < minC-1 || (maxC == 0 && t.initTime + tt[t.initPos, c.orig] > c.tmax) # we can now eliminate some solutions
        return -1, Inf
    end

    #####
    # last step: compute feasibility and cost on all remaining possible insertions and returns best one
    bestPos = -1; bestCost = Inf
    custCost = tc[c.orig, c.dest]
    # special case if before first customer
    if minC == 1
        # two cases: no customer or some
        if isempty(tw)
            # feasible: we have already tested t.initTime + tt[t.initPos, c.orig] <= c.tmax
            bestCost = tc[t.initPos, c.orig] + custCost -
            (tt[t.initPos, c.orig] + custTime) * pb.waitingCost
            if earliest
                bestCost = EPS*bestCost + max(0., t.initTime + tt[t.initPos, c.orig] - c.tmin)
            end
            return 1, bestCost
        elseif max(t.initTime + tt[t.initPos, c.orig], c.tmin) + custTime +
                tt[c.dest, pb.custs[tw[1].id].orig] + 2*pb.customerTime <= tw[1].tSup
            bestCost = tc[t.initPos, c.orig] + custCost + tc[c.dest, pb.custs[tw[1].id].orig] -
            tc[t.initPos, pb.custs[tw[1].id].orig] - (tt[t.initPos, c.orig] + custTime +
            tt[c.dest, pb.custs[tw[1].id].orig] - tt[t.initPos, pb.custs[tw[1].id].orig]) * pb.waitingCost
            if earliest
                bestCost = EPS*bestCost + max(0., t.initTime + tt[t.initPos, c.orig] - c.tmin)
            end
            bestPos = 1
        end
        minC += 1
    end

    #Second Case: taking customer after all the others (not empty now)
    if maxC == length(tw)
        # feasibility is already verified
        cLast = pb.custs[tw[end].id]
        cost = tc[cLast.dest, c.orig] + tc[c.orig, c.dest] -
        (tt[cLast.dest, c.orig] + custTime) * pb.waitingCost
        if earliest
            cost = EPS*cost + max(0., tw[end].tInf + 2*pb.customerTime + tt[cLast.orig, cLast.dest] +
                tt[cLast.dest, c.orig] - c.tmin)
        end
        if cost < bestCost
            bestCost = cost
            bestPos = length(tw) + 1
        end
        maxC -= 1
    end

    #Last Case : insertions in between two customers
    while minC <= maxC+1
        c1 = pb.custs[tw[minC-1].id]
        c2 = pb.custs[tw[minC].id]
        if max(tw[minC-1].tInf + 2*pb.customerTime  + tt[c1.orig, c1.dest] + tt[c1.dest, c.orig], c.tmin)+
            custTime + 2*pb.customerTime  + tt[c.dest, c2.orig] <= tw[minC].tSup
            cost = tc[c1.dest, c.orig] + custCost +
            tc[c.dest,c2.orig] -  tc[c1.dest, c2.orig] -
            (tt[c1.dest, c.orig] + custTime +
            tt[c.dest, c2.orig] - tt[c1.dest, c2.orig]) * pb.waitingCost
            if earliest
                cost = EPS*cost + max(0., tw[minC-1].tInf + 2*pb.customerTime  + tt[c1.orig, c1.dest] + tt[c1.dest, c.orig] - c.tmin)
            end
            if cost < bestCost
                bestCost = cost
                bestPos = minC
            end
        end
        minC += 1
    end
    return bestPos, bestCost
end #inbounds
end

"""
    `forceInsert!`, helper function that insert customer into taxi timeline
     without checking feasibility
"""
function forceInsert!(pb::TaxiProblem, cID::Int, k::Int, tw::Vector{CustomerTimeWindow}, i::Int)
@inbounds begin
    t = pb.taxis[k]
    tt = getPathTimes(pb.times)
    c  = pb.custs[cID]
    #If customer is to be inserted in first position
    if i == 1
        tmin = max(t.initTime + tt[t.initPos, c.orig], c.tmin)
        if length(tw) == 0
            push!(tw, CustomerTimeWindow(c.id, tmin, c.tmax))
        else
            tmax = min(c.tmax, tw[1].tSup - tt[c.orig,c.dest] -
            tt[c.dest,pb.custs[tw[1].id].orig] - 2*pb.customerTime)
            insert!(tw, 1, CustomerTimeWindow(c.id, tmin, tmax))
        end
    else
        tmin = max(c.tmin, tw[i-1].tInf + 2*pb.customerTime +
        tt[pb.custs[tw[i-1].id].orig, pb.custs[tw[i-1].id].dest] +
        tt[pb.custs[tw[i-1].id].dest, c.orig])
        if i > length(tw) #If inserted in last position
            push!(tw, CustomerTimeWindow(c.id, tmin, c.tmax))
        else
            tmax = min(c.tmax, tw[i].tSup - tt[c.orig, c.dest] -
            tt[c.dest, pb.custs[tw[i].id].orig] - 2*pb.customerTime)
            insert!(tw, i, CustomerTimeWindow(c.id, tmin, tmax))
        end
    end

    #-------------------------
    # Update the freedom intervals of the other assigned customers (just half the work)
    #-------------------------
    for j = (i-1):(-1):1
        tw[j].tSup = min(tw[j].tSup, tw[j+1].tSup - 2*pb.customerTime -
        tt[pb.custs[tw[j].id].orig, pb.custs[tw[j].id].dest] -
        tt[pb.custs[tw[j].id].dest, pb.custs[tw[j+1].id].orig])
    end
    for j = (i+1):length(tw)
        tw[j].tInf = max(tw[j].tInf, tw[j-1].tInf + 2*pb.customerTime +
        tt[pb.custs[tw[j-1].id].orig, pb.custs[tw[j-1].id].dest] +
        tt[pb.custs[tw[j-1].id].dest, pb.custs[tw[j].id].orig])
    end
end #inbounds
end




"""
    `switchCustomers!`,   split a taxi timeline and tries to switch the last part with another taxi's
    - updates solution, and returns instructions to revert
"""
function switchCustomers!(sol::OfflineSolution, k::Int, i::Int, bestK::Int = -1)
    pb = sol.pb

    #Step 1: find the best taxi (if not given)
    # criterion: minimum "insertcost"
    if bestK == -1
        bestCost = Inf
        bestPos  = -1

        for k2 in eachindex(pb.taxis)
            if k2==k
                continue
            end
            cost, pos = switchCost(sol, k2, sol.custs[k][i])
            if cost < bestCost
                bestCost = cost
                bestPos  = pos
                bestK    = k2
            end
        end

    else
        bestCost, bestPos = switchCost(sol,bestK, sol.custs[k][i])
    end
    if bestCost == Inf
        return EmptyUpdate
    end

    solUpdates = PartialSolution()
    priorRejected = deepcopy(sol.rejected)

    #Step 2: switch the two timelines at the given position
    addPartialSolution!(solUpdates,switchTimelines!(sol,k,i-1,bestK,bestPos))

    #Step3: tries to insert all customers
    for c in eachindex(pb.custs)
        if c in priorRejected
            addPartialSolution!(solUpdates,insertCustomer!(sol, c, [k, bestK]))
        elseif c in sol.rejected
            addPartialSolution!(solUpdates,insertCustomer!(sol, c))
        end
    end
    return solUpdates
end


"""
    `switchTimelines!(s,k1,i1,k2,i2)`, Performs a timeline switch between k1 and k2,
     at positions i1 and i2
    - but k1 may not be able to take all of k2's customers (in this case, we reject them)
    - and same with k2 for k1 customers
    - i1 and i2 are positions of the customer right before the switch (0 if whole switch)
    - returns instructions to revert
"""
function switchTimelines!(s::OfflineSolution, k1::Int, i1::Int, k2::Int, i2::Int)
    pb = s.pb
    tt = getPathTimes(pb.times)
    c1 = s.custs[k1][(i1+1):end]
    c2 = s.custs[k2][(i2+1):end]

    solUpdates = PartialSolution()
    addPartialSolution!(solUpdates,k1,s.custs[k1])
    addPartialSolution!(solUpdates,k2,s.custs[k2])

    # First step: insert k2's customers into k1 (reject customers until we can insert them)
    s.custs[k1] = s.custs[k1][1:i1]
    if isempty(s.custs[k1])
        t = pb.taxis[k1]
        freeTime = t.initTime
        freeLoc  = t.initPos
    else
        c  = s.custs[k1][end]
        c0 = pb.custs[c.id]
        freeTime = c.tInf + 2*pb.customerTime + tt[c0.orig, c0.dest]
        freeLoc  = c0.dest
    end
    firstCust = length(c2) + 1
    for (i,c) in enumerate(c2)
        c0 = pb.custs[c.id]
        if freeTime + tt[freeLoc, c0.orig] <= c.tSup
            firstCust = i
            break
        end
    end
    for i in 1:(firstCust-1) #reject the customers
        push!(s.rejected, c2[i].id)
    end
    append!(s.custs[k1],c2[firstCust:end])
    updateTimeWindows!(s,k1)


    #Second step: insert k1's customers into k2 (reject customers until we can insert them)
    s.custs[k2] = s.custs[k2][1:i2]
    if isempty(s.custs[k2])
        t = pb.taxis[k2]
        freeTime = t.initTime
        freeLoc  = t.initPos
    else
        c  = s.custs[k2][end]
        c0 = pb.custs[c.id]
        freeTime = c.tInf + 2*pb.customerTime + tt[c0.orig, c0.dest]
        freeLoc  = c0.dest
    end
    firstCust = length(c1) + 1
    for (i,c) in enumerate(c1)
        c0 = pb.custs[c.id]
        if freeTime + tt[freeLoc, c0.orig] <= c.tSup
            firstCust = i
            break
        end
    end

    for i in 1:(firstCust-1) #reject the customers
        push!(s.rejected, c1[i].id)
    end
    append!(s.custs[k2],c1[firstCust:end])
    updateTimeWindows!(s,k2)
    return solUpdates
end


"""
    `switchCost`, helper function: compute the cost of inserting customer newC and the followers into taxi k
    two conditions:
    - tries to keep as many of the previous customers as possible
    - has to be able to pick-up all the following customers too
    The cost can be computed different ways.
    - travel time from last place.
    - ==> total time from last action.
    - same with costs
"""
function switchCost(sol::OfflineSolution, k::Int, newC::CustomerTimeWindow)
@inbounds begin

    pb = sol.pb
    tt = getPathTimes(pb.times)
    custs = pb.custs
    nC = custs[newC.id]
    t = pb.taxis[k]
    if t.initTime + tt[t.initPos, nC.orig] > newC.tSup
        return (Inf, -1)
    end
    i = 0
    for c in sol.custs[k]
        c0 = custs[c.id]
        if c.tInf + 2*pb.customerTime + tt[c0.orig, c0.dest] + tt[c0.dest, nC.orig] > newC.tSup
            break
        else
            i += 1
        end
    end
    if i == 0
        return (max(t.initTime + tt[t.initPos, nC.orig], nC.tmin) - t.initTime, 0)
    else
        c = sol.custs[k][i]
        c0 = custs[c.id]
        return (max(c.tInf + 2*pb.customerTime + tt[c0.orig, c0.dest] + tt[c0.dest, nC.orig], nC.tmin) -
                (c.tInf + 2*pb.customerTime + tt[c0.orig, c0.dest]),i)
    end
end #inbounds
end
