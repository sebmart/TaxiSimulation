###################################################
## offline/timewindows.jl
## operating with time windows
###################################################


"""
    `updateTimeWindow!(OfflineSolution,k::Int)`
    Update the time windows of taxi `k` timeline
    Do not check for feasibility or update rejected!
"""
function updateTimeWindows!(s::OfflineSolution,k::Int)
    l = s.custs[k]; c=s.pb.custs
    tt(i::Int, j::Int) = traveltime(s.pb.times,i,j)

    if !isempty(l)
        l[1].tInf = max(c[l[1].id].tmin, s.pb.taxis[k].initTime + tt(s.pb.taxis[k].initPos, c[l[1].id].orig))
        l[end].tSup = c[l[end].id].tmax
    end
    for i = 2:(length(l))
        l[i].tInf = max(c[l[i].id].tmin, l[i-1].tInf+
        tt(c[l[i-1].id].orig, c[l[i-1].id].dest)+
        tt(c[l[i-1].id].dest, c[l[i].id].orig)+ 2*s.pb.customerTime)
    end
    for i = (length(l) - 1):(-1):1
        l[i].tSup = min(c[l[i].id].tmax, l[i+1].tSup-
        tt(c[l[i].id].orig, c[l[i].id].dest)-
        tt(c[l[i].id].dest, c[l[i+1].id].orig) - 2*s.pb.customerTime)
    end
    s
end

"""
    `updateTimeWindow!(OfflineSolution)`
    update all time windows, check for feasibility and updates `isRejected`
"""
function updateTimeWindows!(s::OfflineSolution)
    s.isRejected = trues(length(s.pb.custs))
    for k in eachindex(s.pb.taxis)
        updateTimeWindows!(s,k)
        for c in s.custs[k]
            if c.tInf > c.tSup + EPS
                error("Solution Infeasible for taxi $k : customer $(c.id) : tInf = $(c.tInf), tSup = $(c.tSup)")
            end
            s.isRejected[c.id] = false
        end
    end
    s
end

"""
    `OfflineSolution(TaxiSolution)` transform a feasible solution into an Offline solution
    (compute max time windows)
"""
function OfflineSolution(s::TaxiSolution)
    tw = Array(Vector{CustomerTimeWindow}, length(pb.taxis))
    rejected = trues(length(s.pb.custs))
    for k in eachindex(s.pb.taxis)
        tw[k] = [CustomerTimeWindow(c.id, s.pb.custs[c.id].tmin, s.pb.custs[c.id].tmax) for c in sol.actions[k].custs]
    end
    sol = OfflineSolution(tw, rejected, s.profit)
    return updateTimeWindows!(sol)
end

"""
    `TaxiSolution(OfflineSolution)`, transform offline solution into full solution
    - rule: pick up customers as early as possible
"""
function TaxiSolution(sol::OfflineSolution)

    nTaxis, nCusts = length(pb.taxis), length(pb.custs)
    actions = Array(TaxiActions, nTaxis)
    tt = traveltimes(pb)
    for k in 1:nTaxis
        custs = CustomerAssignment[]
        for c in sol.custs[k]
            push!( custs, CustomerAssignment(c.id,c.tInf,c.tInf + tt[pb.custs[c.id].orig, pb.custs[c.id].dest] + 2*pb.customerTime))
        end
        actions[k] = TaxiActions(pb,k,custs)
    end
    return TaxiSolution(sol.pb, actions, sol.isRejected, sol.profit)

end

"""
    `TaxiActions(TaxiProblem,k::Int, Vector{CustomerAssignment})`
    - Reconstruct all of a taxi's actions from its assigned customers
    - The rule is to wait _before_ going to the next customer if the taxi has to wait
"""
function TaxiActions(pb::TaxiProblem, id_taxi::Int, custs::Array{CustomerAssignment,1})
    tt(i::Int, j::Int) = traveltime(s.pb.times,i,j)
    times = Float64[]
    prevPos = pb.taxis[id_taxi].initPos
    pos = pb.taxis[id_taxi].initPos
    path = Int[]
    times = Tuple{Float64,Float64}[]
    for c in custs
        cust = pb.custs[c.id]

        #travels to customer origin
        p,t = getPathWithTimes(pb.times, pos, cust.orig, prevPos, startTime=c.timeIn - tt(pos, cust.orig))
        append!(path,p[1:end-1])
        append!(times,t)

        #travels with customer
        p,t = getPathWithTimes(pb.times, cust.orig, cust.dest, pos, startTime=c.timeIn + pb.customerTime)
        append!(path,p[1:end-1])
        append!(times,t)
        pos = cust.dest
        prevPos = cust.orig
    end
    push!(path, pos)
    return TaxiActions(id_taxi,path,times,custs)
end
