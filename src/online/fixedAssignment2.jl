"Insert customer in a taxi timeline, but cannot be modified later"
type FixedAssignment <: OnlineMethod
	pb::TaxiProblem
	sol::IntervalSolution
    startTime::Float64

    noTcall::Bool
    noTmaxt::Bool
    period::Float64
	# FixedAssignment() = new()
    function FixedAssignment(;period::Float64=0.)
        offline = new()
        offline.noTcall = false
        offline.noTmaxt = false
        offline.period = period
        return offline
    end
end

"""
Initializes a given FixedAssignment with a selected taxi problem without customers
"""
function onlineInitialize!(om::FixedAssignment, pb::TaxiProblem)
	pb.taxis = copy(pb.taxis)
    om.pb = pb
    om.startTime=0.
    om.sol = IntervalSolution(pb)
end


function onlineUpdate!(om::FixedAssignment, endTime::Float64, newCustomers::Vector{Customer}, virtualCustomers::Vector{Customer} = Customer[])
    pb = om.pb
    tt = traveltimes(pb)
    for c in sort(newCustomers, by=x->x.tmin)
        if length(pb.custs) < c.id
            resize!(pb.custs, c.id)
            for i = 1:(c.id-length(om.sol.notTaken))
                push!(om.sol.notTaken, true)
            end
        end
        if c.tmaxt >= om.startTime
            pb.custs[c.id] = Customer(c.id,c.orig,c.dest,c.tcall,
            max(c.tmin,om.startTime),c.tmaxt,c.price)
            insertCustomer!(pb,om.sol,c.id)
        end
    end
    for c in sort(virtualCustomers, by=x->x.tmin)
        if length(pb.custs) < c.id
            resize!(pb.custs, c.id)
            for i = 1:(c.id-length(om.sol.notTaken))
                push!(om.sol.notTaken, true)
            end
        end
        if c.tmaxt >= om.startTime
            pb.custs[c.id] = Customer(c.id,c.orig,c.dest,c.tcall,
            max(c.tmin,om.startTime),c.tmaxt,c.price)
            insertCustomer!(pb,om.sol,c.id)
        end
    end
    
    actions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(pb.taxis)]

    for (k,custs) in enumerate(om.sol.custs)
        while !isempty(custs)
            c = custs[1]
            if c.tSup - tt[pb.taxis[k].initPos, pb.custs[c.id].orig] <= endTime

                append!(actions[k].path, getPath(pb, pb.taxis[k].initPos,
                pb.custs[c.id].orig, c.tSup - tt[pb.taxis[k].initPos, pb.custs[c.id].orig]))
                append!(actions[k].path, getPath(pb,pb.custs[c.id].orig,
                pb.custs[c.id].dest, c.tSup + pb.customerTime))

                newTime = c.tSup + 2*pb.customerTime + tt[pb.custs[c.id].orig,
                pb.custs[c.id].dest]
                push!(actions[k].custs, CustomerAssignment(c.id, c.tSup, newTime))
                pb.taxis[k] = Taxi(pb.taxis[k].id, pb.custs[c.id].dest, newTime)
				custs[1].tInf = custs[1].tSup
				for j = 2 :length(custs)
                    custs[j].tInf = max(custs[j].tInf, custs[j-1].tInf + 2*pb.customerTime +
                    tt[pb.custs[custs[j-1].id].orig, pb.custs[custs[j-1].id].dest] +
                    tt[pb.custs[custs[j-1].id].dest, pb.custs[custs[j].id].orig])
                end
                shift!(custs)
            elseif c.tInf - tt[pb.taxis[k].initPos, pb.custs[c.id].orig] < endTime
                c.tInf = endTime + tt[pb.taxis[k].initPos, pb.custs[c.id].orig]
                for j = 2 :length(custs)
                    custs[j].tInf = max(custs[j].tInf, custs[j-1].tInf + 2*pb.customerTime +
                    tt[pb.custs[custs[j-1].id].orig, pb.custs[custs[j-1].id].dest] +
                    tt[pb.custs[custs[j-1].id].dest, pb.custs[custs[j].id].orig])
                end
                break
            else
                break
            end
        end
		if pb.taxis[k].initTime < endTime
			pb.taxis[k] = Taxi(pb.taxis[k].id, pb.taxis[k].initPos, endTime)
		end
    end
    om.startTime = endTime

	return actions
end
