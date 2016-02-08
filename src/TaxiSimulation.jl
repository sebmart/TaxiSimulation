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
# Constants
const PATH = string(Pkg.dir("TaxiSimulation"))
# time epsilon
const EPS = 1e-4

# main
include("taxiproblem/taxiproblem.jl")
include("taxiproblem/randomproblem.jl")


end
