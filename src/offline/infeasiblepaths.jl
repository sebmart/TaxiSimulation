###################################################
## offline/infeasiblepaths.jl
## Compute path infeasibility for flow model
###################################################


"""
    `FlowInfeasibilities`, contain infeasible paths associated with a FlowProblem
    - f[k] corresponds to paths with k+1 edges or k+2 nodes
    - paths are represented as a list of nodes
"""
typealias FlowInfeasibilities Vector{Array{Edge, 2}}

"""
    `DependentWindow`, represent a coupled to a destination. Store the coupling information
"""
immutable DependentWindow
    "list of customers in path"
    last::Int
    "Minimum first customer coupled drop-off time"
    oMin::Float64
    "Maximum first customer drop-off time"
    oMax::Float64
    "Minimum last customer drop-off time"
    dMin::Float64
    "Maximum last customer coupled drop-off time"
    dMax::Float64
end

# compute dependent time window of simple links
function DependentWindow(pb::FlowProblem, e::Edge)
    tt = pb.time[e]
    DependentWindow(
        dst(e),
        max(pb.tw[src(e)][1], pb.tw[dst(e)][1] - tt),
        min(pb.tw[src(e)][2], pb.tw[dst(e)][2] - tt),
        max(pb.tw[dst(e)][1], pb.tw[src(e)][1] + tt),
        min(pb.tw[dst(e)][2], pb.tw[src(e)][2] + tt)
    )
end

"""
    `mergeWindows`, return the union of two consecutive dependent windows
    !!! we assume that the second object is a simple link
"""
function mergeWindows(dw1::DependentWindow, dw2::DependentWindow)
    DependentWindow(
        dw2.last,
        dw1.oMin + max(0., dw2.oMin - dw1.dMin),
        dw1.oMax + min(0., dw2.oMax - dw1.dMax),
        dw2.dMin + max(0., dw1.dMin - dw2.oMin),
        dw2.dMax + min(0., dw1.dMax - dw2.oMax)
    )
end

"""
    `allInfeasibilities`, return Infeasibility object corresponding to a FlowProblem
"""
function allInfeasibilities(pb::FlowProblem)
    # Create the set of dependent links of length 1 (remove the blocks)
    dep1 = Vector{DependentWindow}[DependentWindow[] for i in vertices(pb.g)]
    for e in edges(pb.g)
        dw = DependentWindow(pb, e)
        if dw.dMax > pb.tw[dst(e)][1] # if it's not a block, add it
            push!(dep1[src(e)], dw)
        end
    end
    k = 1
    dep = Dict{Vector{Int}, DependentWindow}()
    for (o,d) in enumerate(dep1), dw in d
        dep[[o,dw.last]] = dw
    end
    infeasibilities = FlowInfeasibilities()
    while length(dep) > 0
        k += 1
        println("$(length(dep)) $k-link paths")
        infeasible, dep = kInfeasibilities(pb, dep, dep1, k)
        push!(infeasibilities, infeasible)
    end
    return infeasibilities
end

"""
    `kInfeasibilities`, compute dependences and infeasibilities with k links
    using dependences with k-1 links
"""
function kInfeasibilities(pb, depk, dep1, k)
    infeasible = Vector{Int}[]
    depkp1 = Dict{Vector{Int}, DependentWindow}()
    for (l1,dw1) in depk, dw2 in dep1[dw1.last]
        l = vcat(l1, [dw2.last])
        if haskey(depk, l[2:end]) #if there is no block or infeasibility inside
            dw = mergeWindows(dw1,dw2)
            if dw.dMin > pb.tw[dw.last][2] # if infeasible, add it to infeasible list
                push!(infeasible, l)
            elseif dw.dMax > pb.tw[dw.last][1] # if not a block
                depkp1[l] = dw
            end #do nothing if block
        end
    end
    #turn infeasible into a rectangular Array
    res = Array{Edge}(k, length(infeasible))
    for (i, l) in enumerate(infeasible), j in 1:k
        res[j,i] = Edge(l[j], l[j+1])
    end
    return res, depkp1
end
