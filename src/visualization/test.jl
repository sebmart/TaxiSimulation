cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");

using TaxiSimulation

width, nTime, nTaxis, nCusts = 8, 100, 10, 40
city = SquareCity(width)
generateProblem!(city, nTaxis, nTime, nCusts)

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src/offline")
sol2 = insertionsDescent(city, 1000)
sol = TaxiSolution(city, sol2)

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


# Output the graph vizualization to pdf file (see GraphViz library)
function drawNetwork(pb::TaxiProblem, name::String = "graph")
  stdin, proc = open(`neato -Tplain -o Outputs/$(name).txt`, "w")
  to_dot(pb,stdin)
  close(stdin)
end

# Write the graph in dot format
function to_dot(pb::TaxiProblem, stream::IO)
    write(stream, "digraph  citygraph {\n")
    for i in vertices(pb.network), j in out_neighbors(pb.network,i)
      write(stream, "$i -> $j\n")
    end
    write(stream, "}\n")
    return stream
end