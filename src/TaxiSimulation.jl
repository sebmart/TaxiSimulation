#--------------------------------------------------
#-- All the Taxi Simulation tools in a Module
#--------------------------------------------------

module TaxiSimulation

using RoutingNetworks, Distributions, JuMP, Gurobi, SFML
import MathProgBase
import RoutingNetworks: visualInit, visualEvent, visualUpdate, visualize
# using JLD, LightGraphs, Base.Collections,
# DataStructures, Base.Dates, DataFrames, Base.Test


# taxiproblem
export Customer, Taxi, TaxiProblem, CustomerAssignment, TaxiActions, TaxiSolution
export addRandomCustomers!, addRandomTaxis!

#offline
export CustomerTimeWindow, OfflineSolution, BenchmarkPoint, mipOpt
# Constants
const PATH = string(Pkg.dir("TaxiSimulation"))
const EPS = 1e-4

# main
include("taxiproblem/taxiproblem.jl")
include("taxiproblem/randomproblem.jl")
#Offline
include("offline/offline.jl")
include("offline/timewindows.jl")
include("offline/mip.jl")


end
