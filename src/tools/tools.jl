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






TaxiSolution() = TaxiSolution(TaxiActions[], trues(0), 0.0)
IntervalSolution() = IntervalSolution(Vector{CustomerAssignment}[], trues(0), 0.0)

copySolution(sol::IntervalSolution) = IntervalSolution( deepcopy(sol.custs), copy(sol.notTaken), sol.cost)

toInt(x::Float64) = round(Int,x)

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
