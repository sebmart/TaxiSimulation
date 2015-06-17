cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");
using TaxiSimulation
using HDF5
using JLD
using SFML
using LightGraphs

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src/visualization");
include("visualizerSetup.jl")

width, nTime, nTaxis, nCusts = 10, 100, 10, 40
city = SquareCity(width);
generateProblem!(city, nTaxis, nTime, nCusts)
presol = insertionsDescent(city, 500);
sol = TaxiSolution(city, presol);

visualize(city, sol)
