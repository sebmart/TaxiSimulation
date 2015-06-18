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
export Network, Road, Customer, Taxi, TaxiProblem, CustomerAssignment,
       TaxiActions, TaxiSolution, ShortPaths, AssignedCustomer, IntervalSolution,
       Coordinates

#Cities
export Manhattan, Metropolis, SquareCity,
       generateCustomers!, generateTaxis!, generateProblem!

#Offline MILP solvers
export fullOpt, fixedTimeOpt, intervalOpt

#Offline heuristics
export orderedInsertions, randomInsertions, insertionsDescent, localDescent

#Tools
export printSolution, shortestPaths!, shortestPaths, testSolution, saveTaxiPb,
       loadTaxiPb, drawNetwork, dotFile, copySolution, expandWindows!



include("definitions.jl")

#tools
include("tools/print.jl")
include("tools/shortestpath.jl")
include("tools/tools.jl")

#Solvers
include("offline/randomInsertions.jl")
include("offline/insertionsDescent.jl")
include("offline/localDescent.jl")
include("offline/fullOpt.jl")
# include("offline/fixedTimeOpt.jl")
include("offline/intervalOpt.jl")

include("cities/squareCity.jl")
include("cities/metropolis.jl")
include("cities/manhattan.jl")

end
