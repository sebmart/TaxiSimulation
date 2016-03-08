###################################################
## offline/metrics.jl
## Metrics of Taxi-routing offline solutions
###################################################
"""
    `taxiProfit`, compute taxi profit from list of cust. assignment
"""
function taxiProfit(pb::TaxiProblem, custs::Vector{CustomerTimeWindow}, k::Int)
    tt = getPathTimes(pb.times)
    tc = getPathTimes(pb.costs)
    pos = pb.taxis[k].initPos
    drivingTime = 0
    profit = 0.
    for c in custs
        c1 = pb.custs[c.id]
        profit += c1.fare - tc[pos,c1.orig] - tc[c1.orig,c1.dest]
        drivingTime += tt[pos,c1.orig] + tt[c1.orig,c1.dest]
        pos = c1.dest
    end
    return profit - (pb.simTime - drivingTime)*pb.waitingCost
end

"""
    `solutionProfit`, compute the cost of an Offline Solution just using Customers
"""
function solutionProfit(pb::TaxiProblem, t::Vector{Vector{CustomerTimeWindow}})
    profit = 0.0

    for (k,custs) in enumerate(t)
        profit += taxiProfit(pb,custs,k)
    end
    return profit
end

Metrics(s::OfflineSolution) = computeMetrics(s.pb,s.custs)
"""
    `computeMetrics`, compute OfflineSolution's metrics
    - only valid when all taxis available from beginning
    - for now, do not compute drive-distance
"""
function computeMetrics(pb::TaxiProblem, t::Vector{Vector{CustomerTimeWindow}})
    m = Metrics()
    tt = getPathTimes(pb.times)
    tc = getPathTimes(pb.costs)
    m.driveTime      = 0.
    m.emptyDriveTime = 0.
    m.demandRatio    = 0.

    rev = fill(0., length(pb.taxis))
    costs = fill(0., length(pb.taxis))
    for (k,tws) in enumerate(t)
        driveTime = 0.
        fullTime = 0.
        lastPos = pb.taxis[k].initPos
        for tw in tws
            costs[k]  += tc[lastPos, pb.custs[tw.id].orig] + tc[pb.custs[tw.id].orig, pb.custs[tw.id].dest]
            driveTime += tt[lastPos, pb.custs[tw.id].orig] + tt[pb.custs[tw.id].orig, pb.custs[tw.id].dest]
            rev[k] += pb.custs[tw.id].fare
            m.emptyDriveTime -= tt[pb.custs[tw.id].orig, pb.custs[tw.id].dest]
            m.demandRatio += 1.
            lastPos = pb.custs[tw.id].dest
        end
        costs[k] += (pb.simTime - driveTime)*pb.waitingCost
        m.driveTime      += driveTime
        m.emptyDriveTime += driveTime
    end
    profit = rev - costs

    m.revenues = sum(rev)
    m.costs = sum(costs)
    m.profit = sum(profit)
    m.emptyDriveRatio = m.emptyDriveTime/(m.emptyDriveTime + m.driveTime)
    m.driveRatio = m.driveTime/(pb.simTime*length(pb.taxis))
    m.demandRatio /= length(pb.custs)
    m.taxiProfitMean = m.profit/length(pb.taxis)
    m.taxiProfitStd = std(profit)

    return m
end
