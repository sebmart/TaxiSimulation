###################################################
## online/searchbudget.jl
## online algorithm that continuously improve best solution, contrained by time of search
###################################################

"""
	`SearchBudget`, OnlinePlanning that continuously improves best solution, constrained by time of search
	- uses an offline solution. Customers that are not rejected yet are either already taken,
	taken in the future or already rejected
"""
mutable struct SearchBudget <: OfflinePlanning
	pb::TaxiProblem
	sol::OfflineSolution
	currentCusts::DataStructures.IntSet
	#parameters
	"Function that takes an offline solution and improves it in limited time"
	update_solver::Function
	"Function that takes the problem and returns an offline solution"
	precompute_solver::Function

	"percentage of simulation-time dedicated to computations"
	time_budget::Float64
	"recomputation updates frequency (0 = at each step, >0: in seconds of sim-time)"
	update_freq::Float64

	# private
	"Current time in simulation"
	startTime::Float64
	"Last search sim-time (seconds)"
	lastSearchTime::Float64
	"total search time (seconds)"
	totalSearchTime::Float64

    function SearchBudget(;update_solver::Function=(pb, init, custs, t)->localDescent(pb,init,maxTime=t, maxSearch = 1,verbose=false),
							time_budget::Float64=1.,  
							update_freq::Float64=0.,
							precompute_solver::Function=(pb,custs)->localDescent(	pb, 
																					orderedInsertions!(partialOfflineSolution(pb, custs)),
																					maxSearch = 1,
																					verbose=false)
							)

		sb = new()

		sb.update_solver = update_solver
		sb.precompute_solver = precompute_solver
		sb.time_budget = time_budget
		sb.update_freq = update_freq
        return sb
    end
end

function initialPlanning!(sb::SearchBudget)
    sb.startTime = 0.
	sb.lastSearchTime = 0. # we consider precomputations as a search
	sb.totalSearchTime = 0.
	# Welp you forgot the time budget thingy
	sb.sol = sb.precompute_solver(sb.pb, sb.currentCusts)
end


function updatePlanning!(sb::SearchBudget, endTime::Float64, newCustomers::Vector{Int})
	#Insert new customers
    for c in newCustomers
        insertCustomer!(sb.sol,c)
    end

	# Local search
	if sb.startTime - sb.lastSearchTime  >= sb.update_freq
		sb.lastSearchTime = sb.startTime
		searchTime = sb.startTime * sb.time_budget - sb.totalSearchTime
		sb.totalSearchTime = sb.startTime * sb.time_budget
		sb.sol = sb.update_solver(sb.pb, sb.sol, sb.currentCusts, searchTime)
	end

    sb.startTime = endTime
end
