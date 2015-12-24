"""
	Insert customer in a taxi timeline
	Periodically tries to reoptimize using local search
"""
type LimitedSearch <: OnlineMethod
	pb::TaxiProblem
	sol::IntervalSolution
    startTime::Float64
	solver::Function
	timePerTs::Float64
	updateFreq::Float64
	lastSearch::Float64
	custId::Vector{Int}
	validCust::Vector{Bool}
	earliest::Bool

    period::Float64
	# FixedAssignment() = new()
    function LimitedSearch(;
		period::Float64=0.,
		solver::Function=(pb,init,t)->localDescent(pb,init,maxTime=t,random=true,verbose=false),
		timePerTs::Float64=1.,   #In seconds
		updateFreq::Float64=0.,  #In timesteps (often minutes)
		earliest::Bool=false
	)
        offline = new()
        offline.period = period
        offline.solver = solver
		offline.timePerTs = timePerTs
        offline.updateFreq = updateFreq
		offline.earliest = earliest
        return offline
    end
end

"""
Initializes a given FixedAssignment with a selected taxi problem without customers
"""
function onlineInitialize!(om::LimitedSearch, pb::TaxiProblem)
	pb.taxis = copy(pb.taxis)
    om.pb = pb
	om.pb.custs = Customer[]
    om.startTime=0.
	om.lastSearch= -Inf
    om.sol = IntervalSolution(pb)
	om.custId = Int[]
	om.validCust = Bool[]
end


function onlineUpdate!(om::LimitedSearch, endTime::Float64, newCustomers::Vector{Customer})
    pb = om.pb
    tt = traveltimes(pb)
	#Insert new customers
    for c in sort(newCustomers, by=x->x.tmin)

		push!(pb.custs,  Customer(length(pb.custs)+1,c.orig,c.dest,c.tcall,
		max(c.tmin,om.startTime),c.tmaxt,c.price))
		push!(om.sol.notTaken, true)
		push!(om.validCust, true)
		push!(om.custId, c.id)

        if c.tmaxt >= om.startTime
            insertCustomer!(pb,om.sol,length(pb.custs),earliest=om.earliest)
		else
			error("WTF")
		end
    end

	#If we have time to optimize
	if om.startTime - om.lastSearch  >= om.updateFreq
		#refactor the problem (remove non valid customers and update IDs)
		for c in pb.custs
			if c.tmaxt < om.startTime
				om.validCust[c.id] = false
			end
		end
		indexChange = zeros(Int,length(pb.custs))
		pb.custs = pb.custs[om.validCust]
		om.sol.notTaken = om.sol.notTaken[om.validCust]
		custId = zeros(Int,length(pb.custs))
		for (i,c) in enumerate(pb.custs)
			indexChange[c.id] = i
			pb.custs[i] = Customer(i,c.orig,c.dest,c.tcall,c.tmin,c.tmaxt,c.price)
			custId[i] = om.custId[c.id]
		end
		om.custId = custId
		for custs in om.sol.custs
			for c in custs
				c.id = indexChange[c.id]
			end
		end
		om.validCust = trues(length(pb.custs))
		expandWindows!(pb,om.sol)
		om.sol = om.solver(pb, om.sol, (om.startTime - om.lastSearch) * om.timePerTs)
		om.lastSearch = om.startTime
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
                push!(actions[k].custs, CustomerAssignment(om.custId[c.id], c.tInf, newTime))
                pb.taxis[k] = Taxi(pb.taxis[k].id, pb.custs[c.id].dest, newTime)
				om.validCust[c.id] = false
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
