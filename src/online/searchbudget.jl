###################################################
## online/searchbudget.jl
## online algorithm that continuously improve best solution, contrained by time of search
###################################################

"""
	`SearchBudget`, OnlineAlgorithm that continuously improves best solution, constrained by time of search
	- uses an offline solution. Customers that are not rejected yet are either already taken,
	taken in the future or already rejected
"""
type SearchBudget <: OnlineAlgorithm
	#parameters
	"Function that takes an offline solution and improves it in limited time"
	update_solver::Function
	"Function that takes the problem and returns an offline solution"
	precompute_solver::Function
	"percentage of simulation-time dedicated to computations"
	time_budget::Float64
	"recomputation updates frequency (0 = at each step, >0: in seconds of sim-time)"
	update_freq::Float64
	"time allowed to pre-solving (seconds)"
	precompute_time::Float64

	#private
	"Incomplete version of taxi-problem"
	pb::TaxiProblem
	"Solution to offline problem, kept up-to-date"
	sol::OfflineSolution
	"Current time in simulation"
	startTime::Float64
	"Last search sim-time (seconds)"
	lastSearchTime::Float64
	"total search time (seconds)"
	totalSearchTime::Float64

    function SearchBudget(;update_solver::Function = (pb,init,t)->localDescent(pb,init,maxTime=t,random=false,verbose=false),
		 time_budget::Float64=1.,  update_freq::Float64=0., precompute_time::Float64=10.,
		 precompute_solver::Function=(pb,t) -> update_solver(pb, orderedInsertions(pb), t))

		sb = new()

		sb.update_solver = update_solver
		sb.precompute_solver = precompute_solver
		sb.time_budget = time_budget
		sb.update_freq = update_freq
		sb.precompute_time = precompute_time

        return sb
    end
end


function onlineInitialize!(sb::SearchBudget, pb::TaxiProblem)
	pb.taxis = copy(pb.taxis)
    sb.startTime = 0.
	sb.lastSearchTime = 0. # we consider precomputations as a search
	sb.totalSearchTime = 0.

	newCustomers = copy(pb.custs)
	pb.custs = [Customer(i,c.orig,c.dest,c.tcall,c.tmin,c.tmax,c.fare) for (i,c) in enumerate(pb.custs)]
	sb.sol = sb.precompute_solver(pb, sb.precompute_time)

	newIDs = [c.id for c in newCustomers]
	pb.custs = Array{Customer}(maximum([c.id for c in newCustomers]))
	for c in newCustomers
		pb.custs[c.id] = c
    end
	sb.pb = pb
	changeCustIDs!(sb.sol, newIDs)
end

"""
	`changeCustIDs!`, changes ids of customers in an offline solution
"""
function changeCustIDs!(sol::OfflineSolution, newIDs::Vector{Int})
	#update taxis' time windows
	for tws in sol.custs, tw in tws
		tw.id = newIDs[tw.id]
	end
	#update rejected
	rejected = IntSet()
	for c in sol.rejected
		push!(rejected, newIDs[c])
	end
	sol.rejected = rejected
end

function onlineUpdate!(sb::SearchBudget, endTime::Float64, newCustomers::Vector{Customer})
    pb = sb.pb
	tt = getPathTimes(pb.times)

	#Insert new customers
    for c in sort!(newCustomers, by=x->x.tmin)
        if length(pb.custs) < c.id
            resize!(pb.custs, c.id)
        end
        if c.tmax >= sb.startTime
			push!(sb.sol.rejected, c.id)
            pb.custs[c.id] = Customer(c.id,c.orig,c.dest,c.tcall,
            max(c.tmin,sb.startTime),c.tmax,c.fare)
            insertCustomer!(sb.sol,c.id)
        end
    end

	# Local search
	if sb.startTime - sb.lastSearchTime  >= sb.update_freq
		sb.lastSearchTime = sb.startTime
		searchTime = sb.startTime * sb.time_budget - sb.totalSearchTime
		sb.totalSearchTime = sb.startTime * sb.time_budget
		sb.sol = sb.update_solver(pb, sb.sol, searchTime)
	end
    actions = emptyActions(pb)
	# println("===$((sb.startTime, endTime))===")
	# println(newCustomers)
	# println(sb.sol.custs)
	# println(sb.sol.rejected)
	#Apply next actions
    for (k,custs) in enumerate(sb.sol.custs)
        while !isempty(custs)
            c = custs[1]
            if c.tInf - tt[pb.taxis[k].initPos, pb.custs[c.id].orig] <= endTime
				path, times = getPathWithTimes(pb.times, pb.taxis[k].initPos, pb.custs[c.id].orig,
									startTime=c.tInf - tt[pb.taxis[k].initPos, pb.custs[c.id].orig])
				append!(actions[k].path, path[2:end])
				append!(actions[k].times, times)
				path, times = getPathWithTimes(pb.times, pb.custs[c.id].orig, pb.custs[c.id].dest,
								 	startTime=c.tInf + pb.customerTime)
				append!(actions[k].path, path[2:end])
				append!(actions[k].times, times)

                newTime = c.tInf + 2*pb.customerTime + tt[pb.custs[c.id].orig, pb.custs[c.id].dest]
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

	# remove rejected customers of the past
	for c in sb.sol.rejected
		if pb.custs[c].tmax < endTime
			delete!(sb.sol.rejected, c)
		end
	end
	# println(sb.sol.rejected)
	# println([act.custs for act in actions])


    sb.startTime = endTime

	return actions
end
