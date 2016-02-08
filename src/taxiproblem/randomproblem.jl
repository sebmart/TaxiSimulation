###################################################
## taxiproblem/randomproblem.jl
## create random taxiproblem object from given city and routing
###################################################

"""
    `addRandomCustomers!`: adds random customers (uniformly) to a TaxiProblem
    - customers are a Poisson process for each node with a mean of `custNodeHour` customer/hour
    - customers destination uniformely random
    - last pick-up time is `maxTime` (in seconds)
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
