cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");

cd("/taxi-simulation/src");
using TaxiSimulation
using HDF5
using JLD
using SFML
using LightGraphs

width, nTime, nTaxis, nCusts = 20, 200, 20, 40
city = SquareCity(width);
generateProblem!(city, nTaxis, nTime, nCusts);
presol = insertionsDescent(city, 500);
sol = TaxiSolution(city, presol);

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/");
include("src/visualization/visualize.jl");
visualize(city, sol)
