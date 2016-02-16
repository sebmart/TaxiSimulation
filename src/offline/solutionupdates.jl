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
function insertCustomer!(sol::OfflineSolution, cId::Int, taxis = 1:length(sol.pb.taxis); earliest::Bool=false)
    if ! (cId in sol.rejected)
        error("Customer already inserted")
    end

    #We test the new customer for each taxi in the least, and we keep the best candidate
    bestCost = Inf
    bestPos  = -1
    bestTaxi = -1
    for k in taxis
        pos, cost = insertCost(sol.pb, cId, k, sol.custs[k])
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
        forceInsert!(sol.pb, cId, sol.custs[bestTaxi], bestPos)
        solUpdates = PartialSolution()
        addPartialSolution!(solUpdates, bestTaxi, custs)
        return solUpdate
    end
end

        #If customer is to be inserted in first position
        if i == 1
            tmin = max(t.initTime + tt[t.initPos, c.orig], c.tmin)
            if length(custs) == 0
                push!( custs, CustomerTimeWindow(c.id, tmin, c.tmax))
            else
                tmax = min(c.tmax, custs[1].tSup - tt[c.orig,c.dest] -
                tt[c.dest,cDesc[custs[1].id].orig] - 2*custTime)
                insert!(custs, 1, CustomerTimeWindow(c.id, tmin, tmax))
            end
        else
            tmin = max(c.tmin, custs[i-1].tInf + 2*custTime +
            tt[cDesc[custs[i-1].id].orig, cDesc[custs[i-1].id].dest] +
            tt[cDesc[custs[i-1].id].dest, c.orig])
            if i > length(custs) #If inserted in last position
                push!(custs, CustomerTimeWindow(c.id, tmin, c.tmax))
            else
                tmax = min(c.tmax,custs[i].tSup - tt[c.orig, c.dest] -
                tt[c.dest, cDesc[custs[i].id].orig] - 2*custTime)
                insert!(custs, i, CustomerTimeWindow(c.id, tmin, tmax))
            end
        end

        #-------------------------
        # Update the freedom intervals of the other assigned customers
        #-------------------------
        for j = (i-1) :(-1):1
            custs[j].tSup = min(custs[j].tSup, custs[j+1].tSup - 2*custTime -
            tt[cDesc[custs[j].id].orig, cDesc[custs[j].id].dest] -
            tt[cDesc[custs[j].id].dest, cDesc[custs[j+1].id].orig])
        end
        for j = (i+1) :length(custs)
            custs[j].tInf = max(custs[j].tInf, custs[j-1].tInf + 2*custTime +
            tt[cDesc[custs[j-1].id].orig, cDesc[custs[j-1].id].dest] +
            tt[cDesc[custs[j-1].id].dest, cDesc[custs[j].id].orig])
        end
        delete!(sol.rejected,cId)
        return solUpdates
    end
    end #inbounds
end




        custs = sol.custs[k]
        initPos = pb.taxis[k].initPos
        initTime = pb.taxis[k].initTime
        #First Case: taking customer before all the others
        if initTime + tt[initPos, c.orig] <= c.tmax
            if length(custs) == 0 #if no customer at all
                cost = tc[initPos, c.orig] + tc[c.orig, c.dest] -
                (tc[initPos, c.orig] + tt[c.orig, c.dest]) * pb.waitingCost
                if earliest
                    cost = EPS*cost + max(0., initTime + tt[initPos, c.orig] - c.tmin)
                end
                if cost < mincost
                    mincost = cost
                    position = 1
                    mintaxi = k
                end

                #if there is a customer after
            elseif length(custs) != 0
                c1 = cDesc[custs[1].id]

                if max(initTime + tt[initPos, c.orig], c.tmin) +
                    tt[c.orig, c.dest] + tt[c.dest, c1.orig] + 2*custTime <= custs[1].tSup

                    cost = tc[initPos, c.orig] + tc[c.orig, c.dest] +
                    tc[c.dest,c1.orig] - tc[initPos, c1.orig] -
                    (tt[initPos, c.orig] + tt[c.orig, c.dest] +
                    tt[c.dest,c1.orig] - tt[initPos, c1.orig]) * pb.waitingCost
                    if earliest
                        cost = EPS*cost + max(0., initTime + tt[initPos, c.orig] - c.tmin)
                    end
                    if cost < mincost
                        mincost = cost
                        position = 1
                        mintaxi = k
                    end
                end
            end
        end

        #Second Case: taking customer after all the others
        if length(custs) > 0
            cLast = cDesc[custs[end].id]
            if custs[end].tInf + 2*custTime + tt[cLast.orig, cLast.dest] +
                tt[cLast.dest, c.orig] <= c.tmax
                cost = tc[cLast.dest, c.orig] + tc[c.orig, c.dest] -
                (tt[cLast.dest, c.orig] + tt[c.orig, c.dest]) * pb.waitingCost
                if earliest
                    cost = EPS*cost + max(0., custs[end].tInf + 2*custTime + tt[cLast.orig, cLast.dest] +
                        tt[cLast.dest, c.orig] - c.tmin)
                end
                if cost < mincost
                    mincost = cost
                    position = length(custs) + 1
                    mintaxi = k
                end
            end
        end

        #Last Case: taking customer in-between two customers
        if length(custs) > 2
            for i in 1:length(custs)-1
                ci = cDesc[custs[i].id]
                cip1 = cDesc[custs[i+1].id]
                if custs[i].tInf + 2*custTime + tt[ci.orig, ci.dest] + tt[ci.dest, c.orig] <= c.tmax &&
                    max(custs[i].tInf + 2*custTime + tt[ci.orig, ci.dest] + tt[ci.dest, c.orig], c.tmin)+
                    tt[c.orig, c.dest] + 2*custTime + tt[c.dest, cip1.orig] <= custs[i+1].tSup
                    cost = tc[ci.dest, c.orig] + tc[c.orig, c.dest] +
                    tc[c.dest,cip1.orig] -  tc[ci.dest, cip1.orig] -
                    (tt[ci.dest, c.orig] + tt[c.orig, c.dest] +
                    tt[c.dest, cip1.orig] - tt[ci.dest, cip1.orig]) * pb.waitingCost
                    if earliest
                        cost = EPS*cost + max(0., custs[i].tInf + 2*custTime + tt[ci.orig, ci.dest] + tt[ci.dest, c.orig] - c.tmin)
                    end
                    if cost < mincost
                        mincost = cost
                        position = i+1
                        mintaxi = k
                    end
                end
            end
        end
    end
    solUpdates = EmptyUpdate
    #-------------------------
    # Insert customer into selected taxi's assignments
    #-------------------------
    i = position

    #If customer can be assigned
    if mintaxi != 0
        t = pb.taxis[mintaxi]
        custs = sol.custs[mintaxi]
        solUpdates = PartialSolution()
        addPartialSolution!(solUpdates, mintaxi, custs)
        #If customer is to be inserted in first position
        if i == 1
            tmin = max(t.initTime + tt[t.initPos, c.orig], c.tmin)
            if length(custs) == 0
                push!( custs, CustomerTimeWindow(c.id, tmin, c.tmax))
            else
                tmax = min(c.tmax, custs[1].tSup - tt[c.orig,c.dest] -
                tt[c.dest,cDesc[custs[1].id].orig] - 2*custTime)
                insert!(custs, 1, CustomerTimeWindow(c.id, tmin, tmax))
            end
        else
            tmin = max(c.tmin, custs[i-1].tInf + 2*custTime +
            tt[cDesc[custs[i-1].id].orig, cDesc[custs[i-1].id].dest] +
            tt[cDesc[custs[i-1].id].dest, c.orig])
            if i > length(custs) #If inserted in last position
                push!(custs, CustomerTimeWindow(c.id, tmin, c.tmax))
            else
                tmax = min(c.tmax,custs[i].tSup - tt[c.orig, c.dest] -
                tt[c.dest, cDesc[custs[i].id].orig] - 2*custTime)
                insert!(custs, i, CustomerTimeWindow(c.id, tmin, tmax))
            end
        end

        #-------------------------
        # Update the freedom intervals of the other assigned customers
        #-------------------------
        for j = (i-1) :(-1):1
            custs[j].tSup = min(custs[j].tSup, custs[j+1].tSup - 2*custTime -
            tt[cDesc[custs[j].id].orig, cDesc[custs[j].id].dest] -
            tt[cDesc[custs[j].id].dest, cDesc[custs[j+1].id].orig])
        end
        for j = (i+1) :length(custs)
            custs[j].tInf = max(custs[j].tInf, custs[j-1].tInf + 2*custTime +
            tt[cDesc[custs[j-1].id].orig, cDesc[custs[j-1].id].dest] +
            tt[cDesc[custs[j-1].id].dest, cDesc[custs[j].id].orig])
        end
        delete!(sol.rejected,cId)
    end
end #inbounds
    return solUpdates
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
    `switchCost`, helper function: compute the cost of inserting customer c and the followers into taxi
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
