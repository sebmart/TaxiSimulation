###################################################
## taxiproblem/metrics.jl
## Metrics of Taxi-routing solutions
###################################################



"""
    `computeMetrics`, compute TaxiSolution's metrics
    - only valid when all taxis available from beginning
"""
function computeMetrics(pb::TaxiProblem, actions::Vector{TaxiActions})
    m = Metrics()
    rt = pb.times.times
    rc = pb.costs.times
    tt = getPathTimes(pb.times)
    m.driveTime      = 0.
    m.driveDistance  = 0.
    m.emptyDriveTime = 0.
    m.demandRatio    = 0.

    rev = fill(0., length(pb.taxis))
    costs = fill(0., length(pb.taxis))
    for (k,a) in enumerate(actions)
        driveTime = 0.
        fullTime = 0.
        for i in 1:length(a.path)-1
            costs[k] += rc[a.path[i], a.path[i+1]]
            driveTime += rt[a.path[i], a.path[i+1]]
            m.driveDistance += pb.network.roads[a.path[i], a.path[i+1]].distance
        end
        for c in a.custs
            rev[k] += pb.custs[c.id].fare
            m.emptyDriveTime -= tt[pb.custs[c.id].orig, pb.custs[c.id].dest]
            m.demandRatio += 1.
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

function Base.show(io::IO, m::Metrics)
    println("Solution metrics:")
    @printf("Revenues: \$%.2f, Costs: \$%.2f, Profit: \$%.2f \n", m.revenues, m.costs, m.profit)
    @printf("%.2f%% of the demand is met\n", m.demandRatio*100.)
    @printf("%.3fkm traveled, for %.2fh of driving\n", m.driveDistance/1000., m.driveTime/3600.)
    @printf("%.2f%% of waiting time, %.2f%% of empty rides, \n", 100*(1.-m.driveRatio), m.emptyDriveRatio*100.)
    @printf("Fairness: taxi profit = \$%.2f +- \$%.2f\n", m.taxiProfitMean, m.taxiProfitStd)
end