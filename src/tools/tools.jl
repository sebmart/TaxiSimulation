#----------------------------------------
#-- Useful functions to deal with TaxiProblem and TaxiSolution objects
#----------------------------------------

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

"compute the cost of a solution just using customers"
function solutionCost(pb::TaxiProblem, t::Vector{Vector{AssignedCustomer}})
    cost = 0.0
    tt = traveltimes(pb)
    tc = travelcosts(pb)
    for (k,custs) in enumerate(t)
        pos = pb.taxis[k].initPos
        drivingTime = 0
        for c in custs
            c1 = pb.custs[c.id]
            cost += tc[pos,c1.orig] + tc[c1.orig,c1.dest] - c1.price
            drivingTime += tt[pos,c1.orig] + tt[c1.orig,c1.dest]
            pos = c1.dest
        end
        cost += (pb.nTime - drivingTime)*pb.waitingCost
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
        list = copy(sol.custs[k])
        if length(list) >= 1
            list[1].tInf = max(custs[list[1].id].tmin, pb.taxis[k].initTime + tt[pb.taxis[k].initPos, pb.custs[list[1].id].orig])
            list[end].tSup = custs[list[end].id].tmaxt
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


"expand the time windows of an interval solution"
function expandWindows!(pb::TaxiProblem, sol::IntervalSolution)
    custs = pb.custs
    tt = traveltimes(pb)
    custTime = pb.customerTime

    for k = 1:length(pb.taxis)
        list = sol.custs[k]
        if length(list) >= 1
            list[1].tInf = max(custs[list[1].id].tmin, pb.taxis[k].initTime + tt[pb.taxis[k].initPos, pb.custs[list[1].id].orig])
            list[end].tSup = custs[list[end].id].tmaxt
        end
        for i = 2:(length(list))
            list[i].tInf = max(pb.custs[list[i].id].tmin, list[i-1].tInf+
            tt[pb.custs[list[i-1].id].orig, pb.custs[list[i-1].id].dest]+
            tt[pb.custs[list[i-1].id].dest, pb.custs[list[i].id].orig]+2*custTime)
        end
        for i = (length(list) - 1):(-1):1
            list[i].tSup = min(pb.custs[list[i].id].tmaxt, list[i+1].tSup-
            tt[pb.custs[list[i].id].orig,pb.custs[list[i].id].dest]-
            tt[pb.custs[list[i].id].dest, pb.custs[list[i+1].id].orig]-2*custTime)
        end
        #quick check..
        for c in list
            if c.tInf > c.tSup + EPS
                error("Solution Infeasible for taxi $k : customer $(c.id) : tInf = $(c.tInf), tSup = $(c.tSup)")
            end
        end
    end
end

"""
Reconstruct all of a taxi's actions from its assigned customers
The rule is to wait _before_ going to the next customer if the taxi has to wait
"""
function TaxiActions(pb::TaxiProblem, id_taxi::Int, custs::Array{CustomerAssignment,1})
    tt = traveltimes(pb)
    path = Tuple{Float64,Road}[]

    initPos = pb.taxis[id_taxi].initPos
    for c in custs
        cust = pb.custs[c.id]

        #travels to customer origin
        p = getPath(pb, initPos, cust.orig, c.timeIn - tt[initPos, cust.orig])
        append!(path,p)

        #travels with customer
        p = getPath(pb, cust.orig, cust.dest, c.timeIn + pb.customerTime)
        append!(path,p)

        initPos = cust.dest
    end
    return TaxiActions(path,custs)
end

"""
Return a path with timings given a starting time, an origin and a destination
"""
function getPath(city::TaxiProblem, startNode::Int, endNode::Int, startTime::Float64)
    path = Tuple{Float64,Road}[]
    p, wait = getPath(city, startNode, endNode)
    t = startTime
    for i in 1:length(p)
        t += wait[i]
        push!(path, (t, p[i]))
        t += city.roadTime[src(p[i]), dst(p[i])]
    end
    return path
end

function saveTaxiPb(pb::TaxiProblem, name::AbstractString; compress=false)
    save("$(path)/.cache/$name.jld", "pb", pb, compress=compress)
end

function loadTaxiPb(name::AbstractString)
    pb = load("$(path)/.cache/$name.jld","pb")
    return pb
end

"Output the graph vizualization to pdf file (see GraphViz library)"
function drawNetwork(pb::TaxiProblem, name::AbstractString = "graph")
    stdin, proc = open(`neato -Tpdf -o $(path)/outputs/$(name).pdf`, "w")
    to_dot(pb.network,stdin)
    close(stdin)
end

"Write dotfile"
function dotFile(pb::TaxiProblem, name::AbstractString = "graph")
    open("$(path)/outputs/$name.dot","w") do f
        to_dot(pb.network, f)
    end
end

"Write the graph in dot format"
function to_dot(g::Network, stream::IO)
    write(stream, "digraph  citygraph {\n")
    for i in vertices(g), j in out_neighbors(g,i)
        write(stream, "$i -> $j\n")
    end
    write(stream, "}\n")
    return stream
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

"Given a solution, returns the time-windows"
function IntervalSolution(pb::TaxiProblem, sol::TaxiSolution)
    res = Array(Vector{AssignedCustomer}, length(pb.taxis))
    nt = trues(length(pb.custs))
    for k =1:length(sol.taxis)
        res[k] = [AssignedCustomer(c.id, pb.custs[c.id].tmin, pb.custs[c.id].tmaxt) for c in sol.taxis[k].custs]
    end
    tt = traveltimes(pb)

    for (k,cust) = enumerate(res)
        if length(cust) >= 1
            cust[1].tInf = max(cust[1].tInf, tt[pb.taxis[k].initPos, pb.custs[cust[1].id].orig])
            nt[cust[1].id] = false
        end
        for i = 2:(length(cust))
            cust[i].tInf = max(cust[i].tInf, cust[i-1].tInf+
            tt[pb.custs[cust[i-1].id].orig, pb.custs[cust[i-1].id].dest]+
            tt[pb.custs[cust[i-1].id].dest, pb.custs[cust[i].id].orig]+ 2*pb.customerTime)
            nt[cust[i].id] = false
        end
        for i = (length(cust) - 1):(-1):1
            cust[i].tSup = min(cust[i].tSup, cust[i+1].tSup-
            tt[pb.custs[cust[i].id].orig,pb.custs[cust[i].id].dest]-
            tt[pb.custs[cust[i].id].dest, pb.custs[cust[i+1].id].orig] - 2*pb.customerTime)
        end
        for c in cust
            if c.tSup < c.tInf
                error("Solution not feasible")
            end
        end
    end
    return IntervalSolution(res, nt, solutionCost(pb,res))
end

"""
Transform Interval solution into regular solution
rule: pick up customers as early as possible
"""
function TaxiSolution(pb::TaxiProblem, sol::IntervalSolution)

    nTaxis, nCusts = length(pb.taxis), length(pb.custs)
    actions = Array(TaxiActions, nTaxis)
    tt = traveltimes(pb)
    for k in 1:nTaxis
        custs = CustomerAssignment[]
        for c in sol.custs[k]
            push!( custs, CustomerAssignment(c.id,c.tInf,c.tInf + tt[pb.custs[c.id].orig, pb.custs[c.id].dest] + 2*pb.customerTime))
        end
        actions[k] = TaxiActions(pb,k,custs)
    end
    return TaxiSolution(actions, sol.notTaken, sol.cost)

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

"""
Takes a graph and returns positions of the nodes
"""
function graphPositions(g::Network)
    stdin, proc = open(`neato -Tplain -o $(path)/outputs/__graphPositions.txt`, "w")
    to_dot(g,stdin)
    close(stdin)
    fileExists = false
    while (!fileExists)
        sleep(1)
        fileExists = isfile("$(path)/outputs/__graphPositions.txt")
    end
    lines = readlines(open("$(path)/outputs/__graphPositions.txt"))
    rm("$(path)/outputs/__graphPositions.txt")
    coords = Array{Coordinates}(nv(g))
    indices = Int64[]
    index = 2
    while(lines[index][1:4] == "node")
        s = split(lines[index])
        id =  convert(Int64, float(s[2]))
        coords[id] = Coordinates(float(s[3]), float(s[4]))
        index += 1
    end
    return coords
end

"Update the call times"
function updateTcall(pb::TaxiProblem, time)
    pb2 = copy(pb)
    pb2.custs = Customer[Customer(c.id,c.orig,c.dest, max(0., c.tmin-time), c.tmin, c.tmaxt, c.price) for c in pb.custs]
    return pb2
end

"""
Updates the time windows of a taxi timeline
"""
function updateTimeWindows!(pb::TaxiProblem,s::IntervalSolution,k::Int)
    l = s.custs[k]
    tt = traveltimes(pb)

    if !isempty(l)
        l[1].tInf = max(l[1].tInf, tt[pb.taxis[k].initPos, pb.custs[l[1].id].orig])
    end
    for i = 2:(length(l))
        l[i].tInf = max(l[i].tInf, l[i-1].tInf+
        tt[pb.custs[l[i-1].id].orig, pb.custs[l[i-1].id].dest]+
        tt[pb.custs[l[i-1].id].dest, pb.custs[l[i].id].orig]+ 2*pb.customerTime)
    end
    for i = (length(l) - 1):(-1):1
        l[i].tSup = min(l[i].tSup, l[i+1].tSup-
        tt[pb.custs[l[i].id].orig, pb.custs[l[i].id].dest]-
        tt[pb.custs[l[i].id].dest, pb.custs[l[i+1].id].orig] - 2*pb.customerTime)
    end

end
