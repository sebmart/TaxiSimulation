###################################################
## taxiproblem.jl
## defines a taxi-problem and solution
###################################################

"""
    `Customer` All data needed to describe a customer
"""
immutable Customer
    "customer id"
    id::Int
    "Pick-up node in the graph"
    orig::Int
    "drop-off node in the graph"
    dest::Int
    "time of call for online simulations (seconds)"
    tcall::Float64
    "Earliest time for pickup (seconds)"
    tmin::Float64
    "Latest time for pickup (seconds)"
    tmax::Float64
    "Fare paid by customer for the ride (dollars)"
    fare::Float64
end

function Base.show(io::IO, c::Customer)
    @printf(io,"Cust %d, %d=>%d, t=(%.2f,%.2f,%.2f), fare=%.2f\$", c.id, c.orig, c.dest, c.tcall, c.tmin, c.tmax, c.fare)
end

"""
    `Taxi`: All data needed to represent a taxi"
"""
immutable Taxi
    id::Int
    initPos::Int
    initTime::Float64
end

function Base.show(io::IO, t::Taxi)
    @printf(io,"Taxi %d, init-loc=%d init-time=%.2f", t.id, t.initPos, t.initTime)
end

"""
    `TaxiProblem`: All data needed for simulation
"""
type TaxiProblem
    "The routing network of the taxi problem"
    network::Network
    "routing information, time in seconds"
    times::RoutingPaths
    "same routing as times, but costs in dollars"
    costs::RoutingPaths
    "customers"
    custs::Vector{Customer}
    "taxis"
    taxis::Vector{Taxi}
    "last possible pick-up time (seconds)"
    simTime::Float64
    "cost of waiting one second (dollars)"
    waitingCost::Float64
    "time to pickup or dropoff a customer (seconds)"
    customerTime::Float64
end

TaxiProblem(n::Network, t::RoutingPaths, c::RoutingPaths; customerTime::Float64 = 10., waitingCost = 1./3600.) =
TaxiProblem(n, t, c, Customer[], Taxi[], 0., waitingCost, customerTime)

function Base.show(io::IO, pb::TaxiProblem)
    nLocs = nNodes(pb.network); nRoad = nRoads(pb.network)
    println(io, "Taxi Problem")
    println(io, "City with $nLocs locations and $nRoad roads")
    if pb.simTime == 0.
        println(io, "No simulation created yet")
    else
        @printf(io, "Simulation with %i customers and %i taxis for %.2f minutes\n",
            length(pb.custs), length(pb.taxis), pb.simTime/60.)
    end
end

Base.copy(p::TaxiProblem) = TaxiProblem(p.network, p.times, p.costs, p.custs, p.taxis, p.simTime, p.waitingCost, p.customerTime)

"""
    `CustomerAssignment`:  assignement of a customer to a taxi
    - Order: timeIn - wait - trip - wait - timeOut
"""
immutable CustomerAssignment
    "customer's ID"
    id::Int
    "pickup time"
    timeIn::Float64
    "dropoff time"
    timeOut::Float64
end

function Base.show(io::IO, t::CustomerAssignment)
    @printf(io,"Customer %d is picked-up between %.2f and %.2f", t.id, t.timeIn, t.timeOut)
end

"""
    `TaxiActions`: actions of a taxi during a simulation (path, timings and customers)
"""
type TaxiActions
    "taxi's ID"
    taxiID::Int
    "path in the network (list of nodes)"
    path::Vector{Int}
    "times of each road travel (length(time) = length(path) - 1"
    times::Vector{Tuple{Float64, Float64}}
    "customers assigned to taxi, sorted by pick-up time"
    custs::Vector{CustomerAssignment}
end

function Base.show(io::IO, t::TaxiActions)
    @printf(io,"Actions of taxi %d: serves %d customers - drives %d roads", t.taxiID, length(t.custs), length(t.path))
end

"""
    `TaxiSolution`: a solution to a TaxiProblem
"""
type TaxiSolution
    "corresponding TaxiProblem"
    pb::TaxiProblem
    "actions of each taxi"
    actions::Vector{TaxiActions}
    "rejected customers"
    rejected::IntSet
    "solution's profit"
    profit::Float64
end

TaxiSolution(pb::TaxiProblem, actions::Vector{TaxiActions}) =
TaxiSolution(pb, actions, rejectedCustomers(pb,actions), solutionProfit(pb, actions))

function Base.show(io::IO, sol::TaxiSolution)
    nCusts = length(sol.pb.custs); nTaxis = length(sol.pb.taxis)
    println(io, "TaxiSolution, problem with $nCusts customers and $nTaxis taxis")
    @printf(io, "Profit : %.2f dollars\n", sol.profit)
    println(io, "$(length(sol.rejected)) customers not served. ")
end


"""
    `testSolution`, Tests if a TaxiSolution is feasible
    - The paths must be feasible paths (time to cross roads, no jumping..)
    - The customers must correspond to the path, and be driven directly as soon
     as picked-up, using the ehortest path available
"""
function testSolution(sol::TaxiSolution)
    testSolution(OfflineSolution(sol))
end
