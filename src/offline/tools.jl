###################################################
## offline/tools.jl
## tools for offline and time-windows
###################################################


"""
    `updateTimeWindow!(TaxiProblem,Vector{CustomerTimeWindow},k::Int)`
    Update the time windows of taxi `k` timeline
    Do not check for feasibility or update rejected!
"""
function updateTimeWindows!(pb::TaxiProblem, l::Vector{CustomerTimeWindow}, k::Int)
    c= pb.custs
    tt = getPathTimes(pb.times)

    if !isempty(l)
        l[1].tInf = max(c[l[1].id].tmin, pb.taxis[k].initTime + tt[pb.taxis[k].initPos, c[l[1].id].orig])
        l[end].tSup = c[l[end].id].tmax
    end
    for i = 2:(length(l))
        l[i].tInf = max(c[l[i].id].tmin, l[i-1].tInf+
        tt[c[l[i-1].id].orig, c[l[i-1].id].dest]+
        tt[c[l[i-1].id].dest, c[l[i].id].orig]+ 2*pb.customerTime)
    end
    for i = (length(l) - 1):(-1):1
        l[i].tSup = min(c[l[i].id].tmax, l[i+1].tSup-
        tt[c[l[i].id].orig, c[l[i].id].dest]-
        tt[c[l[i].id].dest, c[l[i+1].id].orig] - 2*pb.customerTime)
    end
    l
end
function updateTimeWindows!(s::OfflineSolution, k::Int)
    updateTimeWindows!(s.pb,s.custs[k], k)
    s
end
"""
    `updateTimeWindow!(OfflineSolution)`
    update all time windows
"""
function updateTimeWindows!(pb::TaxiProblem, l::Vector{Vector{CustomerTimeWindow}})
    for k in eachindex(pb.taxis)
        updateTimeWindows!(pb,l[k],k)
    end
    l
end
function updateTimeWindows!(s::OfflineSolution)
    updateTimeWindows!(s.pb, s.custs)
    s
end

"""
    `getRejected`, compute rejected customers of offline solution
"""
function getRejected(pb::TaxiProblem, custs::Vector{Vector{CustomerTimeWindow}})
    rejected = DataStructures.IntSet(1:length(pb.custs))
    for l in custs, c in l
        delete!(rejected,c.id)
    end
    return rejected
end
getRejected(s::OfflineSolution) = getRejected(s.pb, s.custs)

"""
    `OfflineSolution(TaxiSolution)` transform a feasible solution into an Offline solution
    (compute max time windows)
"""
function OfflineSolution(s::TaxiSolution)
    tw = Array{Vector{CustomerTimeWindow}}(undef, length(s.pb.taxis))
    for k in eachindex(s.pb.taxis)
        tw[k] = [CustomerTimeWindow(c.id, s.pb.custs[c.id].tmin, s.pb.custs[c.id].tmax) for c in s.actions[k].custs]
    end
    sol = OfflineSolution(s.pb, tw, s.rejected, solutionProfit(s.pb,tw))
    return updateTimeWindows!(sol)
end

"""
    `TaxiSolution(OfflineSolution)`, transform offline solution into full solution
    - rule: pick up customers as early as possible
"""
function TaxiSolution(s::OfflineSolution)
    nTaxis, nCusts = length(s.pb.taxis), length(s.pb.custs)
    actions = Array{TaxiActions}(undef, nTaxis)
    tt(i::Int, j::Int) = traveltime(s.pb.times,i,j)
    for k in 1:nTaxis
        custs = CustomerAssignment[]
        for c in s.custs[k]
            push!(custs, CustomerAssignment(c.id,c.tInf,c.tInf + tt(s.pb.custs[c.id].orig, s.pb.custs[c.id].dest) + 2*s.pb.customerTime))
        end
        actions[k] = TaxiActions(s.pb,k,custs)
    end
    return TaxiSolution(s.pb, actions, s.rejected, s.profit)

end

"""
    `TaxiActions(TaxiProblem,k::Int, Vector{CustomerAssignment})`
    - Reconstruct all of a taxi's actions from its assigned customers
    - The rule is to wait _before_ going to the next customer if the taxi has to wait
"""
function TaxiActions(pb::TaxiProblem, id_taxi::Int, custs::Array{CustomerAssignment ,1})
    tt(i::Int, j::Int) = traveltime(pb.times,i,j)
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

"""
    `testSolution(OfflineSolution)`, test if offline solution is feasible
"""
function testSolution(sol::OfflineSolution)
    pb = sol.pb
    custs = pb.custs
    rejected = DataStructures.IntSet(eachindex(pb.custs))
    tt(i::Int, j::Int) = traveltime(pb.times,i,j)
    custTime = pb.customerTime

    for k in eachindex(pb.taxis)
        prevPos = pb.taxis[k].initPos
        prevInf = pb.taxis[k].initTime
        prevSup = pb.taxis[k].initTime
        for tw in sol.custs[k]
            c = custs[tw.id]
            @test prevInf + tt(prevPos, c.orig) <= tw.tInf + EPS
            @test prevSup + tt(prevPos, c.orig) <= tw.tSup + EPS
            @test c.tmin  <= tw.tInf + EPS
            @test tw.tInf <= tw.tSup + EPS
            @test tw.tSup <= c.tmax  + EPS

            prevPos = c.dest
            prevInf = tw.tInf + tt(c.orig, c.dest) + 2*pb.customerTime
            prevSup = tw.tSup + tt(c.orig, c.dest) + 2*pb.customerTime
            if ! ( tw.id in rejected)
                error("Customer $(tw.id) picked-up twice")
            end
            delete!(rejected, tw.id)
        end
    end
    if sol.rejected != rejected
        error("Rejected customers do not match")
    end

    for f in fieldnames(Metrics)
        @test sol.profit - EPS <= solutionProfit(sol.pb,sol.custs) <= sol.profit + EPS
    end
    println("Solution is feasible!")
end

printSolution(s::OfflineSolution, io::IO = STDOUT; verbose=1) =
printSolution(TaxiSolution(s), io, verbose=verbose)

"""
    `noassignment`, test if all taxis are idle
"""
function noassignment(s::OfflineSolution)
    for tws in s.custs
        if !isempty(tws)
            return false
        end
    end
    return true
end
