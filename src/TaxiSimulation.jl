###################################################
## TaxiSimulation.jl
## Module: usings, exports, includes
###################################################

module TaxiSimulation

using RoutingNetworks, Distributions, JuMP, Gurobi, SFML, IntervalTrees
using Base.Test, Base.Dates, NearestNeighbors, JLD
import MathProgBase
import RoutingNetworks: visualInit, visualEvent, visualStartUpdate, visualEndUpdate, visualScale, visualize

# taxiproblem
export Customer, Taxi, TaxiProblem, CustomerAssignment, TaxiActions, TaxiSolution, Metrics
export printSolution, addRandomCustomers!, addRandomTaxis!, addDistributedTaxis!
export updateTcall, pureOffline, pureOnline, updateTmax, noTmax
# offline
export CustomerTimeWindow, OfflineSolution, BenchmarkPoint, mipSolve, allLinks, kLinks, linkUnion
export usedLinks, orderedInsertions, orderedInsertions!, testSolution, insertionsDescent, randomInsertions, copySolution
export localDescent, localDescent!, smartSearch!, flowSolve, flowLinks, flowKLinks, greedyInsertions
# online
export OnlineAlgorithm, OfflinePlanning, InsertOnly, SearchBudget, LinksOpt, NearestTaxi, onlineSimulation
export partialOfflineSolution
# data
export RealCustomer, loadManhattanCustomers, saveByDate, addDataCustomers!
# visual
export NetworkVisualizer, visualize
# Constants
const PATH = string(Pkg.dir("TaxiSimulation"))
const EPS = 1e-4

# main
include("taxiproblem/taxiproblem.jl")
include("taxiproblem/print.jl")
include("taxiproblem/randomproblem.jl")
include("taxiproblem/tools.jl")
include("taxiproblem/metrics.jl")

#Offline
include("offline/offline.jl")
include("offline/tools.jl")
include("offline/links.jl")
include("offline/mip.jl")
include("offline/partialsolutions.jl")
include("offline/solutionupdates.jl")
include("offline/insertionsheuristics.jl")
include("offline/localheuristics.jl")
include("offline/metrics.jl")
include("offline/flow.jl")
#Online
include("online/online.jl")
include("online/offlineplanning.jl")
include("online/insertonly.jl")
include("online/searchbudget.jl")
include("online/linksopt.jl")
include("online/nearesttaxi.jl")
include("online/tools.jl")
#data
include("realdata/realdata.jl")
include("realdata/nyctaxidata.jl")
include("realdata/dataproblem.jl")
#visualization
include("visualization/taxivisualizer.jl")
end
