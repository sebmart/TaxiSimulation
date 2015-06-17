cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");
using TaxiSimulation
using HDF5
using JLD
using SFML
using LightGraphs

# Loads the neccessary functions and scripts to create the visualization
cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src/visualization");
include("visualizerSetup.jl")

# Modify following variables to create city of your choosing
width, nTime, nTaxis, nCusts = 10, 100, 10, 40
city = SquareCity(width);
generateProblem!(city, nTaxis, nTime, nCusts)

# Generates solution to the above problem
presol = insertionsDescent(city, 500);
sol = TaxiSolution(city, presol);

# Creates a visualization of the taxi problem and solution
visualize(city, sol)
