#--------------------------------------------------
#-- All the Taxi Simulation tools in a Module
#--------------------------------------------------

module TaxiSimulation

using JLD, LightGraphs, Distributions, JuMP, Gurobi, Base.Collections,
SFML, DataStructures, Base.Dates, DataFrames, Base.Test


#types
export Network, Road, Customer, Taxi, TaxiProblem, CustomerAssignment,
TaxiActions, TaxiSolution, Path, ShortestPaths, RealPaths, AssignedCustomer,
IntervalSolution, Coordinates, OnlineMethod, IterativeOffline, FixedAssignment, 
Uber

#Cities
export Manhattan, Metropolis, SquareCity,
generateCustomers!, generateTaxis!, generateProblem!

#Offline MILP solvers
export fixedTimeOpt, intervalOpt, intervalOptDiscrete, intervalOptContinuous

#Offline heuristics
export orderedInsertions, randomInsertions, insertionsDescent, localDescent

#Online
export onlineSimulation

#Tools
export printSolution, shortestPaths!, shortestPaths, realPaths!, realPaths,
testSolution, saveTaxiPb, loadTaxiPb, drawNetwork, dotFile, copySolution,
expandWindows!, dijkstraWithCosts, solutionCost

#Visualization
export visualize

path = string(Pkg.dir("TaxiSimulation"))
include("definitions.jl")

#tools
include("tools/print.jl")
include("tools/shortestpath.jl")
include("tools/realpath.jl")
include("tools/tools.jl")

#cities
include("cities/squareCity.jl")
include("cities/metropolis.jl")
include("cities/manhattan.jl")

#offline
include("offline/moveCustomer.jl")
include("offline/randomInsertions.jl")
include("offline/insertionsDescent.jl")
include("offline/localDescent.jl")
include("offline/fixedTimeOpt.jl")
include("offline/intervalOpt.jl")

#online
include("online/onlineSimulation.jl")
include("online/iterativeOffline.jl")
include("online/fixedAssignment.jl")
include("online/uber.jl")

#visualization
include("visualization/visualize.jl")

end
