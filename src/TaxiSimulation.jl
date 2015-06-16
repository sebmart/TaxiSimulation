#--------------------------------------------------
#-- All the Taxi Simulation tools in a Module
#--------------------------------------------------

module TaxiSimulation

using HDF5
using JLD
using LightGraphs
using Dates
using Distributions
using JuMP
using Gurobi
using Base.Collections

#types
export Network, Road, Customer, Taxi, TaxiProblem, CustomerAssignment
export TaxiActions, TaxiSolution, ShortPaths, AssignedCustomer, IntervalSolution

#Cities
export Manhattan, Metropolis, SquareCity
export generateCustomers!, generateTaxis!, generateProblem!

#Offline MILP solvers
export fullOpt, simpleOpt, intervalBinOpt

#Offline heuristics
export localOpt, offlineAssignment, offlineAssignmentQuick, randomAssignment

#Tools
export printSolution, shortestPaths!, shortestPaths
export fixSolution!, saveTaxiPb, loadTaxiPb, drawNetwork, dotFile
export copySolution



include("definitions.jl")

#tools
include("tools/print.jl")
include("tools/shortestpath.jl")
include("tools/tools.jl")

#Solvers
include("offline/offlineAssignment.jl")
include("offline/randomDescent.jl")
include("offline/localOpt.jl")
include("offline/intervalBinOpt.jl")
include("offline/fullOpt.jl")
include("offline/simpleOpt.jl")

include("cities/squareCity.jl")
include("cities/metropolis.jl")
include("cities/manhattan.jl")

end
