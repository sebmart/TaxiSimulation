###################################################
## TaxiSimulation.jl
## Module: usings, exports, includes
###################################################

module TaxiSimulation

using RoutingNetworks, Distributions, JuMP, Gurobi, SFML, IntervalTrees
using Base.Test, Base.Dates, NearestNeighbors, JLD
import MathProgBase
import RoutingNetworks: visualInit, visualEvent, visualUpdate, visualScale, visualize

# taxiproblem
export Customer, Taxi, TaxiProblem, CustomerAssignment, TaxiActions, TaxiSolution
export printSolution, addRandomCustomers!, addRandomTaxis!, addDistributedTaxis!
export updateTcall, pureOffline, pureOnline, updateTmax, noTmax
# offline
export CustomerTimeWindow, OfflineSolution, BenchmarkPoint, mipOpt, orderedInsertions
export testSolution, insertionsDescent, randomInsertions, copySolution, localDescent
# online
export OnlineAlgorithm, onlineSimulation
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
#Offline
include("offline/offline.jl")
include("offline/timewindows.jl")
include("offline/mip.jl")
include("offline/partialsolutions.jl")
include("offline/solutionupdates.jl")
include("offline/insertionsheuristics.jl")
include("offline/localdescent.jl")
#Online
include("online/online.jl")
#data
include("realdata/realdata.jl")
include("realdata/nyctaxidata.jl")
include("realdata/dataproblem.jl")
#visualization
include("visualization/taxivisualizer.jl")
end
