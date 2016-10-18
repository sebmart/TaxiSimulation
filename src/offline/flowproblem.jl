###################################################
## offline/flowproblem.jl
## Flow representation of an offline problem
###################################################


"""
    `FlowProblem`: represents an offline problem as a flow graph between customers
    - contains all information to solve (do not need Taxi-Problem)
    - Abstract the problem from the city-graph representation
"""
type FlowProblem
    "oriented graph of flow formulation"
    g::DiGraph
    "time of edges"
    time::Dict{Edge, Float64}
    "profit of edge"
    profit::Dict{Edge, Float64}
    "node time-windows (!!!! correspond to drop-off time! !!!!)"
    tw::Vector{Tuple{Float64, Float64}}
    "node ID to cust ID (<0 for taxi init)"
    node2cust::Vector{Int}
    "cust ID to node ID"
    cust2node::Dict{Int, Int}
    "nodes where taxis begin"
    taxiInit::IntSet
end

function Base.show(io::IO, l::FlowProblem)
    println("MIP flow network:")
    println(nv(l.g), " nodes - ", ne(l.g), " edges")
end

function FlowProblem(pb::TaxiProblem, custList::AbstractArray{Int64,1} = 1:length(pb.custs))
    # custList is the sub-list of customers we actually care about.

    tt = getPathTimes(pb.times)
    tc = getPathTimes(pb.costs)
    nTaxis = length(pb.taxis)
    currentCustomers = pb.custs[custList]

    g    = DiGraph(nTaxis + length(custList))
    time = Dict{Edge,Float64}()
    profit = Dict{Edge,Float64}()
    tw   = Array{Tuple{Float64,Float64}}(nv(g))
    node2cust = Array{Int}(nv(g))
    cust2node = Dict{Int, Int}()
    taxiInit = Set(1:length(pb.taxis))

    for t in pb.taxis
        node2cust[t.id] = -t.id
        cust2node[-t.id] = t.id
        tw[t.id] = (t.initTime, t.initTime)
    end
    for (i,c) in enumerate(currentCustomers)
        node2cust[i + nTaxis] = c.id
        cust2node[c.id] = i + nTaxis
        serveTime = tt[c.orig, c.dest] + 2*pb.customerTime
        tw[cust2node[c.id]] = (c.tmin + serveTime, c.tmax + serveTime)
    end

    for t in pb.taxis, c in currentCustomers
        if t.initTime + tt[t.initPos, c.orig] <= c.tmax
            e = Edge(cust2node[-t.id], cust2node[c.id])
            add_edge!(g, e)
            time[e] = tt[t.initPos, c.orig] + tt[c.orig, c.dest] + 2*pb.customerTime
            profit[e] = c.fare - tc[t.initPos, c.orig] - tc[c.orig, c.dest] + (time[e] - 2*pb.customerTime)*pb.waitingCost
        end
    end
    for c1 in currentCustomers, c2 in currentCustomers
        edgetime = tt[c1.dest, c2.orig] + tt[c2.orig, c2.dest] + 2*pb.customerTime
        if c1.id != c2.id && tw[cust2node[c1.id]][1] + edgetime <= tw[cust2node[c2.id]][2]
            e = Edge(cust2node[c1.id], cust2node[c2.id])
            add_edge!(g, e)
            time[e]   = edgetime
            profit[e] = c2.fare - tc[c1.dest, c2.orig] - tc[c2.orig, c2.dest] + (time[e] - 2*pb.customerTime)*pb.waitingCost
        end
    end
    return FlowProblem(g,time,profit,tw,node2cust,cust2node,taxiInit)
end

"""
    `emptyFlow`, returns an empty flow problem
    !!! if created from FlowProblem, share same memory !!!
"""
function emptyFlow(f::FlowProblem)
    g    = DiGraph(nv(f.g))
    time = f.time
    profit = f.profit
    tw   = f.tw
    node2cust = f.node2cust
    cust2node = f.cust2node
    taxiInit  = f.taxiInit
    return FlowProblem(g,time,profit,tw,node2cust,cust2node,taxiInit)
end

function emptyFlow(pb::TaxiProblem)
    tt = getPathTimes(pb.times)
    tc = getPathTimes(pb.costs)
    nTaxis = length(pb.taxis)

    g    = DiGraph(nTaxis + length(pb.custs))
    time = Dict{Edge,Float64}()
    profit = Dict{Edge,Float64}()
    tw   = Array{Tuple{Float64,Float64}}(nv(g))
    node2cust = Array{Int}(nv(g))
    cust2node = Dict{Int, Int}()
    taxiInit = Set(1:length(pb.taxis))

    for t in pb.taxis
        node2cust[t.id] = -t.id
        cust2node[-t.id] = t.id
        tw[t.id] = (t.initTime, t.initTime)
    end
    for c in pb.custs
        node2cust[c.id + nTaxis] = c.id
        cust2node[c.id] = c.id + nTaxis
        serveTime = tt[c.orig, c.dest] + 2*pb.customerTime
        tw[c.id + nTaxis] = (c.tmin + serveTime, c.tmax + serveTime)
    end
    return FlowProblem(g,time,profit,tw,node2cust,cust2node,taxiInit)
end


"""
    `FlowSolution`: compact representation of a flow solution (tied to a problem), just dictionary
"""
type FlowSolution
    edges::Set{Edge}
end

function copySolution(fs::FlowSolution)
    return FlowSolution(copy(fs.edges))
end

function solutionApproxProfit(fpb::FlowProblem, s::FlowSolution)
    return sum(fpb.profit[e] for e in s.edges)
end

function Base.show(io::IO, s::FlowSolution)
    println("Flow solution:")
    @printf("%d customers picked-up", length(s.edges))
end

function FlowSolution(l::FlowProblem, s::OfflineSolution)
    sol = Set{Edge}()
    for (k,ll) in enumerate(s.custs)
        orig = l.cust2node[-k]
        for tw in ll
            dest = l.cust2node[tw.id]
            e = Edge(orig, dest)
            if ! has_edge(l.g, e)
                error("Warmstart link not in flow graph!")
            end
            push!(sol, e)
            orig = dest
        end
    end
    FlowSolution(sol)
end

function OfflineSolution(pb::TaxiProblem, l::FlowProblem, s::FlowSolution)
    custs = [CustomerTimeWindow[] for k in eachindex(pb.taxis)]
    rejected = IntSet(eachindex(pb.custs))
    # reconstruct solution
    for k=eachindex(pb.taxis), e = out_edges(l.g, l.cust2node[-k])
        if e in  s.edges
            c = l.node2cust[dst(e)]
            push!(custs[k], CustomerTimeWindow(c, 0., 0.))
            delete!(rejected, c)
            anotherCust = true
            while anotherCust
                anotherCust = false
                for e2 in out_edges(l.g, dst(e))
                    if e2 in s.edges
                        c = l.node2cust[dst(e2)]
                        push!(custs[k], CustomerTimeWindow(c, 0., 0.))
                        delete!(rejected, c)
                        anotherCust = true; e = e2; break;
                    end
                end
            end
        end
    end
    updateTimeWindows!(pb, custs)
    return OfflineSolution(pb, custs, rejected, solutionProfit(pb, custs))
end

"""
    `LinkScores` contain link-scores associated with a FlowProblem network
    - stored in a sorted way (to easily get k-best or update), for each in-neighbor and out-neighbor
"""
type LinkScores
    nxt::Vector{Vector{Tuple{Int,Float64}}}
    prv::Vector{Vector{Tuple{Int,Float64}}}
end

function LinkScores(fpb::FlowProblem, score::Dict{Edge, Float64})
    nxt = Vector{Tuple{Int,Float64}}[sort!(Tuple{Int,Float64}[(dst(e),score[e]) for e in out_edges(fpb.g,v)], by=x->x[2], rev=true) for v in vertices(fpb.g)]
    prv = Vector{Tuple{Int,Float64}}[sort!(Tuple{Int,Float64}[(src(e),score[e]) for e in in_edges(fpb.g,v)],  by=x->x[2], rev=true) for v in vertices(fpb.g)]
    LinkScores(nxt, prv)
end

function Base.show(io::IO, l::LinkScores)
    println("Link Scores container")
end

"""
    `scoreHeuristic` assign scores to links.
    - scores is minus the shortest possible empty driving time for link
"""
function scoreHeuristic(pb::TaxiProblem, l::FlowProblem)
    tt = getPathTimes(pb.times)
    function score(e::Edge)
        c = pb.custs[l.node2cust[dst(e)]]
        return -(max(l.time[e], l.tw[dst(e)][1] - l.tw[src(e)][2]) - tt[c.orig, c.dest] - 2*pb.customerTime)
    end
    nxt = Vector{Tuple{Int,Float64}}[sort!(Tuple{Int,Float64}[(dst(e),score(e)) for e in out_edges(l.g,v)], by=x->x[2], rev=true) for v in vertices(l.g)]
    prv = Vector{Tuple{Int,Float64}}[sort!(Tuple{Int,Float64}[(src(e),score(e)) for e in in_edges(l.g,v)],  by=x->x[2], rev=true) for v in vertices(l.g)]
    LinkScores(nxt, prv)
end

"""
    `optimalScores` uses the LP flow formulation to guess how useful links of a FlowProblem
     are.
"""
function optimalScores(fpb::FlowProblem, n::Int)
    feasibleCount = Dict{Edge, Int}(e => 0 for e in edges(fpb.g))
    optimalCount = Dict{Edge, Int}(e => 0 for e in edges(fpb.g))

    for i = 1:n
        print("\r Iteration $i")
        randomPickupTimes = randPickupTimes(fpb)
        sol = lpFlow(fpb, randomPickupTimes, verbose=false)

        for e in feasibleEdges(fpb, randomPickupTimes)
            feasibleCount[e] += 1
        end

        for e in sol.edges
            optimalCount[e] += 1
        end
    end
    finalScores = Dict{Edge, Float64}()
    for e in edges(fpb.g)
        if feasibleCount[e] == 0
            finalScores[e] = 0.
        else
            finalScores[e] = optimalCount[e]/feasibleCount[e]
        end
    end
    return LinkScores(fpb, finalScores)
end

"""
    `kLinks` given a LinkScores and a FlowProblem object, construct a graph subset keeping the k best links
    !!! share memory with original object !!!
"""
function kLinks(l::FlowProblem, k::Int, score::LinkScores ; firstK::Int=0)
    pb = emptyFlow(l)

    # k-limit on out edges
    for v1 in vertices(l.g)
        for (v2,_) in score.nxt[v1][1:min(k,end)]
            e = Edge(v1,v2)
            add_edge!(pb.g, e)
        end
        for (v0,_) in score.prv[v1][1:min(k,end)]
            e = Edge(v0,v1)
            add_edge!(pb.g, e)
        end
    end

    if firstK > 0
        for v1 in l.taxiInit, (v2,_) in score.nxt[v1][1:min(firstK,end)]
            e = Edge(v1,v2)
            add_edge!(pb.g, e)
        end
    end
    return pb
end

function kLinks(pb::TaxiProblem, k::Int; firstK::Int=0)  # to create from scratch
    l = FlowProblem(pb)
    sc = scoreHeuristic(pb, l)
    kLinks(l,k,sc,firstK=firstK)
end


"""
    `fixedPickupTimes`: return set of pick-up times with fixed ratio.
"""
function fixedPickupTimes(l::FlowProblem, ratio=1.)
    return Float64[t[1] + ratio * (t[2] - t[1]) for t in l.tw]
end

"""
    `randPickupTimes`: return a set of uniformly random pick-up time for each customer
    to be used with flow, within a given (or the original) time window
"""
function randPickupTimes(l::FlowProblem, tw::Vector{Tuple{Float64, Float64}}=l.tw)
    return Float64[t[1] + rand() * (t[2] - t[1]) for t in tw]
end
randPickupTimes(l::FlowProblem, s::FlowSolution) = randPickupTimes(l,timeWindows(l,s))

"""
    `timeWindows`: get time windows of solution.
"""
function timeWindows(l::FlowProblem, s::FlowSolution)
    tw = copy(l.tw)
    for n = l.taxiInit
        orig = n
        path = Int[n]
        endPath = false
        while !endPath
            endPath=true
            for dest in out_neighbors(l.g, orig)
                if e in s.edges
                    tw[dest][1] = max(tw[dest][1], tw[orig][1] + l.time[Edge(orig, dest)])
                    push!(path, dest)
                    orig = dest
                    endPath = false
                    break
                end
            end
        end
        # go backward for sup
        for i in (length(path)-1):-1:1
            tw[path[i]][2] = min(tw[path[i]][2], tw[path[i+1]][2] - l.time[e])
        end
    end
    return tw
end

"""
    `addLinks!` add links of a flow solution to a flow problem
    - !!! time/profit information must be computed already !!!
"""
function addLinks!(pb::FlowProblem, s::FlowSolution)
    for e in s.edges
        add_edge!(pb.g, e)
    end
    pb
end
