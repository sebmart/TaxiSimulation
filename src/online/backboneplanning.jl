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
    k::Int
    "contains the current full backbone, reduced to k incoming and outcoming links"
    fpb::FlowProblem
    "the current Flow solution of fpb"
    s::FlowSolution
    "Stores the link scores, !!! used differently, as heaps"
    scores::LinkScores

end

function onlineInitialize!(bp::BackbonePlanning, pb::TaxiProblem)

end

function onlineUpdate!(bp::BackbonePlanning, endTime::Float64, newCustomers::Vector{Customer})
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
            if op.pb.custs[c].tmax < endTime
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
    removeNode!(bp, oldTaxiNode)

    # the old customer node has to become the new taxi node
    newTaxiNode = fpb.cust2node[-k]
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
