#--------------------------------------------------
#-- All the Taxi Simulation tools in a Module
#--------------------------------------------------

module TaxiSimulation

using RoutingNetworks
# JuMP, Gurobi, Base.Test,
# using JLD, LightGraphs, Distributions, JuMP, Gurobi, Base.Collections,
# SFML, DataStructures, Base.Dates, DataFrames, Base.Test, MathProgBase


# main
export Customer, Taxi, TaxiProblem, CustomerAssignment, TaxiActions, TaxiSolution

# Constants
const PATH = string(Pkg.dir("TaxiSimulation"))
# time epsilon
const EPS = 1e-4

# main
include("taxiproblem.jl")


end
