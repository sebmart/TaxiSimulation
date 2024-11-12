###################################################
## online/online.jl
## basics of online problem solving
###################################################

"""
    `OnlineAlgorithm`, abstract type inherited by online algorithms
    Needs to implement:
    - `onlineInitialize!(OnlineAlgorithm, TaxiProblem)`, initializes a given OnlineAlgorithm with
    a selected taxi problem with just initial customers.
    - `onlineUpdate!(OnlineAlgorithm, Float64, Vector{Customer})`, updates OnlineAlgorithm to
    account for new customers, returns a list of TaxiActions since the last update.
"""

abstract type OnlineAlgorithm end
Base.show(io::IO, t::OnlineAlgorithm)=
    print(io,"Online Algorithm: ", split(string(typeof(t)), ".")[end])

"""
    `onlineSimulation`, simulates the online problem: send only the online information to an
     online algorithm, in an iterative way. Compiles the taxis' online actions into a
    TaxiSolution object and returns it.
    - `period`: period of update in seconds. If 0, update for each new customer
    - `horizon`: horizon in minutes (max on tmin - tcall)
"""
function onlineSimulation(pb::TaxiProblem, oa::OnlineAlgorithm;
                period::Real = 0., verbose::Bool=true, horizon::Real = Inf)

	# Sorts customers by tcall
	customers = sort(pb.custs, by = x -> x.tcall)
    if horizon < Inf
        for (i,c) in enumerate(customers)
            customers[i]=
            Customer(c.id, c.orig, c.dest, max(c.tcall, c.tmin-horizon), c.tmin, c.tmax, c.fare)
        end
        sort!(customers, by = x -> x.tcall)
    end
    # separate customers with tcall = 0 (pre-known data)
    firstNew = length(customers) + 1
    for (i,c) in enumerate(customers)
        if c.tcall > 0.
            firstNew = i
            break
        end
    end
    firstCustomers = sort(customers[1:firstNew - 1], by=x -> x.tmin)
    customers = customers[firstNew:end]

	# Initializes the online method with the given taxi problem without the customers
	init = copy(pb)
	init.custs = firstCustomers

    verbose && print("\rpre-simulation computations...")

	onlineInitialize!(oa, init)
	allTaxiActions = emptyActions(pb)

	#Create list of update times and customers
	if period == 0.
        updates = NewCustUpdate(customers)
        verbose && (endTime = isempty(customers) ? pb.simTime : customers[end].tcall)
    else
        updates = PeriodUpdate(customers, period, pb.simTime)
        verbose && (endTime = pb.simTime)
    end

    acceptedCustomers = DataStructures.IntSet()

    verbose && (lastPrint = -Inf; realTimeStart = time())

    for (newCusts, tStart, tEnd) in updates
        t = time()
        if verbose && t - lastPrint >= 0.5
            m, s  = minutesSeconds(tStart)
            m2,s2 = minutesSeconds(t-realTimeStart)
            lastPrint = time()
            @printf("\rsim-time: %dm%02ds (%.2f%%) realTime:(%dm%02ds)             ", m,s, 100*tStart/endTime, m2,s2)
        end
        newTaxiActions = onlineUpdate!(oa, tEnd, sort(newCusts, by=c->c.tmin))
        for (k,allAction) in enumerate(allTaxiActions)
            if !isempty(newTaxiActions[k].times)
                if newTaxiActions[k].times[1][1] < tStart - EPS
                    error("Path modification back in time: $(newTaxiActions[k].times[1]) < $tStart !")
                else
                    append!(allAction.path,newTaxiActions[k].path[2:end])
                    append!(allAction.times,newTaxiActions[k].times)
                end
            end
            custAssignments = newTaxiActions[k].custs
            if !isempty(custAssignments)
                if custAssignments[1].timeIn < tStart - EPS
                    error("Customer modification back in time: $(custAssignments[1].timeIn) < $tStart !")
                else
                    for c in custAssignments
                        if c.id in acceptedCustomers
                            error("\"$c\" cannot be picked-up twice!")
                        else
                            push!(acceptedCustomers, c.id)
                        end
                    end
                    append!(allAction.custs, custAssignments)
                end
            end
        end
    end
    verbose && print("\n")

	return TaxiSolution(pb, allTaxiActions)
end


"""
    `NewCustUpdate`, iterator on customers that creates an update for each new customer
"""
mutable struct NewCustUpdate
    custs::Vector{Customer}
end
# Base.start(it::NewCustUpdate) = (0., 1) # (tStart of next, index of next), this equals to Base.rest(it::NewCustUpdate, 0)
# Base.done(it::NewCustUpdate, s::Tuple{Float64, Int}) = s[1] == Inf
function Base.iterate(it::NewCustUpdate, s::Tuple{Float64, Int})
    s[1] == Inf && return nothing
    newCusts = Customer[]
    i = s[2]
    while i <= length(it.custs) && it.custs[i].tcall <= s[1]
        push!(newCusts, it.custs[i])
        i += 1
    end
    if i > length(it.custs)
        return (newCusts, s[1], Inf), (Inf, i)
    else
        return (newCusts, s[1], it.custs[i].tcall + EPS), (it.custs[i].tcall + EPS, i)
    end
end


"""
    `PeriodUpdate`, iterator on customers that creates an update for each fixed period
"""
mutable struct PeriodUpdate
    custs::Vector{Customer}
    period::Float64
    simTime::Float64
end
# Base.start(it::PeriodUpdate) = (0,1) # This equals to rest(it::PeriodUpdate, 0)
# Base.done(it::PeriodUpdate, s::Tuple{Int,Int}) = s[1] == typemax(Int)
function Base.iterate(it::PeriodUpdate, s::Tuple{Int,Int})
    # End condition
    s[1] == typemax(Int) && return nothing 
    newCusts = Customer[]
    i = s[2]
    while i <= length(it.custs) && it.custs[i].tcall <= s[1]*it.period
        c = it.custs[i]
        if c.tmax >= s[1]*it.period
            push!(newCusts, Customer(c.id,c.orig,c.dest,c.tcall,
            max(c.tmin,s[1]*it.period),c.tmax,c.fare))
        end
        i += 1
    end

    if s[1]*it.period > it.simTime
        return (newCusts, s[1]*it.period, Inf), (typemax(Int), i)
    else
        return (newCusts, s[1]*it.period, (s[1]+1)*it.period), (s[1]+1, i)
    end
end
