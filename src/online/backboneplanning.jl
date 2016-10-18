###################################################
## online/backboneplanning.jl
## specific online algorithm that maintain an offline solution in the form of a backbone
## and use local backbone search to optimize the current solution
###################################################


"""
    `BackbonePlanning` : OnlineAlgorithm subtype that maintains a FlowProblem and an offline
    FlowSolution. Use local backbone search to solve the problem at each iteration.
"""
type BackbonePlanning <: OnlineAlgorithm
    "The taxi problem, partially updated"
    pb::TaxiProblem
    "parameter that control the density of the graph representation"
    edgesPerNode::Int
    "contains the current full backbone, reduced to k incoming and outcoming links"
    fpb::FlowProblem
    "the current Flow solution of fpb"
    s::FlowSolution
    "Stores the link scores, !!! used differently, as heaps"
    scores::LinkScores
    "time for precomputation"
    precompTime::Float64
    "Time for each step"
    iterTime::Float64

    function BackbonePlanning(;edgesPerNode::Int=10, precompTime::Real=100, iterTime::Real=30, maxEdges::Int=1500)
        bp = new()
        if edgesPerNode < 2
            error("Not enough edges per node")
        end
        bp.edgesPerNode = edgesPerNode
        bp.precompTime = precompTime
        bp.iterTime = iterTime
        bp.maxEdges = maxEdges
        bp.iterTime = iterTime
        return bp
    end
end

function onlineInitialize!(bp::BackbonePlanning, pb::TaxiProblem)
    pb.taxis = copy(pb.taxis)
    custs = pb.custs
    pb.custs = []
    fpb = emptyFlow(pb)
    prevScores = Float64[(0,-Inf) for i = 1:pb.edgesPerNode]
    nextScores = Float64[(0,-Inf) for i = 1:pb.edgesPerNode]
    scores = LinkScores(nextScores, prevScores)

    bp.pb = pb; bp.scores = scores; bp.fpb = fpb

    # construct the flow-graph customer by customer.
    if !isempty(custs)
        pb.custs = Array{Customer}(maximum(c.id for c in custs))
        for c in custs
            pb.custs[c.id] = c
            addCustomer!(bp, c.id)
        end
    end

    # first solution
    bp.s = backboneSearch(fpb, emptyFlowSolution(), maxEdges=maxEdges, localityRatio=1, maxTime=precompTime)
end

function onlineUpdate!(bp::BackbonePlanning, endTime::Float64, newCustomers::Vector{Customer})
    #Add new customers
    for c in newCustomers
        if length(bp.pb.custs) < c.id
            resize!(bp.pb.custs, c.id)
        end
        bp.pb.custs[c.id] = c
        addCustomer!(bp, c.id)
    end
    bp.s = backboneSearch(fpb, bp.s, maxEdges=maxEdges, localityRatio=1, maxTime=precompTime)


    return computeActions!(bp::BackbonePlanning, endTime::Float64)
end

"""
    `computeActions!` return set of actions given current offline solution.
    Updates the solution and FlowProblem
"""
function computeActions!(bp::BackbonePlanning, endTime::Float64)
    offlinesol = OfflineSolution(bp.pb, bp.fpb, bp.s)
    tt = getPathTimes(bp.pb.times)
    actions = emptyActions(bp.pb)

    for (k,custs) in enumerate(offlinesol.custs)
        while !isempty(custs)
            c = custs[1]
            if c.tInf - tt[bppb.taxis[k].initPos, bp.pb.custs[c.id].orig] <= endTime
                path, times = getPathWithTimes(bp.pb.times, bp.pb.taxis[k].initPos, bp.pb.custs[c.id].orig,
                                    startTime=c.tInf - tt[bp.pb.taxis[k].initPos, bp.pb.custs[c.id].orig])
                append!(actions[k].path, path[2:end])
                append!(actions[k].times, times)
                path, times = getPathWithTimes(bp.pb.times, bp.pb.custs[c.id].orig, bp.pb.custs[c.id].dest,
                                    startTime=c.tInf + bp.pb.customerTime)
                append!(actions[k].path, path[2:end])
                append!(actions[k].times, times)

                newTime = c.tInf + 2*bp.pb.customerTime + tt[bp.pb.custs[c.id].orig, bp.pb.custs[c.id].dest]
                push!(actions[k].custs, CustomerAssignment(c.id, c.tInf, newTime))
                bp.pb.taxis[k] = Taxi(bp.pb.taxis[k].id, bp.pb.custs[c.id].dest, newTime)
                shift!(custs)
                moveTaxi!(bp, k, c.id)
            else
                break
            end
        end
        if bp.pb.taxis[k].initTime < endTime
            bp.pb.taxis[k] = Taxi(bp.pb.taxis[k].id, bp.pb.taxis[k].initPos, endTime)
            updateTaxiTime!(bp, bp.pb.taxis[k].id)
        end

        # remove rejected customers of the past
        for c in keys(bp.fpb.cust2node)
            if bp.pb.custs[c].tmax < endTime
                customerNode = bp.fpb.cust2node[c]
                removeNode!(bp, customerNode)
            end
        end
    end
    return actions
end

"""
    `moveTaxi!` : updates the flow problem (and the flow solution) so that a taxi picks up a
    customer.
"""
function moveTaxi!(bp::BackbonePlanning, k::Int, c::Int)
    fpb = bp.fpb
    #delete the old taxi node
    oldTaxiNode = fpb.cust2node[-k]
    newTaxiNode = fpb.cust2node[c]

    removeNode!(bp, oldTaxiNode)

    # the old customer node has to become the new taxi node

    fpb.cust2node[-k] = newTaxiNode
    fpb.node2cust[newTaxiNode] = -k

    delete!(fpb.taxiInit, oldTaxiNode)
    push!(fpb.taxiInit, newTaxiNode)

    updateTaxiTime!(bp, k)
end

"""
    `updateTaxiTime!` : updates FlowProblem with taxi init times from TaxiProblem
"""
function updateTaxiTime!(bp::BackbonePlanning, k::Int)
    taxiNode = bp.fpb.cust2node[-k]
    initTime = pb.pb.taxis[k].initTime
    bp.fpb.tw[taxiNode] = (initTime, initTime)
end

"""
    `removeNode!` removes a node from the flow graph, updates all the FlowProblem and
    FlowSolution attributes to the new status
"""
function removeNode!(bp::BackbonePlanning, n::Int)
    fpb = bp.fpb
    oldNode = nv(fpb.g)
    newNode = n

    # remove edges around node
    for e in in_edges(fpb.g, n)
        delete!(bp.s.edges, e)
        delete!(fpb.time, e)
        delete!(fpb.profit, e)
    end
    for e in out_edges(fpb.g, n)
        delete!(bp.s.edges, e)
        delete!(fpb.time, e)
        delete!(fpb.profit, e)
    end

    #remove node
    delete!(fpb.cust2node, fpb.node2cust[n])
    if oldNode != newNode
        fpb.tw[newNode] = pop!(fpb.tw)
        fpb.node2cust[newNode] = pop!(fpb.node2cust)
        fpb.cust2node[fpb.node2cust[newNode]] = newNode
    else
        pop!(fpb.tw)
        pop!(fpb.node2cust)
    end

    # update node with change of id
    if oldNode != newNode
        for e in in_edges(fpb.g, oldNode)
            newEdge = Edge(src(e), newNode)
            fpb.time[newEdge] = pop!(fpb.time, e)
            fpb.profit[newEdge] = pop!(fpb.time, e)
            if haskey(bp.s.edges, e)
                bp.s.edges[newEdge] = pop!(bp.s.edges, e)
            end
        end
        for e in out_edges(fpb.g, oldNode)
            newEdge = Edge(newNode, dst(e))
            fpb.time[newEdge] = pop!(fpb.time, e)
            fpb.profit[newEdge] = pop!(fpb.time, e)
            if haskey(bp.s.edges, e)
                bp.s.edges[newEdge] = pop!(bp.s.edges, e)
            end
        end
    end

    # finally updates the graph
    rem_vertex!(fpb.g, n)
end

"""
    `addCustomer!` adds a customer to the flow graph, takes care of the score update tools
"""
function addCustomer!(bp::BackbonePlanning, newCust::Int)
    c = bp.pb.custs[newCust]

    # First, add node
    add_vertex!(bp.fpb.g)
    newNode = nv(bp.fpb.g)
    serveTime = tt[c.orig, c.dest] + 2*bp.pb.customerTime
    push!(bp.fpb.tw, (c.tmin + serveTime, c.tmax + serveTime))
    push!(bp.fpb.node2cust, newCust)
    bp.fpb.cust2node[newCust] = newNode

    # then, add edges:
    for n in 1:nv(bp.fpb.g)-1
        tryAddEdge!(bp, Edge(n, newNode))
        tryAddEdge!(bp, Edge(newNode, n))
    end
end

"""
    `tryAddEdge!` try to add an edge in the sparse flow graph
"""
function tryAddEdge!(bp::BackbonePlanning, newEdge::Edge)
    # Eliminate trivial infeasibilities
    (bp.fpb.tw[src(newEdge)][1] > bp.tw[dst(newEdge)][2]) && return
    idO = bp.fpb.node2cust[src(newEdge)]
    idD = bp.fpb.node2cust[dst(newEdge)]
    (idD < 0) && return

    # now check feasibility
    c = bp.pb.custs[idD]
    tt = getPathTimes(bp.pb.times)
    if idO < 0
        edgeTime = tt[bp.pb.taxis[-idO].initPos, c.orig] + tt[c.orig, c.dest] + 2*pb.customerTime
    else
        edgeTime = tt[bp.pb.custs[idO].dest, c.orig] + tt[c.orig, c.dest] + 2*pb.customerTime
    end
    (bp.fpb.tw[src(newEdge)][1] + edgeTime > bp.fpb.tw[dst(newEdge)][2]) && return

    # we have a feasible edge, compute score
    score = -(max(edgeTime, bp.fpb.tw[dst(newEdge)][1] - bp.fpb.tw[src(newEdge)][2]) - tt[c.orig, c.dest] - 2*pb.customerTime)

    # Check if we should add edge. Slightly complicated, need to deal with not deleting
    # current sol.
    maxScoreOrder(t::Tuple{Int, Float64}) = -t[2]
    addEdge = false
    nxt = bp.scores.nxt[src(newEdge)]
    prv = bp.scores.prv[dst(newEdge)]
    if (score > nxt[1][2])
        if Edge(src(newEdge), nxt[1][1]) in bp.s.edges
            minScore = Collections.heappop!(nxt, maxScoreOrder)
            if (score > nxt[1][2])
                addEdge = true
                dstEdge = Collections.heappop!(nxt, maxScoreOrder)[1]
                if !(src(newEdge) in (t[1] for t in bp.scores.prv[dstEdge]))
                    removeEdge!(fpb, Edge(src(newEdge), dstEdge))
                end
                Collections.heappush!(nxt, (dst(newEdge), score), maxScoreOrder)
            end
            Collections.heappush!(nxt, minScore, maxScoreOrder)
        else
            addEdge = true
            dstEdge = Collections.heappop!(nxt, maxScoreOrder)[1]
            if !(src(newEdge) in (t[1] for t in bp.scores.prv[dstEdge]))
                removeEdge!(fpb, Edge(src(newEdge), dstEdge))
            end
            Collections.heappush!(nxt, (dst(newEdge), score), maxScoreOrder)
        end
    end
    if (score > prv[1][2])
        if Edge(prv[1][1], dst(newEdge)) in bp.s.edges
            minScore = Collections.heappop!(prv, maxScoreOrder)
            if (score > prv[1][2])
                addEdge = true
                srcEdge = Collections.heappop!(prv, maxScoreOrder)[1]
                if !(dst(newEdge) in (t[1] for t in bp.scores.nxt[srcEdge]))
                    removeEdge!(fpb, Edge(srcEdge, dst(newEdge)))
                end
                Collections.heappush!(prv, (src(newEdge), score), maxScoreOrder)
            end
            Collections.heappush!(nxt, minScore, maxScoreOrder)
        else
            addEdge = true
            srcEdge = Collections.heappop!(prv, maxScoreOrder)[1]
            if !(dst(newEdge) in (t[1] for t in bp.scores.nxt[srcEdge]))
                removeEdge!(fpb, Edge(srcEdge, dst(newEdge)))
            end
            Collections.heappush!(prv, (src(newEdge), score), maxScoreOrder)
        end
    end
    !(addEdge) && return

    # finally, add new edge
    add_edge!(bp.fpb.g, newEdge)
    time[newEdge] = edgeTime
    tc = getPathTimes(bp.pb.costs)
    if idO < 0
        profit[newEdge] = c.fare - tc[bp.pb.taxis[-idO].initPos, c.orig] - tc[c.orig, c.dest] + (edgeTime - 2*bp.pb.customerTime)*bp.pb.waitingCost
    else
        profit[newEdge] = c.fare - tc[bp.pb.custs[idO].dest, c.orig] - tc[c.orig, c.dest] + (edgeTime - 2*bp.pb.customerTime)*bp.pb.waitingCost
    end
end
