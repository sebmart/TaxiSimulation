###################################################
## taxiproblem/metrics.jl
## Metrics of Taxi-routing solutions
###################################################

"""
    `Metrics`, store performance measures for taxi-routing solutions
    `Inf` if not computed
"""
mutable struct Metrics
    # Revenues
    "Solution revenues (customer fares)"
    revenues::Float64
    "Solution costs (driving/waiting costs)"
    costs::Float64
    "Profit (revenues-costs)"
    profit::Float64

    # Efficiency
    "Total distance driven (meters)"
    driveDistance::Float64
    "Total time driven"
    driveTime::Float64
    "Total time driven empty"
    emptyDriveTime::Float64
    "Percentage of time empty when driving = emptyDrivingTime/(drivingTime+emptyDrivingTime)"
    emptyDriveRatio::Float64
    "Percentage of time spent driving"
    driveRatio::Float64
    "Percentage of picked-up customers"
    demandRatio::Float64

    # Fairness
    "Mean of taxi revenue (=revenues/nTaxis)"
    taxiProfitMean::Float64
    "Taxi revenue standard deviation"
    taxiProfitStd::Float64
end
Metrics() = Metrics(fill(-Inf, length(fieldnames(Metrics)))...)
Metrics(s::TaxiSolution) = computeMetrics(s.pb, s.actions)

function Base.show(io::IO, m::Metrics)
    println("Solution metrics:")
    @printf("Revenues: \$%.2f, Costs: \$%.2f, Profit: \$%.2f \n", m.revenues, m.costs, m.profit)
    @printf("%.2f%% of the demand is met\n", m.demandRatio*100.)
    if m.driveDistance != -Inf
        @printf("%.3fkm traveled, for %.2fh of driving\n", m.driveDistance/1000., m.driveTime/3600.)
    else
        @printf("In total, %.2fh of driving\n", m.driveTime/3600.)
    end
    @printf("%.2f%% of waiting time, %.2f%% of driving time is empty, \n", 100*(1. -m.driveRatio), m.emptyDriveRatio*100.)
    @printf("Fairness: taxi profit = \$%.2f +- \$%.2f\n", m.taxiProfitMean, m.taxiProfitStd)
end
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
    totalTime = 0.
    for (k,a) in enumerate(actions)
        driveTime = 0.
        for i in 1:length(a.path)-1
            costs[k] += rc[a.path[i], a.path[i+1]]
            m.driveTime += rt[a.path[i], a.path[i+1]]
            m.driveDistance += pb.network.roads[a.path[i], a.path[i+1]].distance
        end

        for c in a.custs
            rev[k] += pb.custs[c.id].fare
            m.driveTime += 2*pb.customerTime
            m.emptyDriveTime -= tt[pb.custs[c.id].orig, pb.custs[c.id].dest] + 2*pb.customerTime
            m.demandRatio += 1.
        end
        totalTime += isempty(a.times) ? pb.simTime : (a.times[end][2] + pb.customerTime) # here we assume that the taxi ends with a drop-off

        costs[k] += (pb.simTime - driveTime)*pb.waitingCost


    end
    m.emptyDriveTime += m.driveTime

    profit = rev - costs

    m.revenues = sum(rev)
    m.costs = sum(costs)
    m.profit = sum(profit)
    m.emptyDriveRatio = m.emptyDriveTime/(m.driveTime + EPS)
    m.driveRatio = m.driveTime/totalTime
    m.demandRatio /= length(pb.custs)
    m.taxiProfitMean = mean(profit)
    m.taxiProfitStd = std(profit)

    return m
end

"""
    `taxiProfit`, compute taxi profit from list of cust. assignment
"""
function taxiProfit(pb::TaxiProblem, a::TaxiActions)
    rt = pb.times.times
    rc = pb.costs.times
    drivingTime = 0.
    profit = 0.
    for i in 1:length(a.path)-1
        profit -= rc[a.path[i], a.path[i+1]]
        drivingTime += rt[a.path[i], a.path[i+1]]
    end
    for c in a.custs
        profit += pb.custs[c.id].fare
    end
    return profit - (pb.simTime - drivingTime)*pb.waitingCost
end

"""
    `solutionProfit`, compute the cost of an Offline Solution just using Customers
"""
function solutionProfit(pb::TaxiProblem, sol::Vector{TaxiActions})
    profit = 0.
    for actions in sol
        profit += taxiProfit(pb, actions)
    end
    return profit
end
