"iterate offline algorithm, simulating until tHorizon"
type IterativeOffline <: OnlineMethod
	solver::Function
	tHorizon::Float64
	startTime::Float64
	nTime::Float64

	pb::TaxiProblem
	customers::Vector{Customer}
	notTaken::Dict{Int64, Bool}

	period::Float64

	completeMoves::Bool

	warmStart::Bool
	nextAssignedCustomers::Dict{Int64, Tuple{Int64, Float64}}
	function IterativeOffline(period::Float64, tHorizon::Float64, solver::Function=mipOpt; completeMoves::Bool=false, warmStart::Bool = false)
		offline = new()
		offline.tHorizon = tHorizon
		offline.solver = solver
		offline.period = period
		offline.completeMoves = completeMoves
		offline.warmStart = warmStart
		return offline
	end
end

"""
Initializes a given OnlineMethod with a selected taxi problem without customers
"""
function onlineInitialize!(om::IterativeOffline, pb::TaxiProblem)
	om.pb = pb
	om.nTime = pb.nTime
	om.pb.taxis = copy(om.pb.taxis)
	om.pb.custs = Customer[]
	om.customers = Customer[]
	om.notTaken = Dict{Int64, Bool}()
	om.nextAssignedCustomers = Dict{Int64, Tuple{Int64, Float64}}()
	om.startTime = 0.0
end

"""
Updates OnlineMethod to account for new customers, returns a list of TaxiActions
since the last update. Needs initial information to start from.
"""
function onlineUpdate!(om::IterativeOffline, endTime::Float64, newCustomers::Vector{Customer})
	# Sets the time window for the offline solver
	tt = TaxiSimulation.traveltimes(om.pb)
	startOffline = om.startTime
	finishOffline = min(om.nTime,max(startOffline + om.tHorizon, endTime))

	# Adds the new customers to the problem's customers
	for c in newCustomers
		om.notTaken[c.id] = true
	end
	append!(om.customers, newCustomers)

	if om.warmStart
		warmStartAssignedCustomers = [AssignedCustomer[] for i in 1:length(om.pb.taxis)]
		warmStartNotTakenIndices = Int64[]
	end
	# Identifies current customers with pickup window within the time window
	currentCustomers = Customer[]
	IDtoIndex = Int64[]
	for customer in om.customers
		if om.notTaken[customer.id]
			if customer.tmin < startOffline
				if customer.tmaxt >= startOffline
					tmaxt = min(customer.tmaxt, finishOffline) - startOffline
					push!(IDtoIndex, customer.id)
					newCust = Customer(length(IDtoIndex), customer.orig, customer.dest, 0., 0., tmaxt, customer.price)
					push!(currentCustomers, newCust)
					if om.warmStart
						if customer.id in keys(om.nextAssignedCustomers)
							info = om.nextAssignedCustomers[customer.id]
							newAssignedCustomer = AssignedCustomer(length(IDtoIndex), info[2], info[2])
							push!(warmStartAssignedCustomers[info[1]], newAssignedCustomer)
						else
							push!(warmStartNotTakenIndices, length(IDtoIndex))
						end
					end
				end
			elseif customer.tmin <= finishOffline
			 	tmaxt = min(customer.tmaxt, finishOffline) - startOffline
			 	push!(IDtoIndex, customer.id)
				newCust = Customer(length(IDtoIndex), customer.orig, customer.dest, 0., customer.tmin - startOffline, tmaxt, customer.price)
				push!(currentCustomers, newCust)
				if om.warmStart
					if customer.id in keys(om.nextAssignedCustomers)
						info = om.nextAssignedCustomers[customer.id]
						newAssignedCustomer = AssignedCustomer(length(IDtoIndex), info[2], info[2])
						push!(warmStartAssignedCustomers[info[1]], newAssignedCustomer)
					else
						push!(warmStartNotTakenIndices, length(IDtoIndex))
					end
				end
			end
		end
	end

	# Sets the problem's customers to those identified within the time window, and solves
	om.pb.custs = currentCustomers
	om.pb.nTime = finishOffline - startOffline + EPS

	if om.warmStart
		for list in warmStartAssignedCustomers
			sort!(list, by = c->c.tInf)
		end
		notTaken = falses(length(currentCustomers))
		for customerNotTakenIndex in warmStartNotTakenIndices
			notTaken[customerNotTakenIndex] = true
		end
		warmStartSol = IntervalSolution(warmStartAssignedCustomers, notTaken, 0.)
		expandWindows!(copy(om.pb), warmStartSol)
		testSolution(om.pb, warmStartSol)
		offlineSolution = om.solver(om.pb, warmStartSol)
	else
		offlineSolution = om.solver(om.pb)
	end

	onlineTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(om.pb.taxis)]
	nextUpdateAssignedCustomers = Dict{Int64, Tuple{Int64, Float64}}()

	# Keeps track of starting taxi paths
	hasPath = falses(length(om.pb.taxis))

	idleTaxiCount = 0

	# Processes offline solution to fit it to online simulation
	for (i, assignments) in enumerate(offlineSolution.custs)
		# Selects for customers who are picked up before the start of the next time window
		startPos = om.pb.taxis[i].initPos
		halfPath = false
		if isempty(assignments)
			idleTaxiCount += 1
		end

		for (j, customer) in enumerate(assignments)
			c = om.pb.custs[customer.id]
			if customer.tInf - tt[startPos,c.orig] + startOffline > endTime
				if om.warmStart
					nextUpdateAssignedCustomers[IDtoIndex[customer.id]] = (i, customer.tSup + startOffline - endTime)
				else
					break
				end
			elseif !om.completeMoves && customer.tInf + startOffline > endTime
				if om.warmStart
					nextUpdateAssignedCustomers[IDtoIndex[customer.id]] = (i, customer.tSup + startOffline - endTime)
					if halfPath
						continue
					end
				elseif halfPath
					break
				end
				path = getPath(om.pb, startPos, c.orig, customer.tInf + startOffline - tt[startPos, c.orig])
				for (t,r) in path
					if t < endTime
						push!(onlineTaxiActions[i].path, (t,r))
						halfPath = true
					else
						break
					end
				end
			else
				om.notTaken[IDtoIndex[customer.id]] = false
				timeOut = customer.tInf + startOffline + 2 * om.pb.customerTime + tt[c.orig, c.dest]
				assignment = CustomerAssignment(IDtoIndex[customer.id], customer.tInf + startOffline, timeOut)
				push!(onlineTaxiActions[i].custs, assignment)
				append!(onlineTaxiActions[i].path, getPath(om.pb, startPos, c.orig, assignment.timeIn - tt[startPos, c.orig]))
				append!(onlineTaxiActions[i].path, getPath(om.pb, c.orig, c.dest, assignment.timeIn + om.pb.customerTime))
				startPos = c.dest
			end
		end

		# Updates the initial taxi locations and paths for the next time window
		if halfPath && !isempty(onlineTaxiActions[i].path)
			(t, road) = onlineTaxiActions[i].path[end]
			newt = max(t + om.pb.roadTime[src(road), dst(road)] - endTime, 0.0)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, dst(road), newt)
		elseif !isempty(onlineTaxiActions[i].custs)
			(t, road) = onlineTaxiActions[i].path[end]
			newt = max(onlineTaxiActions[i].custs[end].timeOut - endTime, 0.0)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, dst(road), newt)
		else
			newt = max(om.pb.taxis[i].initTime - endTime + startOffline, 0.0)
			om.pb.taxis[i] = Taxi(om.pb.taxis[i].id, om.pb.taxis[i].initPos, newt)
		end
	end

	# Updates the start time for the next time window
	om.startTime = endTime
	om.nextAssignedCustomers = nextUpdateAssignedCustomers

	# Returns new TaxiActions to OnlineSimulation
	return onlineTaxiActions
end
