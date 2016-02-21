###################################################
## onlien/online.jl
## basics of online problem solving
###################################################

"""
    `OnlineAlgorithm`, abstract type inherited by online algorithms
    Needs to implement:
    - `initialize!(OnlineAlgorithm, TaxiProblem)`, initializes a given OnlineAlgorithm with
    a selected taxi problem without customers.
    - `update!(OnlineAlgorithm, Float64, Vector{Customer})`, updates OnlineAlgorithm to
    account for new customers, returns a list of TaxiActions since the last update.
"""

abstract OnlineAlgorithm

"""
    `onlineSimulation`, simulates the online problem: send only the online information to an
     online algorithm, in an iterative way. Compiles the taxis' online actions into a
    TaxiSolution object and returns it.
    - `period`: period of update in seconds. If 0, update for each new customer
"""
function onlineSimulation(pb::TaxiProblem, oa::OnlineAlgorithm, period::Float64 = 0.; verbose::Bool=false)

	# Sorts customers by tcall
	customers = sort(pb.custs, by = x -> x.tcall)

	# Initializes the online method with the given taxi problem without the customers
	init = copy(pb)
	init.custs = Customer[]
	onlineInitialize!(oa, init)
	allTaxiActions = emptyActions(pb)


    if verbose
        p = floor(Int, 100*tStart/maxTime)
        if p > percent
            @printf("=> %02d%%, Timestep : %.2f   \r", p, tStart)
            flush(STDOUT)
            percent = p
        end
    end

	#Create list of update times and customers
	if period == 0.
        updates = NewCustUpdate(customers)
    else
        updates = PeriodUpdate(period)
    end
    for (newCusts, tStart, tEnd) in updates
        if verbose
            m,s = minutesSeconds(tStart)
            @printf("\rtime : %dm%02ds (%.2f%%)   ", m,s, 100*tStart/pb.simTime)
        end
        newTaxiActions = onlineUpdate!(oa, tEnd, newCusts)
        for (k,allAction) in enumerate(allTaxiActions)
            if !isempty(newTaxiActions[k].times)
                if newTaxiActions[k].times[1] < tStart - EPS
                    error("Path modification back in time: $(newTaxiActions[k].times[1]) < $tStart !")
                else
                    append!(allAction.path,newTaxiActions[k].path[2:end])
                    append!(allAction.times,newTaxiActions[k].times)
                end
            end
            if !isempty(newTaxiActions[k].custs)
                if newTaxiActions[k].custs[1].timeIn < tStart - EPS
                    error("Customer modification back in time: $(newTaxiActions[k].custs[1].timeIn) < $tStart!")
                else
                    append!(allAction.custs,newTaxiActions[k].custs)
                end
            end
        end
    end

	return TaxiSolution(pb, allTaxiActions)
end


"""
    `NewCustUpdate`, iterator on customers that creates an update for each new customer
"""
type NewCustUpdate
    custs::Vector{Customer}
end
Base.start(it::NewCustUpdate) = (0., 1) # (tStart of next, index of next)
Base.done(it::NewCustUpdate, s::Tuple{Float64, Int}) = s[2] > length(it.custs)
function Base.next(it::NewCustUpdate, s::Tuple{Float64, Int})
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
type PeriodUpdate
    custs::Vector{Customer}
    period::Float64
end
Base.start(it::PeriodUpdate) = (0,1) # (iteration number of next, next cust)
Base.done(it::PeriodUpdate, s::Tuple{Int,Int}) = s[2] > length(it.custs)
function Base.next(it::PeriodUpdate, s::Tuple{Int,Int})
    newCusts = Customer[]
    i = s[2]
    while i <= length(it.custs) && it.custs[i].tcall <= s[1]*it.period
        push!(newCusts, it.custs[i])
        i += 1
    end
    if i > length(it.custs)
        return (newCusts, s[1]*it.period, Inf), (s[1]+1, i)
    else
        return (newCusts, s[1]*it.period, (s[1]+1)*it.period), (s[1]+1, i)
    end
end
