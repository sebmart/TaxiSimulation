###################################################
## offline/miplinks.jl
## link sets for mip
###################################################

"""
    `CustomerLink`, contain all customer link informations necessary to build mip
"""
type CustomerLinks
    "cust ID => previous customer (>0) or taxi (<0)"
    prv::Dict{Int, Set{Int}}
    "cust ID (>0) or taxi ID (<0) => next customer (>0)"
    nxt::Dict{Int, Set{Int}}
end

function Base.show(io::IO, l::CustomerLinks)
    tLink = 0; cLink = 0
    for (k,s) in l.nxt
        if k > 0
            cLink += length(s)
        else
            tLink += length(s)
        end
    end
    println("MIP links precomputation:")
    println("$tLink initial links and $cLink customer links")
end



"""
    `allLinks` : all feasible MIP links => provably optimal solution
    - can use custList to subset customers
"""
function allLinks(pb::TaxiProblem, custList::IntSet = IntSet(eachindex(pb.custs)))
    tt = getPathTimes(pb.times)
    prv = Dict{Int,Set{Int}}([(c, Set{Int}()) for c in custList])
    nxt = Dict{Int,Set{Int}}([(c, Set{Int}()) for c in custList])
    for k in eachindex(pb.taxis)
        nxt[-k] = Set{Int}()
    end

    # first customers
    for t in pb.taxis, c in custList
        if t.initTime + tt[t.initPos, pb.custs[c].orig] <= pb.custs[c].tmax
            push!(nxt[-t.id], c)
            push!(prv[c], -t.id)
        end
    end
    # customer pairs
    for c1 in custList, c2 in custList
        if c1 != c2 &&
            pb.custs[c1].tmin + tt[pb.custs[c1].orig, pb.custs[c1].dest] +
            tt[pb.custs[c1].dest, pb.custs[c2].orig] + 2*pb.customerTime <= pb.custs[c2].tmax
            push!(nxt[c1], c2)
            push!(prv[c2], c1)
        end
    end
    return CustomerLinks(prv, nxt)
end

"""
    `kLinks` : k links for each cust/taxi
    - can use custList to subset customers
"""
function kLinks(pb::TaxiProblem, maxLink::Int, custList::IntSet = IntSet(eachindex(pb.custs)))
    tt = getPathTimes(pb.times)
    prv = Dict{Int,Set{Int}}([(c, Set{Int}()) for c in custList])
    nxt = Dict{Int,Set{Int}}([(c, Set{Int}()) for c in custList])
    for k in eachindex(pb.taxis)
        nxt[-k] = Set{Int}()
    end

    revLink = Dict{Int, Vector{Int}}([(c,Int[]) for c in custList])
    revCost = Dict{Int, Vector{Float64}}([(c,Float64[]) for c in custList])

    # first customers
    for t in pb.taxis
        custs = Int[]; costs = Float64[]
        for c in custList
            if t.initTime + tt[t.initPos, pb.custs[c].orig] <= pb.custs[c].tmax
                push!(custs, c)
                cost = linkCost(pb, -t.id, c)
                push!(costs, cost)
                push!(revLink[c], -t.id)
                push!(revCost[c], cost)
            end
        end
        p = sortperm(costs)
        for i in p[1:min(end,maxLink)]
            c = custs[i]
            push!(nxt[-t.id], c)
            push!(prv[c], -t.id)
        end
    end

    # customer pairs
    for c1 in custList
        custs = Int[]; costs = Float64[]
        for c2 in custList
            if c1 != c2 && pb.custs[c1].tmin + tt[pb.custs[c1].orig, pb.custs[c1].dest] +
            tt[pb.custs[c1].dest, pb.custs[c2].orig] + 2*pb.customerTime <= pb.custs[c2].tmax
                push!(custs, c2)
                cost = linkCost(pb, c1, c2)
                push!(costs, cost)
                push!(revLink[c2], c1)
                push!(revCost[c2], cost)
            end
        end
        p = sortperm(costs)
        for i in p[1:min(end,maxLink)]
            c2 = custs[i]
            push!(nxt[c1], c2)
            push!(prv[c2], c1)
        end
    end

    for (c2, costs) in revCost
        p = sortperm(costs)
        for i in p[1:min(end,maxLink)]
            k = revLink[c2][i]
            push!(nxt[k], c2)
            push!(prv[c2], k)
        end
    end
    return CustomerLinks(prv, nxt)
end
"""
    `linkCost(TaxiProblem, i1,i2)`, return cost of link i1=>i2 (if i1<0, then i1 is a taxi)
    !!! customer must be  "feasible"
    - "best-case" cost : cost = shortest possible time between drop-off of one and pickup of the other
"""
function linkCost(pb::TaxiProblem, i1::Int, i2::Int)
    tt = getPathTimes(pb.times)
    c2 = pb.custs[i2]
    if i1 < 0 #taxi link
        t1 = pb.taxis[-i1]
        return max(tt[t1.initPos, c2.orig], c2.tmin - t1.initTime)
    else #customer link
        c1 = pb.custs[i1]
        return max(tt[c1.dest, c2.orig], c2.tmin - c1.tmax - tt[c1.orig, c1.dest] - 2*pb.customerTime)
    end
end
#
# """
#     `OnlineMIP` : creates MIP problem that works in online setting (can extend any MIP setting)
# """
# type OnlineMIP <: MIPSettings
#     pb::TaxiProblem
#     links::CustomerLinks
#     warmstart::Nullable{OfflineSolution}
#
#     "The underlying MIP setting"
#     mip::MIPSettings
#     "Customer in consideration"
#     realCusts::IntSet
#
#     function OnlineMIP(mip::MIPSettings = Optimal())
#         o = new()
#         o.mip = mip
#         o
#     end
#
# end
# function mipInit!(o::OnlineMIP, pb::TaxiProblem, warmstart::Nullable{OfflineSolution})
#     isnull(warmstart) && error("online setting has to have a warmstart")
#
#     pb2 = copy(pb)
#     o.realCusts = setdiff(IntSet(eachindex(pb.custs)), setdiff(getRejected(get(warmstart)), get(warmstart).rejected))
#     pb2.custs = [pb.custs[c] for c in o.realCusts]
#     mipInit!(o.mip, pb2, warmstart)
#
#     o.pb = pb
#     o.links = o.mip.links
#     o.links.cID = [c.id for c in pb2.custs]
#     o.links.cRev = Dict([(c.id,i) for (i,c) in enumerate(pb2.custs)])
#     o.warmstart = o.mip.warmstart
# end
#
# function mipEnd(o::OnlineMIP, custs::Vector{Vector{CustomerTimeWindow}}, rev::Float64)
#     rejected = intersect(getRejected(o.pb,custs),o.realCusts)
#     return OfflineSolution(o.pb, custs, rejected, rev)
# end
#
