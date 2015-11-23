#----------------------------------------
#-- Insert a non-taken customer into a time-window solution
#----------------------------------------

"""
    Take an IntervalSolution and insert a not-taken customer, with minimal cost
    - !! do not update solution cost !!
"""
function insertCustomer!(pb::TaxiProblem, sol::IntervalSolution, cId::Int, taxis = 1:length(pb.taxis); earliest::Bool=false)
    #-------------------------
    # Select the taxi to assign
    #-------------------------
    if !sol.notTaken[cId]
        error("Customer already inserted")
    end
    c = pb.custs[cId]
    cDesc = pb.custs
    custTime = pb.customerTime
    mincost = Inf
    mintaxi = 0
    position = 0
    #We need the shortestPaths
    tt = traveltimes(pb)
    tc = travelcosts(pb)

    #We test the new customer for each taxi
    for k in taxis
        custs = sol.custs[k]
        initPos = pb.taxis[k].initPos
        initTime = pb.taxis[k].initTime
        #First Case: taking customer before all the others
        if initTime + tt[initPos, c.orig] <= c.tmaxt
            if length(custs) == 0 #if no customer at all
                cost = tc[initPos, c.orig] + tc[c.orig, c.dest] -
                (tt[initPos, c.orig] + tt[c.orig, c.dest]) * pb.waitingCost
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
                tt[cLast.dest, c.orig] <= c.tmaxt
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
                if custs[i].tInf + 2*custTime + tt[ci.orig, ci.dest] + tt[ci.dest, c.orig] <= c.tmaxt &&
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

    #-------------------------
    # Insert customer into selected taxi's assignments
    #-------------------------
    i = position

    #If customer can be assigned
    if mintaxi != 0
        t = pb.taxis[mintaxi]
        custs = sol.custs[mintaxi]
        #If customer is to be inserted in first position
        if i == 1
            tmin = max(t.initTime + tt[t.initPos, c.orig], c.tmin)
            if length(custs) == 0
                push!( custs, AssignedCustomer(c.id, tmin, c.tmaxt))
            else
                tmaxt = min(c.tmaxt,custs[1].tSup - tt[c.orig,c.dest] -
                tt[c.dest,cDesc[custs[1].id].orig] - 2*custTime)
                insert!(custs, 1, AssignedCustomer(c.id, tmin, tmaxt))
            end
        else
            tmin = max(c.tmin, custs[i-1].tInf + 2*custTime +
            tt[cDesc[custs[i-1].id].orig, cDesc[custs[i-1].id].dest] +
            tt[cDesc[custs[i-1].id].dest, c.orig])
            if i > length(custs) #If inserted in last position
                push!(custs, AssignedCustomer(c.id, tmin, c.tmaxt))
            else
                tmaxt = min(c.tmaxt,custs[i].tSup - tt[c.orig,c.dest] -
                tt[c.dest,cDesc[custs[i].id].orig] - 2*custTime)
                insert!(custs, i, AssignedCustomer(c.id, tmin, tmaxt))
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
        sol.notTaken[cId] = false
    end
    return mincost, mintaxi, position
end


"""
    split a taxi timeline and tries to switch the last part with another taxi's
    returns either the previous solution, or construct a new one and returns it
    suppose that no other customer can be inserted in current solution
    the new solution is returned even if its cost is not as good as the previous one
"""
function switchCustomers!(pb::TaxiProblem, sol::IntervalSolution, k::Int, i::Int)
    #Step 1: find the best taxi.
    # criterion: minimum "insertcost"
    bestCost = Inf
    bestPos  = -1
    bestK    = -1
    for k2 in 1:length(pb.taxis)
        if k2==k
            continue
        end
        cost, pos = insertCost(pb, sol, k2, sol2.custs[k][i])
        if cost < bestCost
            bestCost = cost
            bestPos  = pos
            bestK    = k2
        end
    end
    if bestCost == Inf
        return sol
    end

    priorNotTaken = copy(sol.notTaken)

    #Step 2: switch the two timelines at the given position
    switchTimelines!(pb,sol,k,i-1,bestK,bestPos)

    #Step3: tries to insert all customers
    for c in 1:length(pb.custs)
        if priorNotTaken[c]
            insertCustomer!(pb, sol, c, [k, bestK])
        elseif sol2.notTaken[c]
            insertCustomer!(pb, sol, c)
        end
    end
    sol.cost = solutionCost(pb, sol.custs)
end

"""
    Performs a timeline switch between k1 and k2, at positions i1 and i2
    - but k1 may not be able to take all of k2's customers (in this case, we reject them)
    - and same with k2 for k1 customers
    - i1 and i2 are positions of the customer right before the switch (0 if whole switch)
"""
function switchTimelines!(pb::TaxiProblem, s::IntervalSolution, k1::Int, i1::Int, k2::Int, i2::Int)
    tt = traveltimes(pb)
    c1 = s.custs[k1][(i1+1):end]
    c2 = s.custs[k2][(i2+2):end]



    # First step: insert k2's customers into k1 (reject customers until we can insert them)
    s.custs[k1] = s.custs[k1][1:i1]
    if isempty(s.custs[k1])
        t = pb.taxis[k1]
        freeTime = t.initTime
        freeLoc  = t.initPos
    else
        c  = s.cust[k1][end]
        c0 = pb.custs[c.id]
        freeTime = c.tInf + 2*pb.customerTime + tt[c0.orig, c0.dest]
        freeLoc  = c0.dest
    end
    firstCust = length(c2) + 1
    for i,c in enumerate(c2)
        c0 = custs[c.id]
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
        c  = s.cust[k2][end]
        c0 = pb.custs[c.id]
        freeTime = c.tInf + 2*pb.customerTime + tt[c0.orig, c0.dest]
        freeLoc  = c0.dest
    end
    firstCust = length(c1) + 1
    for i,c in enumerate(c1)
        c0 = custs[c.id]
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
                c.tInf + 2*pb.customerTime + tt[c0.orig, c0.dest],i)
    end
end
