###################################################
## offline/mipsettings.jl
## different pre and post computations on the mip
###################################################
"""
    `Optimal` : creates MIP problem that returns provably optimal solution
"""
type Optimal <: MIPSettings
    pb::TaxiProblem
    links::CustomerLinks
    warmstart::Nullable{OfflineSolution}

    function Optimal()
        return new()
    end
end

function mipInit!(o::Optimal, pb::TaxiProblem, warmstart::Nullable{OfflineSolution})
    tt = getPathTimes(pb.times)
    # all customers are considered
    cID = collect(eachindex(pb.custs))
    cRev = Dict([(i,i) for i in eachindex(pb.custs)])
    starts = Tuple{Int,Int}[]
    sRev   = Dict{Tuple{Int,Int},Int}()
    sRev1  = Vector{Int}[Int[] for i=eachindex(pb.taxis)]
    sRev2  = Vector{Int}[Int[] for i=eachindex(pb.custs)]
    pairs  = Tuple{Int,Int}[]
    pRev   = Dict{Tuple{Int,Int},Int}()
    pRev1  = Vector{Int}[Int[] for i=eachindex(pb.custs)]
    pRev2  = Vector{Int}[Int[] for i=eachindex(pb.custs)]

    # first customers
    for t in pb.taxis, (i,c) in enumerate(pb.custs)
        if t.initTime + tt[t.initPos, c.orig] <= c.tmax
            push!(starts, (t.id, i))
            sRev[t.id,i] = length(starts)
            push!(sRev1[t.id], length(starts))
            push!(sRev2[i], length(starts))
        end
    end
    # customer pairs
    for (i1,c1) in enumerate(pb.custs), (i2,c2) in enumerate(pb.custs)
        if i1 != i2 &&
        c1.tmin + tt[c1.orig, c1.dest] + tt[c1.dest, c2.orig] + 2*pb.customerTime <= c2.tmax
            push!(pairs, (i1, i2))
            pRev[i1, i2] = length(pairs)
            push!(pRev1[i1], length(pairs))
            push!(pRev2[i2], length(pairs))
        end
    end
    links = CustomerLinks(cID, cRev, pairs, pRev, pRev1, pRev2, starts, sRev, sRev1, sRev2)
    o.pb = pb; o.links = links; o.warmstart=warmstart
    o
end


"""
    `OnlineMIP` : creates MIP problem that works in online setting (can extend any MIP setting)
"""
type OnlineMIP <: MIPSettings
    pb::TaxiProblem
    links::CustomerLinks
    warmstart::Nullable{OfflineSolution}

    "The underlying MIP setting"
    mip::MIPSettings
    "Customer in consideration"
    realCusts::IntSet

    function OnlineMIP(mip::MIPSettings = Optimal())
        o = new()
        o.mip = mip
        o
    end

end
function mipInit!(o::OnlineMIP, pb::TaxiProblem, warmstart::Nullable{OfflineSolution})
    isnull(warmstart) && error("online setting has to have a warmstart")

    pb2 = copy(pb)
    o.realCusts = setdiff(IntSet(eachindex(pb.custs)), setdiff(getRejected(get(warmstart)), get(warmstart).rejected))
    pb2.custs = [pb.custs[c] for c in o.realCusts]
    mipInit!(o.mip, pb2, warmstart)

    o.pb = pb
    o.links = o.mip.links
    o.links.cID = [c.id for c in pb2.custs]
    o.links.cRev = Dict([(c.id,i) for (i,c) in enumerate(pb2.custs)])
    o.warmstart = o.mip.warmstart
end

function mipEnd(o::OnlineMIP, custs::Vector{Vector{CustomerTimeWindow}}, rev::Float64)
    rejected = intersect(getRejected(o.pb,custs),o.realCusts)
    return OfflineSolution(o.pb, custs, rejected, rev)
end
