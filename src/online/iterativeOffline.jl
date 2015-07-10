type IterativeOffline <: OnlineMethod
	solver::Function
	tHorizon::Float64
	endTime::Float64
	
	pb::TaxiProblem
	# currentSolution::TaxiSolution
	# currentCustomers::Vector{Customer}
	# currentTaxis::Vector{Taxi}
	# endTime::Float64
	# taxiActions::Vector{TaxiActions}
	# solution::IntervalSolution

	function IterativeOffline(solver::Function, tHorizon::Float64)
		offline = new()
		offline.solver =  solver
		offline.tHorizon = tHorizon
		return offline
	end
end

# Should store endtime as well
# Change to initialize with no customers at all

# Initializes a given OnlineMethod with a selected taxi problem without customers
function initialize!(om::OnlineMethod, pb::TaxiProblem, p::Float64)
	reducedPb = copy(pb)
	reducedPb.custs = Vector{Customer}
	om.pb = reducedPb
	om.period = p
end
"""
Updates OnlineMethod to account for new customers, returns a list of TaxiActions 
since the last update. Needs initial information to start from. 
"""
# remove/ignore customers that are after THorizon?
function update!(om::OnlineMethod, step::Int64, newCustomers::Vector{Customer})
	append!(om.pb.custs, newCustomers)	
	
	# Make sure customers are picked up before THorizon

	offlineSolution = TaxiSolution(om.pb, om.solver(om.pb, 100))

	# Not taken customers should be carried over, modifying tmaxt or tmin as necessary

	# Map Customer IDs to current indices in om.pb.custs as ID != index here
	IDtoIndex = Dict{Int64, Int64}
	for i = 1:length(newCustomers)
		IDtoIndex[newCustomers[i].id] = i
	end

	for (k, TaxiAction) in enumerate(offlineSolution.taxis)
		if TaxiAction.path[1][1] > step * om.period
			TaxiAction.path = Vector{Tuple{Float64, Road}}
			for assignment in TaxiAction.custs
				# Fix indexing with created dictionary
				offline.notTaken[IDtoIndex[assignment.id]] = true
			end
			TaxiAction.custs = Vector{CustomerAssignment}
		end
		om.pb.Taxis[k].initPos = om.pb.custs[TaxiAction.custs[end].id].dest
		if TaxiAction.custs[end].timeOut <= step * period
			om.pb.Taxis[k].initTime = 0
		else
			om.pb.Taxis[k].initTime = TaxiAction.custs[end].timeOut - om.period
		end
	end
	
	# Check for tmin, tmaxt for each customer. No reason to add customer to next horizon
	# if they're no longer able to be picked up
	remainingCusts = Vector{Customer}
	for i = 1:length(offlineSolution.notTaken)
		if offlineSolution.notTaken[i]
			# Filter out desired customers that fit the time bill
			push!(remainingCusts, om.pb.custs[i])
		end
	end

	om.pb.custs = remainingCusts

	for TaxiAction in offlineSolution.taxis
		for path in TaxiAction.path
			path[1] += (step - 1) * om.period
		end
		for assignment in TaxiAction.custs
			assignment.timeIn += (step - 1) * om.period
			assignment.timeOut += (step - 1) * om.period
		end
	end

	return offlineSolution.taxis
end

onlineSimulation(pb, IterativeOffline(localDescent, 30))

function localDescent(pb::TaxiProblem, maxTry::Int, start::IntervalSolution = orderedInsertions(pb))
    nTaxis = length(pb.taxis)
    println("Start, $(-start.cost) dollars")
    sol =  copySolution(start)
    best = sol.cost
    for trys in 1:maxTry
        k = rand(1:nTaxis)
        k2 = rand( 1 :(nTaxis-1))
        k2 =  k2 >= k ? k2+1 : k2
        if isempty(sol.custs[k])
            continue
        end
        i = rand(1:length(sol.custs[k]))
        sol = splitAndMove!(pb, sol, k, i, k2)
        if sol.cost < best
            print("\r====Try: $(trys), $(-sol.cost) dollars                  ")
            best = sol.cost
        end
    end
    expandWindows!(pb, sol)
    print("\r====Final: $(-sol.cost) dollars              \n")
    return sol
end
