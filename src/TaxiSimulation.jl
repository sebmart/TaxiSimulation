###################################################
## TaxiSimulation.jl
## Module: usings, exports, includes
###################################################

module TaxiSimulation

using RoutingNetworks, Distributions, JuMP, Gurobi, SFML, IntervalTrees, Base.Test
import MathProgBase
import RoutingNetworks: visualInit, visualEvent, visualUpdate, visualScale, visualize
# using JLD, LightGraphs, Base.Collections,
# DataStructures, Base.Dates, DataFrames, Base.Test


# taxiproblem
export Customer, Taxi, TaxiProblem, CustomerAssignment, TaxiActions, TaxiSolution
export printSolution, addRandomCustomers!, addRandomTaxis!
# offline
export CustomerTimeWindow, OfflineSolution, BenchmarkPoint, mipOpt, orderedInsertions,
testSolution, insertionsDescent, randomInsertions, copySolution, localDescent
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
#visualization
include("visualization/taxivisualizer.jl")
end
