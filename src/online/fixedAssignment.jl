"Insert customer in a taxi timeline, but cannot be modified later"
type FixedAssignment <: OnlineMethod
	pb::TaxiProblem
	sol::IntervalSolution
    startTime::Float64
	earliest::Bool


    period::Float64
	# FixedAssignment() = new()
    function FixedAssignment(;period::Float64=0., earliest::Bool=false)
        offline = new()
		offline.earliest = earliest
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
	om.pb.custs = Customer[]
    om.startTime=0.
    om.sol = IntervalSolution(pb)
end


function onlineUpdate!(om::FixedAssignment, endTime::Float64, newCustomers::Vector{Customer})
    pb = om.pb
    tt = traveltimes(pb)
	#Insert new customers
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
            insertCustomer!(pb,om.sol,c.id, earliest=om.earliest)
        end
    end
    actions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(pb.taxis)]

	#Apply next actions
    for (k,custs) in enumerate(om.sol.custs)
        while !isempty(custs)
            c = custs[1]
            if c.tInf - tt[pb.taxis[k].initPos, pb.custs[c.id].orig] <= endTime

                append!(actions[k].path, getPath(pb, pb.taxis[k].initPos,
                pb.custs[c.id].orig, c.tInf - tt[pb.taxis[k].initPos, pb.custs[c.id].orig]))
                append!(actions[k].path, getPath(pb,pb.custs[c.id].orig,
                pb.custs[c.id].dest, c.tInf + pb.customerTime))

                newTime = c.tInf + 2*pb.customerTime + tt[pb.custs[c.id].orig,
                pb.custs[c.id].dest]
                push!(actions[k].custs, CustomerAssignment(c.id, c.tInf, newTime))
                pb.taxis[k] = Taxi(pb.taxis[k].id, pb.custs[c.id].dest, newTime)
                shift!(custs)

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
