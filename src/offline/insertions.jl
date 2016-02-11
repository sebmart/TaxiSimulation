

"""
- split a taxi timeline and tries to switch the last part with another taxi's
- updates solution, and returns instructions to revert
"""
function switchCustomers!(pb::TaxiProblem, sol::IntervalSolution, k::Int, i::Int, bestK::Int = -1)
    solUpdates = PartialSolution()
    #Step 1: find the best taxi (if not given)
    # criterion: minimum "insertcost"
    if bestK == -1
        bestCost = Inf
        bestPos  = -1

        for k2 in 1:length(pb.taxis)
            if k2==k
                continue
            end
            cost, pos = insertCost(pb, sol, k2, sol.custs[k][i])
            if cost < bestCost
                bestCost = cost
                bestPos  = pos
                bestK    = k2
            end
        end

    else
        bestCost, bestPos = insertCost(pb,sol,bestK, sol.custs[k][i])
    end
    if bestCost == Inf
        return solUpdates
    end


    priorNotTaken = deepcopy(sol.notTaken)

    #Step 2: switch the two timelines at the given position
    addPartialSolution!(solUpdates,switchTimelines!(pb,sol,k,i-1,bestK,bestPos))

    #Step3: tries to insert all customers
    for c in 1:length(pb.custs)
        if priorNotTaken[c]
            addPartialSolution!(solUpdates,insertCustomer!(pb, sol, c, [k, bestK]))
        elseif sol.notTaken[c]
            addPartialSolution!(solUpdates,insertCustomer!(pb, sol, c))
        end
    end
    return solUpdates
end

"""
    Performs a timeline switch between k1 and k2, at positions i1 and i2
    - but k1 may not be able to take all of k2's customers (in this case, we reject them)
    - and same with k2 for k1 customers
    - i1 and i2 are positions of the customer right before the switch (0 if whole switch)
    - returns instructions to revert
"""
function switchTimelines!(pb::TaxiProblem, s::IntervalSolution, k1::Int, i1::Int, k2::Int, i2::Int)
    tt = traveltimes(pb)
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
        s.notTaken[c2[i].id] = true
    end
    append!(s.custs[k1],c2[firstCust:end])
    updateTimeWindows!(pb,s,k1)


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
        s.notTaken[c1[i].id] = true
    end
    append!(s.custs[k2],c1[firstCust:end])
    updateTimeWindows!(pb,s,k2)
    return solUpdates
end


"""
    helper function: compute the cost of inserting customer c and the followers into taxi
    two conditions:
    - tries to keep as many of the previous customers as possible
    - has to be able to pick-up all the following customers too
    The cost can be computed different ways.
    - travel time from last place.
    - ==> total time from last action.
    - same with costs
"""
function insertCost(pb::TaxiProblem, sol::IntervalSolution, k::Int, newC::AssignedCustomer)
    tt = traveltimes(pb)
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
end
