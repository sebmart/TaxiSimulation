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
#
#     function OnlineMip(mip::MIPSettings)
#         isnull(mip.warmstart) && error("online setting has to have a warmstart")
#
#         o = new()
#         o.pb = mip.pb
#         o.links = mip.links
#         o.warmstart = mip.warmstart
#
#     end
#
# end
#
# """
#     `customersOnline`, subsets customers that can be taken before other customers
# """
# function customersOnline(pb::TaxiProblem, toKeep::IntSet, links::Function)
#     pb2 = copy(pb)
#     pb2.custs = pb.custs[collect(toKeep)]
#     cID =  [c.id for c in pb2.custs]
#     cRev = Dict{Int,Int}([(c.id, i) for (i,c) in enumerate(pb2.custs)])
#     return (cID, cRev, links(pb2)[3:end]...)
# end
#
#
# """
#     `limitedLinks`, subsets customers that can be taken before other customers
#     - allow k customers before each customer, and k after each customer
#     - sort them by score distance + possibility (need to also sort by availability)
# """
# function limitedLinks(pb::TaxiProblem, k::Int)
#     tt = getPathTimes(pb.times)
#     # all customers are considered
#     cID = collect(eachindex(pb.custs))
#     cRev = Dict([(i,i) for i in eachindex(pb.custs)])
#     starts = Tuple{Int,Int}[]
#     sRev   = Dict{Tuple{Int,Int},Int}()
#     sRev1  = Vector{Int}[Int[] for i=eachindex(pb.taxis)]
#     sRev2  = Vector{Int}[Int[] for i=eachindex(pb.custs)]
#     pairs  = Tuple{Int,Int}[]
#     pRev   = Dict{Tuple{Int,Int},Int}()
#     pRev1  = Vector{Int}[Int[] for i=eachindex(pb.custs)]
#     pRev2  = Vector{Int}[Int[] for i=eachindex(pb.custs)]
#
#     # first customers
#     for t in pb.taxis, (i,c) in enumerate(pb.custs)
#         if t.initTime + tt[t.initPos, c.orig] <= c.tmax
#             push!(starts, (t.id, i))
#             sRev[t.id,i] = length(starts)
#             push!(sRev1[t.id], length(starts))
#             push!(sRev2[i], length(starts))
#         end
#     end
#     # customer pairs
#     for (i1,c1) in enumerate(pb.custs), (i2,c2) in enumerate(pb.custs)
#         if i1 != i2 &&
#         c1.tmin + tt[c1.orig, c1.dest] + tt[c1.dest, c2.orig] + 2*pb.customerTime <= c2.tmax
#             push!(pairs, (i1, i2))
#             pRev[i1, i2] = length(pairs)
#             push!(pRev1[i1], length(pairs))
#             push!(pRev2[i2], length(pairs))
#         end
#     end
#     return cID, cRev, pairs, pRev, pRev1, pRev2, starts, sRev, sRev1, sRev2
# end
