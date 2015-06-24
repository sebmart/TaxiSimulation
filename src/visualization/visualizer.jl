cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");
using TaxiSimulation
# using HDF5
# using JLD
using SFML
using LightGraphs
using Clustering

width, nTime, nTaxis, nCusts = 6, 200.0, 5, 50
demand = 1.0
# city = SquareCity(width, discreteTime = true)
city = SquareCity(width)
# city = Metropolis(width, width)
generateProblem!(city, nTaxis, nTime, nCusts);
# generateProblem!(city, nTaxis, demand, now(), now() + Dates.Hour(2))
# presol = intervalOpt(city)
presol = localDescent(city,10000,insertionsDescent(city, 10000));
sol = TaxiSolution(city, presol)

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/");
include("src/visualization/visualize.jl");
# include("src/visualization/visualizeClusters.jl");
visualize(city, sol)

man = Manhattan();
# visualize(man, sol)
# visualizeClusters(man, sol, 50)


