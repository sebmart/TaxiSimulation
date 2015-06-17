cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");

using TaxiSimulation

width, nTime, nTaxis, nCusts = 8, 100, 10, 40
city = SquareCity(width)
generateProblem!(city, nTaxis, nTime, nCusts)

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src/offline")
sol = insertionsDescent(city, 1000)
sol2 = TaxiSolution(city, sol)

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation")
include("src/visualization/setup.jl")
visualize(city, sol2)

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src/visualization/tests");
save("testcity.jld", "city", city)
save("testsol.jld", "sol", sol2)

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src/visualization/tests");
city = load("testcity.jld", "city")
sol = load("testsol.jld", "sol")

# using GraphViz
# function drawNetwork(pb::TaxiProblem, name::String = "graph")
#   stdin, proc = open(`neato -Tpdf -o Outputs/$(name).pdf`, "w")
#   to_dot(pb,stdin)
#   close(stdin)
# end

# drawNetwork(city, "test")

using HDF5
using JLD
using SFML