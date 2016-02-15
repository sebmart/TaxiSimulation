
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
