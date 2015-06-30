#--------------------------------------------------
#-- All the Taxi Simulation tools in a Module
#--------------------------------------------------

module TaxiSimulation

using HDF5, JLD, LightGraphs, Distributions, JuMP, Gurobi, Base.Collections,
      SFML, DataStructures, Base.Dates

#types
export Network, Road, Customer, Taxi, TaxiProblem, CustomerAssignment,
       TaxiActions, TaxiSolution, ShortPaths, AssignedCustomer, IntervalSolution,
       Coordinates

#Cities
export Manhattan, Metropolis, SquareCity,
       generateCustomers!, generateTaxis!, generateProblem!

#Offline MILP solvers
export fullOpt, fixedTimeOpt, intervalOpt, intervalOptDiscrete, intervalOptContinuous

#Offline heuristics
export orderedInsertions, randomInsertions, insertionsDescent, localDescent

#Tools
export printSolution, shortestPaths!, shortestPaths, testSolution, saveTaxiPb,
       loadTaxiPb, drawNetwork, dotFile, copySolution, expandWindows!,
       custom_dijkstra

#Visualization
export visualize

path = string(Pkg.dir("TaxiSimulation"))
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
include("offline/fixedTimeOpt.jl")
include("offline/intervalOpt.jl")

include("cities/squareCity.jl")
include("cities/metropolis.jl")
include("cities/manhattan.jl")

include("visualization/visualize.jl")

end
