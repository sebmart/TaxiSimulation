###################################################
## offline/miplinks.jl
## link sets for mip
###################################################

"""
    `CustomerLink`, contain all customer link informations necessary to build mip
    - all taxis must be in nxt
    - all customers that are in prv must be in nxt and vice-versa
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
    println("Link/customer equal to $(cLink/length(keys(l.prv)))")
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
function kLinks(pb::TaxiProblem, maxLink::Int, custList::IntSet = IntSet(eachindex(pb.custs));
                initOnly::Bool = false)
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

    if !initOnly
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
        println("blop")
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

"""
    `linkUnion!`
    - union of two valid link lists
    - or merge the second one that is a solution into the first one
"""
function linkUnion!(l1::CustomerLinks, l2::CustomerLinks)
    prv = deepcopy(l1.prv)
    nxt = deepcopy(l1.nxt)
    for (c, s) in l2.nxt
        if haskey(l1.nxt,c)
            union!(l1.nxt[c], s)
            if c > 0
                union!(l1.prv[c], l2.prv[c])
            end
        else
            l1.nxt[c] = deepcopy(s)
            l1.prv[c] = deepcopy(l2.prv[c])
        end
    end
    return l1
end

linkUnion(l1::CustomerLinks, l2::CustomerLinks) =
linkUnion!(CustomerLinks(deepcopy(l1.prv),deepcopy(l1.nxt)), l2)

"""
    `usedLinks`, extract used links from offline solution
"""
function usedLinks(s::OfflineSolution)
    prv = Dict{Int,Set{Int}}()
    nxt = Dict{Int,Set{Int}}()
    for (k,l) in enumerate(s.custs)
        if isempty(l)
            nxt[-k] = Set{Int}()
        else
            nxt[-k] = Set{Int}(l[1].id)
            prv[l[1].id] = Set{Int}(-k)
            for i in 1:length(l)-1
                nxt[l[i].id] = Set{Int}(l[i+1].id)
                prv[l[i+1].id] = Set{Int}(l[i].id)
            end
            nxt[l[end].id] = Set{Int}()
        end
    end
    return CustomerLinks(prv, nxt)
end

"""
    `removeCusts!`, remove a set of customers/taxis from CustomerLinks
"""
function removeCusts!(l::CustomerLinks, rem)
    for c in rem
        delete!(l.prv, c)
        delete!(l.nxt, c)
    end
    for s in values(l.prv)
        setdiff!(s, rem)
    end
    for s in values(l.nxt)
        setdiff!(s, rem)
    end
    l
end

"""
    `removeInfeasible!`, remove infeasible links from CustomerLinks
"""
function removeInfeasible!(l::CustomerLinks, pb::TaxiProblem)
    tt = getPathTimes(pb.times)
    for (c2, s) in l.prv, c in s
        if c>0 && pb.custs[c].tmin + tt[pb.custs[c].orig, pb.custs[c].dest] +
            tt[pb.custs[c].dest, pb.custs[c2].orig] + 2*pb.customerTime > pb.custs[c2].tmax
            delete!(s, c)
            delete!(l.nxt[c], c2)
        elseif c < 0 && pb.taxis[-c].initTime + tt[pb.taxis[-c].initPos, pb.custs[c2].orig] > pb.custs[c2].tmax
            delete!(s, c)
            delete!(l.nxt[c], c2)
        end
    end
    l
end

"""
    `testLinks`, test if link structure is valid
"""
function testLinks(pb::TaxiProblem, l::CustomerLinks)
    function testKey(d,c, s)
        if !haskey(d,c)
            error("$s has no element $c")
        end
    end
    for t in pb.taxis
        testKey(l.nxt, -t.id, "nxt")
    end
    for c in keys(l.prv)
        testKey(l.nxt, c, "nxt")
        for c2 in l.prv[c]
            testKey(l.nxt, c2, "nxt")
            if c2 > 0
                testKey(l.prv, c2, "prv")
            end
        end
    end
    for c in keys(l.nxt)
        if c>0
            testKey(l.prv, c, "prv")
            for c2 in l.nxt[c]
                testKey(l.nxt, c2, "nxt")
                testKey(l.prv, c2, "prv")
            end
        end
    end
    println("Links all good")
end

"""
    `flowLinks`, returns links for feasible flow
"""
function flowLinks(pb::TaxiProblem, custList::IntSet = IntSet(eachindex(pb.custs)); timeRatio::Float64=0.5)
    tt = getPathTimes(pb.times)
    prv = Dict{Int,Set{Int}}([(c, Set{Int}()) for c in custList])
    nxt = Dict{Int,Set{Int}}([(c, Set{Int}()) for c in custList])
    times = Dict{Int,Float64}([(c, timeRatio* pb.custs[c].tmin + (1-timeRatio)* pb.custs[c].tmax) for c in custList])
    for k in eachindex(pb.taxis)
        nxt[-k] = Set{Int}()
    end

    # first customers
    for t in pb.taxis, c in custList
        if t.initTime + tt[t.initPos, pb.custs[c].orig] <= times[c]
            push!(nxt[-t.id], c)
            push!(prv[c], -t.id)
        end
    end
    # customer pairs
    for c1 in custList, c2 in custList
        if c1 != c2 &&
            times[c1] + tt[pb.custs[c1].orig, pb.custs[c1].dest] +
            tt[pb.custs[c1].dest, pb.custs[c2].orig] + 2*pb.customerTime <= times[c2]
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
function flowKLinks(pb::TaxiProblem, maxLink::Int, custList::IntSet = IntSet(eachindex(pb.custs));
                initOnly::Bool = false, timeRatio::Float64=0.5)
    tt = getPathTimes(pb.times)
    prv = Dict{Int,Set{Int}}([(c, Set{Int}()) for c in custList])
    nxt = Dict{Int,Set{Int}}([(c, Set{Int}()) for c in custList])
    times = Dict{Int,Float64}([(c, timeRatio* pb.custs[c].tmin + (1-timeRatio)* pb.custs[c].tmax) for c in custList])

    for k in eachindex(pb.taxis)
        nxt[-k] = Set{Int}()
    end

    revLink = Dict{Int, Vector{Int}}([(c,Int[]) for c in custList])
    revCost = Dict{Int, Vector{Float64}}([(c,Float64[]) for c in custList])

    # first customers
    for t in pb.taxis
        custs = Int[]; costs = Float64[]
        for c in custList
            if t.initTime + tt[t.initPos, pb.custs[c].orig] <= times[c]
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

    if !initOnly
        # customer pairs
        for c1 in custList
            custs = Int[]; costs = Float64[]
            for c2 in custList
                if c1 != c2 && times[c1] + tt[pb.custs[c1].orig, pb.custs[c1].dest] +
                tt[pb.custs[c1].dest, pb.custs[c2].orig] + 2*pb.customerTime <= times[c2]
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
    end
    return CustomerLinks(prv, nxt)
end
