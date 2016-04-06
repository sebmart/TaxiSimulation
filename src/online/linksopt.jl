###################################################
## online/linksopt.jl
## online algorithm that keeps a set of links, on which it solves to optimality
###################################################

"""
	`LinksOpt`, OnlinePlanning that keeps a set of links, on which it solves to optimality
"""
type LinksOpt <: OfflinePlanning
	pb::TaxiProblem
	sol::OfflineSolution
	currentCusts::IntSet

	#parameters
    "minimum K"
    k::Int
    "seconds between each recomputation"
    improveFreq::Float64

	# private
	"Current time in simulation"
	startTime::Float64
	"Last search sim-time (seconds)"
	lastSearchTime::Float64
    "current set of customer links"
    links::CustomerLinks

    function LinksOpt(;k::Int=1, improve_freq::Real=30.)
		lo = new()
        lo.improveFreq = improve_freq
        lo.k = k
        return lo
    end
end

function initialPlanning!(lo::LinksOpt)
    lo.startTime = 0.
	lo.lastSearchTime = 0. # we consider precomputations as a search
    lo.sol = orderedInsertions!(partialOfflineSolution(lo.pb, lo.currentCusts))
    lo.links = baseLinks(lo)
    for i in 1:5
        linkUnion!(lo.links, usedLinks(lo.sol))
        lo.sol =  mipSolve(lo.pb, lo.sol, lo.links, verbose=true, MIPGap=1e-6)
        localDescent!(lo.pb, lo.sol, maxTime=10., maxSearch=5, verbose=true)
    end
end


function updatePlanning!(lo::LinksOpt, endTime::Float64, newCustomers::Vector{Int})
	#Insert new customers
    for c in newCustomers
        insertCustomer!(lo.sol,c)
    end

	# improve!
	if lo.startTime - lo.lastSearchTime  >= lo.improveFreq
		lo.lastSearchTime = lo.startTime
        removeCusts!(lo.links, setdiff(IntSet(keys(lo.links.prv)), lo.currentCusts))
        removeInfeasible!(lo.links, lo.pb)
        linkUnion!(lo.links, baseLinks(lo))
        linkUnion!(lo.links, usedLinks(lo.sol))
        println(lo.links)
        lo.sol = mipSolve(lo.pb, lo.sol, lo.links, verbose=true, MIPGap=1e-6)
        improveSolution!(lo)
        lo.sol = mipSolve(lo.pb, lo.sol, lo.links, verbose=true, MIPGap=1e-6)
	end

    lo.startTime = endTime
end

"""
    `improveSolution!`, find better solution and creates new links
"""
function improveSolution!(lo::LinksOpt)
    for i = 1:10
        localDescent!(lo.pb, lo.sol, maxTime=5., maxSearch=3, verbose=true)
        linkUnion!(lo.links, usedLinks(lo.sol))
    end
end

"""
    `baseLinks`, minimum set of links to consider
"""
function baseLinks(lo::LinksOpt)
    return kLinks(lo.pb, lo.k, lo.currentCusts)
end
