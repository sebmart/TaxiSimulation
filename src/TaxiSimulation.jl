#--------------------------------------------------
#-- All the Taxi Simulation tools in a Module
#--------------------------------------------------

module TaxiSimulation

using RoutingNetworks, Distributions
# using JLD, LightGraphs, JuMP, Gurobi, Base.Collections,
# SFML, DataStructures, Base.Dates, DataFrames, Base.Test, MathProgBase


# taxiproblem
export Customer, Taxi, TaxiProblem, CustomerAssignment, TaxiActions, TaxiSolution
export addRandomCustomers!, addRandomTaxis!

#offline
export CustomerTimeWindow, OfflineSolution, BenchmarkPoint
# Constants
const PATH = string(Pkg.dir("TaxiSimulation"))
const EPS = 1e-4

# main
include("taxiproblem/taxiproblem.jl")
include("taxiproblem/randomproblem.jl")
#Offline
include("offline/offline.jl")
include("offline/timewindows.jl")


end
