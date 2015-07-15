#--------------------------------------------------
#-- All the Taxi Simulation tools in a Module
#--------------------------------------------------

module TaxiSimulation

using HDF5, JLD, LightGraphs, Distributions, JuMP, Gurobi, Base.Collections,
SFML, DataStructures, Base.Dates, DataFrames

#types
export Network, Road, Customer, Taxi, TaxiProblem, CustomerAssignment,
TaxiActions, TaxiSolution, Path, ShortestPaths, RealPaths, AssignedCustomer,
IntervalSolution, Coordinates, OnlineMethod, Uber

#Cities
export Manhattan, Metropolis, SquareCity,
generateCustomers!, generateTaxis!, generateProblem!

#Offline MILP solvers
export fixedTimeOpt, intervalOpt, intervalOptDiscrete, intervalOptContinuous

#Offline heuristics
export orderedInsertions, randomInsertions, insertionsDescent, localDescent

#Tools
export printSolution, shortestPaths!, shortestPaths, realPaths!, realPaths,
testSolution, saveTaxiPb, loadTaxiPb, drawNetwork, dotFile, copySolution,
expandWindows!, dijkstraWithCosts, solutionCost

#Visualization
export visualize

export EPS

path = string(Pkg.dir("TaxiSimulation"))
include("definitions.jl")

#tools
include("tools/print.jl")
include("tools/shortestpath.jl")
include("tools/realpath.jl")
include("tools/tools.jl")

#Solvers
include("offline/randomInsertions.jl")
include("offline/insertionsDescent.jl")
include("offline/localDescent.jl")
include("offline/fixedTimeOpt.jl")
include("offline/intervalOpt.jl")

include("cities/squareCity.jl")
include("cities/metropolis.jl")
include("cities/manhattan.jl")

include("visualization/visualize.jl")

end
