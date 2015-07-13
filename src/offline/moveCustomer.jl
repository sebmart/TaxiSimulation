#----------------------------------------
#-- Insert a non-taken customer into a time-window solution
#----------------------------------------

"Take an IntervalSolution and insert a not-taken customer"
function insertCustomer!(pb::TaxiProblem, sol::IntervalSolution, cId::Int)

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
    for (k,custs) in enumerate(sol.custs)
        initPos = pb.taxis[k].initPos
        initTime = pb.taxis[k].initTime
        #First Case: taking customer before all the others
        if initTime + tt[initPos, c.orig] <= c.tmaxt
            if length(custs) == 0 #if no customer at all
                cost = tc[initPos, c.orig] + tc[c.orig, c.dest] -
                (tt[initPos, c.orig] + tt[c.orig, c.dest]) * pb.waitingCost
                if cost < mincost
                    mincost = cost
                    position = 1
                    mintaxi = k
                end

                #if there is a customer after
            elseif length(custs) != 0
                c1 = cDesc[custs[1].id]

                if max(initTime + tt[initPos, c.orig], c.tmin) +
                    tt[c.orig, c.dest] + tt[c.dest, c1.orig] <= custs[1].tSup

                    cost = tc[initPos, c.orig] + tc[c.orig, c.dest] +
                    tc[c.dest,c1.orig] - tc[initPos, c1.orig] -
                    (tt[initPos, c.orig] + tt[c.orig, c.dest] +
                    tt[c.dest,c1.orig] - tt[initPos, c1.orig]) * pb.waitingCost
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
            tmin = max(c.tmin, custs[i-1].tInf + 2*custTime
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
            custs[j].tSup = min(custs[j].tSup, custs[j+1].tSup - 2*custTime
            tt[cDesc[custs[j].id].orig, cDesc[custs[j].id].dest] -
            tt[cDesc[custs[j].id].dest, cDesc[custs[j+1].id].orig])
        end
        for j = (i+1) :length(custs)
            custs[j].tInf = max(custs[j].tInf, custs[j-1].tInf + 2*custTime
            tt[cDesc[custs[j-1].id].orig, cDesc[custs[j-1].id].dest] +
            tt[cDesc[custs[j-1].id].dest, cDesc[custs[j].id].orig])
        end
        sol.notTaken[cId] = false
    end
    return mincost, mintaxi, position
end

"Split a customer list and exchange with another taxi. Returns the best between this solution and the previous one"
function splitAndMove!(pb::TaxiProblem, sol2::IntervalSolution, k::Int, i::Int, k2::Int)
    tt = traveltimes(pb)
    custs = pb.custs
    sol = copySolution(sol2)

    #-------------------------
    # UPDATE TAXI B
    #-------------------------

    #Look for the first place we can insert it in k2
    custsA = sol.custs[k][i:end]
    #Extract the list to move from k
    sol.custs[k] = sol.custs[k][1:i-1]

    while !isempty(custsA) && pb.taxis[k2].initTime + tt[pb.taxis[k2].initPos, custs[custsA[1].id].orig] > custsA[1].tSup
        sol.notTaken[custsA[1].id] = true
        deleteat!(custsA, 1)
    end

    #if just impossible to assign it => stop

    if !isempty(custsA)
        i2 = 1
        for (j,c) in enumerate(sol.custs[k2])
            if c.tInf + 2*custTime + tt[custs[c.id].orig, custs[c.id].dest] +
                tt[custs[c.id].dest, custs[custsA[1].id].orig] <=
                custsA[1].tSup
                i2 = j+1
            else
                break
            end
        end

        #Extract the list to move from k2
        custsB = sol.custs[k2][i2:end]
        sol.custs[k2] = sol.custs[k2][1:i2-1]

        #Update the windows of custsA
        if isempty(sol.custs[k2])
            custsA[1].tInf = max(custs[custsA[1].id].tmin, pb.taxis[k2].initTime +
            tt[pb.taxis[k2].initPos, custs[custsA[1].id].orig])
        else
            custsA[1].tInf = max(custs[custsA[1].id].tmin, 2*custTime+
            sol.custs[k2][end].tInf + tt[custs[sol.custs[k2][end].id].orig, custs[sol.custs[k2][end].id].dest]
            + tt[custs[sol.custs[k2][end].id].dest, custs[custsA[1].id].orig])
        end
        for j = 2: length(custsA)
            custsA[j].tInf = max(custs[custsA[j].id].tmin, 2*custTime +
            custsA[j-1].tInf + tt[custs[custsA[j-1].id].orig, custs[custsA[j-1].id].dest]
            + tt[custs[custsA[j-1].id].dest, custs[custsA[j].id].orig])
        end
        #update the windows of k2
        if !isempty(sol.custs[k2])
            sol.custs[k2][end].tSup = min(custs[sol.custs[k2][end].id].tmaxt,
            custsA[1].tSup - tt[custs[sol.custs[k2][end].id].orig, custs[sol.custs[k2][end].id].dest]
            - tt[custs[sol.custs[k2][end].id].dest, custs[custsA[1].id].orig] - 2*custTime)
            for j = (length(sol.custs[k2])-1):-1:1
                sol.custs[k2][j].tSup = min(custs[sol.custs[k2][j].id].tmaxt,
                sol.custs[k2][j+1].tSup - tt[custs[sol.custs[k2][j].id].orig, custs[sol.custs[k2][j].id].dest] -
                tt[custs[sol.custs[k2][j].id].dest, custs[sol.custs[k2][j+1].id].orig] - 2*custTime)
            end
        end
        #reconstruct k2 customers
        append!(sol.custs[k2], custsA)


        #-------------------------
        # UPDATE TAXI A
        #-------------------------

        #Removing customers we cannot take anymore

        i2 = 1
        if isempty(sol.custs[k])
            pos = pb.taxis[k].initPos
            initTime = pb.taxis[k].initPos
            for (j,c) in enumerate(custsB)
                if initTime + tt[pos, custs[c.id].orig] <= c.tSup
                    break
                else
                    i2 = j + 1
                end
            end

        else
            for (j,c) in enumerate(custsB)
                pc = sol.custs[k][end]
                if pc.tInf + tt[custs[pc.id].orig, custs[pc.id].dest] +
                    tt[custs[pc.id].dest, custs[c.id].orig] + 2*custTime<= c.tSup
                    break
                else
                    i2 = j+1
                end
            end
        end
        #We delete those we cannot take
        for j in 1:(i2 - 1)
            sol.notTaken[custsB[j].id] = true
        end

        custsB = custsB[i2: length(custsB)]

        if isempty(custsB)
            #Just update the window of taxi k
            if !isempty(sol.custs[k])
                sol.custs[k][end].tSup = custs[sol.custs[k][end].id].tmaxt
                for j = (length(sol.custs[k])-1):-1:1
                    sol.custs[k][j].tSup = min(custs[sol.custs[k][j].id].tmaxt,
                    sol.custs[k][j+1].tSup - tt[custs[sol.custs[k][j].id].orig, custs[sol.custs[k][j].id].dest]
                    - tt[custs[sol.custs[k][j].id].dest, custs[sol.custs[k][j+1].id].orig] - 2*custTime)
                end
            end
        else
            #Update the windows of custsB
            if isempty(sol.custs[k])
                custsB[1].tInf = max(custs[custsB[1].id].tmin, pb.taxis[k].initTime +
                tt[pb.taxis[k].initPos, custs[custsB[1].id].orig])
            else
                custsB[1].tInf = max(custs[custsB[1].id].tmin,
                sol.custs[k][end].tInf + tt[custs[sol.custs[k][end].id].orig, custs[sol.custs[k][end].id].dest]
                + tt[custs[sol.custs[k][end].id].dest, custs[custsB[1].id].orig] + 2*custTime)
            end
            for j = 2: length(custsB)
                custsB[j].tInf = max(custs[custsB[j].id].tmin,
                custsB[j-1].tInf + tt[custs[custsB[j-1].id].orig, custs[custsB[j-1].id].dest]
                + tt[custs[custsB[j-1].id].dest, custs[custsB[j].id].orig] + 2*custTime)
            end
            #update the windows of taxi k
            if !isempty(sol.custs[k])
                sol.custs[k][end].tSup = min(custs[sol.custs[k][end].id].tmaxt,
                custsB[1].tSup - tt[custs[sol.custs[k][end].id].orig, custs[sol.custs[k][end].id].dest]
                - tt[custs[sol.custs[k][end].id].dest, custs[custsB[1].id].orig] - 2*custTime)
                for j = (length(sol.custs[k])-1):-1:1
                    sol.custs[k][j].tSup = min(custs[sol.custs[k][j].id].tmaxt,
                    sol.custs[k][j+1].tSup - tt[custs[sol.custs[k][j].id].orig, custs[sol.custs[k][j].id].dest]
                    - tt[custs[sol.custs[k][j].id].dest, custs[sol.custs[k][j+1].id].orig] - 2*custTime)
                end
            end
            #reconstruct k customers
            append!(sol.custs[k], custsB)
        end
    end
    #-------------------------
    # INSERT other customers (can be made more efficient)
    #-------------------------
    freeCusts = collect(1: length(custs))[sol.notTaken]
    order = randomOrder( length(freeCusts))
    #For each free customer
    for i in 1:length(freeCusts)
        c = freeCusts[order[i]]
        insertCustomer!(pb,sol,c)
    end

    #compute the costs
    cost = solutionCost(pb, sol.custs)
    if cost <= sol.cost
        sol.cost = cost
        return sol
    else
        return sol2
    end
end
