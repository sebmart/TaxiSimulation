###################################################
## online/offlineplanning.jl
## specific online algorithm that maintain a futur - offline solution throughout the
## simulation
###################################################


"""
    `OfflinePlanning`, abstract type inherited by offline-planning online algorithms
    these algorithm maintain an inner offline solution of futur moves throughout the
    simulation
    Needs to have attributes:
    - `pb::TaxiProblem` the maintained taxi problem
    - `sol::OfflineSolution` the maintained offline solution (contains pb)
    - `currentCusts::IntSet` the known futur customers

    Needs to implement:
    - `initialPlanning!(OfflinePlanning)` initialize solution
    - `updatePlanning!(OfflinePlanning, endtime, newcustomersIds)`

"""
abstract OfflinePlanning <: OnlineAlgorithm

function onlineInitialize!(op::OfflinePlanning, pb::TaxiProblem)
    op.currentCusts = Set{Int}()
    pb.taxis = copy(pb.taxis)
    op.pb = pb
    if !isempty(pb.custs)
        pb.custs = Array{Customer}(maximum([c.id for c in pb.custs]))
		for c in newCustomers
			pb.custs[c.id] = c
			push!(op.currentCusts, c.id)
	    end
    end
    initialPlanning!(op)
end

function onlineUpdate!(op::OfflinePlanning, endTime::Float64, newCustomers::Vector{Customer})
    newCusts = Int[]
    tt = getPathTimes(pb.times)

    #Add new customers
    for c in newCustomers
        if length(op.pb.custs) < c.id
            resize!(op.pb.custs, c.id)
        end
            push!(op.sol.rejected, c.id)
            push!(op.currentCusts, c.id)
            push!(newCusts, c.id)
            pb.custs[c.id] = c
        end
    end

    updatePlanning!(op, endTime, newCusts)

    actions = emptyActions(op.pb)
    for (k,custs) in enumerate(op.sol.custs)
        while !isempty(custs)
            c = custs[1]
            if c.tInf - tt[op.pb.taxis[k].initPos, op.pb.custs[c.id].orig] <= endTime
                path, times = getPathWithTimes(op.pb.times, op.pb.taxis[k].initPos, op.pb.custs[c.id].orig,
                                    startTime=c.tInf - tt[op.pb.taxis[k].initPos, op.pb.custs[c.id].orig])
                append!(actions[k].path, path[2:end])
                append!(actions[k].times, times)
                path, times = getPathWithTimes(op.pb.times, op.pb.custs[c.id].orig, op.pb.custs[c.id].dest,
                                    startTime=c.tInf + pb.customerTime)
                append!(actions[k].path, path[2:end])
                append!(actions[k].times, times)

                newTime = c.tInf + 2*op.pb.customerTime + tt[op.pb.custs[c.id].orig, op.pb.custs[c.id].dest]
                push!(actions[k].custs, CustomerAssignment(c.id, c.tInf, newTime))
                op.pb.taxis[k] = Taxi(op.pb.taxis[k].id, op.pb.custs[c.id].dest, newTime)
                shift!(custs)
                delete!(op.currentCusts, c.id)
            else
                break
            end
        end
        if op.pb.taxis[k].initTime < endTime
            op.pb.taxis[k] = Taxi(op.pb.taxis[k].id, op.pb.taxis[k].initPos, endTime)
        end
    end

    # remove rejected customers of the past
    for c in op.sol.rejected
        if op.pb.custs[c].tmax < endTime
            delete!(op.sol.rejected, c)
            delete!(op.currentCusts, c)
        end
    end

    return actions
end
