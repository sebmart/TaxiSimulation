"Compute the cost of a solution (depreciated if turning penalties..)"
function solutionCost(pb::TaxiProblem, taxis::Array{TaxiActions, 1})
    cost = 0.
    for (k,t) in enumerate(taxis)
        totaltime = 0.
        for (i,(time,road)) in enumerate(t.path)
            cost += pb.roadCost[ src(road), dst(road)]
            totaltime += pb.roadTime[ src(road), dst(road)]
        end
        cost += pb.waitingCost * (pb.nTime - totaltime)
        for c in t.custs
            cost -= pb.custs[c.id].price
        end
    end
    return cost
end

"compute costs of one taxi"
function taxiCost(pb::TaxiProblem,custs::Vector{AssignedCustomer},k::Int)
    tt = traveltimes(pb)
    tc = travelcosts(pb)
    pos = pb.taxis[k].initPos
    drivingTime = 0
    cost = 0.
    for c in custs
        c1 = pb.custs[c.id]
        cost += tc[pos,c1.orig] + tc[c1.orig,c1.dest] - c1.price
        drivingTime += tt[pos,c1.orig] + tt[c1.orig,c1.dest]
        pos = c1.dest
    end
    cost += (pb.nTime - drivingTime)*pb.waitingCost
end

"compute the cost of a solution just using customers"
function solutionCost(pb::TaxiProblem, t::Vector{Vector{AssignedCustomer}})
    cost = 0.0

    for (k,custs) in enumerate(t)
        cost+= taxiCost(pb,custs,k)
    end
    return cost
end


"""
Test if a TaxiSolution is feasible
- The paths must be feasible paths (time to cross roads, no jumping..)
- The customers must correspond to the path, and be driven  directly as soon
 as picked-up, using the shortest path available
"""
function testSolution(pb::TaxiProblem, sol::TaxiSolution)
    custs = pb.custs
    nt = trues(length(pb.custs))
    tt = traveltimes(pb)
    custTime = pb.customerTime
    for (k,actions) in enumerate(sol.taxis)
        lastTime = pb.taxis[k].initTime - EPS
        lastRoad = Road(pb.taxis[k].initPos,pb.taxis[k].initPos)
        idc = isempty(actions.custs) ? 0 : 1
        for (t,r) in actions.path
            if 0<idc<=length(actions.custs)
                if lastTime < actions.custs[idc].timeIn <= t
                    @test_approx_eq_eps (t - custTime) actions.custs[idc].timeIn EPS
                    @test src(r) == custs[actions.custs[idc].id].orig
                elseif lastTime < actions.custs[idc].timeOut <= t +EPS
                    @test_approx_eq_eps (lastTime + custTime + pb.roadTime[src(lastRoad),dst(lastRoad)]) actions.custs[idc].timeOut EPS
                    @test src(r) == custs[actions.custs[idc].id].dest
                    @test_approx_eq_eps (actions.custs[idc].timeOut - actions.custs[idc].timeIn) (2*custTime + tt[custs[actions.custs[idc].id].orig,custs[actions.custs[idc].id].dest]) EPS
                    nt[actions.custs[idc].id] = false

                    idc+=1
                end
            end
            @test dst(lastRoad) == src(r)
            @test (lastTime + pb.roadTime[src(lastRoad),dst(lastRoad)]) <= (t + EPS)
            lastTime, lastRoad = t, r
        end
        if idc>0
            if idc < length(actions.custs)
                error("Customer list not good for taxi $k")
            elseif idc == length(actions.custs)
                @test_approx_eq_eps (lastTime + custTime + pb.roadTime[src(lastRoad),dst(lastRoad)]) actions.custs[idc].timeOut EPS
                @test dst(lastRoad) == custs[actions.custs[idc].id].dest
                @test_approx_eq_eps (actions.custs[idc].timeOut - actions.custs[idc].timeIn) (2*custTime + tt[custs[actions.custs[idc].id].orig,custs[actions.custs[idc].id].dest]) EPS
                nt[actions.custs[idc].id] = false
            end
        end
    end

    if sol.notTaken != nt
        error("NotTaken is not correct")
    end
    @test_approx_eq_eps sol.cost solutionCost(pb,sol.taxis) EPS
end

"test if interval solution is indeed feasible"
function testSolution(pb::TaxiProblem, sol::IntervalSolution)
    custs = pb.custs
    nt = trues(length(pb.custs))
    tt = traveltimes(pb)
    custTime = pb.customerTime

    for k = 1:length(pb.taxis)
        ref = sol.custs[k]
        list = deepcopy(ref)
        if length(list) >= 1
            list[1].tInf = max(custs[list[1].id].tmin, pb.taxis[k].initTime + tt[pb.taxis[k].initPos, pb.custs[list[1].id].orig])
            @test_approx_eq_eps list[1].tInf ref[1].tInf EPS
            list[end].tSup = custs[list[end].id].tmaxt
            @test_approx_eq_eps list[end].tSup ref[end].tSup EPS
            if nt[list[1].id]
                nt[list[1].id] = false
            else
                error("Customer $(list[1].id) picked-up twice")
            end
        end
        for i = 2:(length(list))
            list[i].tInf = max(pb.custs[list[i].id].tmin, list[i-1].tInf+
            tt[pb.custs[list[i-1].id].orig, pb.custs[list[i-1].id].dest]+
            tt[pb.custs[list[i-1].id].dest, pb.custs[list[i].id].orig] + 2*custTime)
            @test_approx_eq_eps list[i].tInf ref[i].tInf EPS
            if nt[list[i].id]
                nt[list[i].id] = false
            else
                error("Customer $(list[i].id) picked-up twice")
            end
        end
        for i = (length(list) - 1):(-1):1
            list[i].tSup = min(pb.custs[list[i].id].tmaxt, list[i+1].tSup-
            tt[pb.custs[list[i].id].orig,pb.custs[list[i].id].dest]-
            tt[pb.custs[list[i].id].dest, pb.custs[list[i+1].id].orig]- 2*custTime)
            @test_approx_eq_eps list[i].tSup ref[i].tSup EPS
        end
        for c in list
            if c.tInf > c.tSup + EPS
                error("Solution Infeasible for taxi $k : customer $(c.id) : tInf = $(c.tInf), tSup = $(c.tSup)")
            end
        end
    end
    if sol.notTaken != nt
        errors = (1:length(pb.custs))[sol.notTaken $ nt]
        error("NotTaken is not correct for customers: $errors")
    end
    # cost = solutionCost(pb,sol.custs)
    # if abs(sol.cost - cost) > 1e-5
    #     error("Cost is not correct (1e-5 precision)")
    # end
end

"returns a random permutation"
function randomOrder(n::Int)
    order = collect(1:n)
    for i = n:-1:2
        j = rand(1:i)
        order[i], order[j] = order[j], order[i]
    end
    return order
end
randomOrder(pb::TaxiProblem) = randomOrder(length(pb.custs))

"Return customers that can be taken before other customers"
function customersCompatibility(pb::TaxiProblem)
    cust = pb.custs
    tt = traveltimes(pb)
    nCusts = length(cust)
    pCusts = Array( Array{Int,1}, nCusts)
    nextCusts = Array( Array{Tuple{Int,Int},1},nCusts)
    for i=1:nCusts
        nextCusts[i] = Tuple{Int,Int}[]
    end

    for (i,c1) in enumerate(cust)
        pCusts[i]= filter(c2->c2 != i && cust[c2].tmin + 2*pb.customerTime +
        tt[cust[c2].orig, cust[c2].dest] + tt[cust[c2].dest, c1.orig] <= c1.tmaxt,
        collect(1:nCusts))
        for (id,j) in enumerate(pCusts[i])
            push!(nextCusts[j], (i,id))
        end
    end
    return pCusts, nextCusts
end



TaxiSolution() = TaxiSolution(TaxiActions[], trues(0), 0.0)
IntervalSolution() = IntervalSolution(Vector{CustomerAssignment}[], trues(0), 0.0)
IntervalSolution(pb::TaxiProblem) =
IntervalSolution([CustomerAssignment[] for k in 1:length(pb.taxis)],
trues(length(pb.custs)), pb.nTime * length(pb.taxis) * pb.waitingCost)

copySolution(sol::IntervalSolution) = IntervalSolution( deepcopy(sol.custs), copy(sol.notTaken), sol.cost)

toInt(x::Float64) = round(Int,x)

traveltimes(pb::TaxiProblem) = traveltimes(pb.paths)
travelcosts(pb::TaxiProblem) = travelcosts(pb.paths)
getPath(city::TaxiProblem, startNode::Int, endNode::Int) = getPath(city, city.paths, startNode, endNode)

"""
Returns a taxi problem with all tcall set to zero
"""
function pureOffline(pb::TaxiProblem)
    pb2 = copy(pb)
    pb2.custs = Customer[Customer(c.id,c.orig,c.dest, 0., c.tmin, c.tmaxt, c.price) for c in pb.custs]
    return pb2
end

"""
Returns a taxi problem with all tcall set to tmin
"""
function pureOnline(pb::TaxiProblem)
    pb2 = copy(pb)
    pb2.custs = Customer[Customer(c.id,c.orig,c.dest, c.tmin, c.tmin, c.tmaxt, c.price) for c in pb.custs]
    return pb2
end

"""
Returns a taxi problem with all tmaxt set to nTime
"""
function noTmaxt(pb::TaxiProblem)
    pb2 = copy(pb)
    pb2.custs = Customer[Customer(c.id,c.orig,c.dest, c.tcall, c.tmin, pb.nTime, c.price) for c in pb.custs]
    return pb2
end

"Update the call times"
function updateTcall(pb::TaxiProblem, time::Float64; random::Bool = false)
    pb2 = copy(pb)
    if random
        pb2.custs = Customer[Customer(c.id,c.orig,c.dest, max(0., c.tmin-rand()*time), c.tmin, c.tmaxt, c.price) for c in pb.custs]
    else
        pb2.custs = Customer[Customer(c.id,c.orig,c.dest, max(0., c.tmin-time), c.tmin, c.tmaxt, c.price) for c in pb.custs]
    end
    return pb2
end



"""
add an update to a Partial solution
- Only store if not stored before
"""
function addPartialSolution!(sol::PartialSolution, k::Int, u::Vector{AssignedCustomer})
    if !haskey(sol,k)
        sol[k] = deepcopy(u)
    end
end
function addPartialSolution!(sol::PartialSolution, sol2::PartialSolution)
    for (k,u) in sol2
        addPartialSolution!(sol,k,u)
    end
end



"""
Updates in place an IntervalSolution, given a list of changes (do not update cost!)
"""
function updateSolution!(sol::IntervalSolution, updateSol::PartialSolution)
    for (k,u) in updateSol
        for c in sol.custs[k]
            sol.notTaken[c.id] = !sol.notTaken[c.id]
        end
        for c in u
            sol.notTaken[c.id] = !sol.notTaken[c.id]
        end
        sol.custs[k] = u
    end
end

"""
Updates in place an IntervalSolution, given a list of changes (do not update cost!)
last updates are supposed to be the last ones
"""
function updateCost(pb, sol::IntervalSolution, updateSol::PartialSolution)
    cost = 0.
    for (k,u) in updateSol
        cost += taxiCost(pb,u,k)
        cost -= taxiCost(pb,sol.custs[k],k)
    end
    return cost
end
