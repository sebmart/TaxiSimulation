###################################################
## taxiproblem/randomproblem.jl
## create random taxiproblem object from given city and routing
###################################################

"""
    `addRandomCustomers!`: adds random customers (uniformly) to a TaxiProblem
    - customers are a Poisson process for each node with a mean of `custNodeHour` customer/hour
    - customers destination uniformely random
    - pickups during a time window of `simTime` seconds
    - customers are ready to wait exactly custWait, and call exactly custCall minutes before
"""
function addRandomCustomers!(pb::TaxiProblem,
                            simTime::Float64 = 60. * 60.,
                            custNodeHour::Float64 = 2.;
                            hourFare::Float64 = 80.,
                            custWait::Float64 = 5.0 * 60.,
                            custCall::Float64 = 30.0 * 60.)
    pb.custs = Customer[]
    tt(i::Int, j::Int) = traveltime(pb.times,i,j)
    waitTime = Exponential(3600./(custNodeHour*nNodes(pb.network)))
    t = rand(waitTime)
    while t <= simTime
        orig = rand(1:nNodes(pb.network))
        dest = rand(1:nNodes(pb.network) - 1)
        orig <= dest && (dest += 1)


        fare = (hourFare/3600)* traveltime(pb.times,orig,dest)
        tmin  = t
        tmaxt = min(simTime, t + custWait)
        tcall = max(0., tmin - custCall)
        push!(pb.custs,
        Customer(length(pb.custs)+1,orig,dest,tcall,tmin,tmaxt,fare))

        t += rand(waitTime)
    end
    pb.simTime = simTime
    pb
end

"""
    `addRandomTaxis!`: adds random taxis (uniformly) to a TaxiProblem
    - adds `nTaxis` with uniform initial positions and 0 initial time
"""
function addRandomTaxis!(pb::TaxiProblem, nTaxis::Int = div(nNodes(pb.network),4))
    pb.taxis = [Taxi(i,rand(1:nNodes(pb.network)), 0.) for i = 1:nTaxis]
    pb
end

"""
    `addDistributedTaxis!`: adds random taxis to a TaxiProblem, respecting the distribution of customers
    - adds `nTaxis` 0 initial time, customers must be pre-loaded
"""
function addDistributedTaxis!(pb::TaxiProblem, nTaxis::Int = div(nNodes(pb.network),4))
    if isempty(pb.custs)
        error("customers have to be added before!")
    end
    pb.taxis = [Taxi(i, rand()<0.5 ? rand(pb.custs).dest : rand(pb.custs).orig, 0.) for i = 1:nTaxis]
    pb
end
