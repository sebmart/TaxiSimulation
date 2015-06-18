cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");
using TaxiSimulation
using HDF5
using JLD
using SFML
using LightGraphs

width, nTime, nTaxis, nCusts = 20, 200, 20, 80
city = SquareCity(width);
generateProblem!(city, nTaxis, nTime, nCusts)
presol = insertionsDescent(city, 500);
sol = TaxiSolution(city, presol);

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src/visualization");
include("visualizerSetup.jl")
cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");

visualize(city, sol, false)

