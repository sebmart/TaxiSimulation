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
    #-------------------------
    # Select the taxi to assign
    #-------------------------
    if ! (cId in sol.rejected)
        error("Customer already inserted")
    end
    pb = sol.pb
    c = pb.custs[cId]
    cDesc = pb.custs
    custTime = pb.customerTime
    mincost = Inf
    mintaxi = 0
    position = 0
    #We need the shortestPaths
    tt(i::Int, j::Int) = traveltime(pb.times,i,j)
    tc(i::Int, j::Int) = traveltime(pb.costs,i,j)


    #We test the new customer for each taxi
    for k in taxis
        custs = sol.custs[k]
        initPos = pb.taxis[k].initPos
        initTime = pb.taxis[k].initTime
        #First Case: taking customer before all the others
        if initTime + tt(initPos, c.orig) <= c.tmax
            if length(custs) == 0 #if no customer at all
                cost = tc(initPos, c.orig) + tc(c.orig, c.dest) -
                (tc(initPos, c.orig) + tt(c.orig, c.dest)) * pb.waitingCost
                if earliest
                    cost = EPS*cost + max(0., initTime + tt(initPos, c.orig) - c.tmin)
                end
                if cost < mincost
                    mincost = cost
                    position = 1
                    mintaxi = k
                end

                #if there is a customer after
            elseif length(custs) != 0
                c1 = cDesc[custs[1].id]

                if max(initTime + tt(initPos, c.orig), c.tmin) +
                    tt(c.orig, c.dest) + tt(c.dest, c1.orig) + 2*custTime <= custs[1].tSup

                    cost = tc(initPos, c.orig) + tc(c.orig, c.dest) +
                    tc(c.dest,c1.orig) - tc(initPos, c1.orig) -
                    (tt(initPos, c.orig) + tt(c.orig, c.dest) +
                    tt(c.dest,c1.orig) - tt(initPos, c1.orig)) * pb.waitingCost
                    if earliest
                        cost = EPS*cost + max(0., initTime + tt(initPos, c.orig) - c.tmin)
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
            if custs[end].tInf + 2*custTime + tt(cLast.orig, cLast.dest) +
                tt(cLast.dest, c.orig) <= c.tmax
                cost = tc(cLast.dest, c.orig) + tc(c.orig, c.dest) -
                (tt(cLast.dest, c.orig) + tt(c.orig, c.dest)) * pb.waitingCost
                if earliest
                    cost = EPS*cost + max(0., custs[end].tInf + 2*custTime + tt(cLast.orig, cLast.dest) +
                        tt(cLast.dest, c.orig) - c.tmin)
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
                if custs[i].tInf + 2*custTime + tt(ci.orig, ci.dest) + tt(ci.dest, c.orig) <= c.tmax &&
                    max(custs[i].tInf + 2*custTime + tt(ci.orig, ci.dest) + tt(ci.dest, c.orig), c.tmin)+
                    tt(c.orig, c.dest) + 2*custTime + tt(c.dest, cip1.orig) <= custs[i+1].tSup
                    cost = tc(ci.dest, c.orig) + tc(c.orig, c.dest) +
                    tc(c.dest,cip1.orig) -  tc(ci.dest, cip1.orig) -
                    (tt(ci.dest, c.orig) + tt(c.orig, c.dest) +
                    tt(c.dest, cip1.orig) - tt(ci.dest, cip1.orig)) * pb.waitingCost
                    if earliest
                        cost = EPS*cost + max(0., custs[i].tInf + 2*custTime + tt(ci.orig, ci.dest) + tt(ci.dest, c.orig) - c.tmin)
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
            tmin = max(t.initTime + tt(t.initPos, c.orig), c.tmin)
            if length(custs) == 0
                push!( custs, CustomerTimeWindow(c.id, tmin, c.tmax))
            else
                tmax = min(c.tmax, custs[1].tSup - tt(c.orig,c.dest) -
                tt(c.dest,cDesc[custs[1].id].orig) - 2*custTime)
                insert!(custs, 1, CustomerTimeWindow(c.id, tmin, tmax))
            end
        else
            tmin = max(c.tmin, custs[i-1].tInf + 2*custTime +
            tt(cDesc[custs[i-1].id].orig, cDesc[custs[i-1].id].dest) +
            tt(cDesc[custs[i-1].id].dest, c.orig))
            if i > length(custs) #If inserted in last position
                push!(custs, CustomerTimeWindow(c.id, tmin, c.tmax))
            else
                tmax = min(c.tmax,custs[i].tSup - tt(c.orig, c.dest) -
                tt(c.dest, cDesc[custs[i].id].orig) - 2*custTime)
                insert!(custs, i, CustomerTimeWindow(c.id, tmin, tmax))
            end
        end

        #-------------------------
        # Update the freedom intervals of the other assigned customers
        #-------------------------
        for j = (i-1) :(-1):1
            custs[j].tSup = min(custs[j].tSup, custs[j+1].tSup - 2*custTime -
            tt(cDesc[custs[j].id].orig, cDesc[custs[j].id].dest) -
            tt(cDesc[custs[j].id].dest, cDesc[custs[j+1].id].orig))
        end
        for j = (i+1) :length(custs)
            custs[j].tInf = max(custs[j].tInf, custs[j-1].tInf + 2*custTime +
            tt(cDesc[custs[j-1].id].orig, cDesc[custs[j-1].id].dest) +
            tt(cDesc[custs[j-1].id].dest, cDesc[custs[j].id].orig))
        end
        delete!(sol.rejected,cId)
    end
    return solUpdates
end
