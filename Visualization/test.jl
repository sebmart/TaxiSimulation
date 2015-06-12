cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation");
Pkg.update()
Pkg.add("HDFS")
Pkg.add("LightGraphs")

include("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/definitions.jl");
include("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Cities/squareCity.jl")
include("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Offline/randomDescent.jl");
width, nTime, nTaxis, nCusts = 6, 100, 3, 20
city = SquareCity(width)
generateProblem!(city, nTaxis, nTime, nCusts)
sol = randomDescent(city, 1000)
sol2 = TaxiSolution(city, sol)
printSolution(sol2)

save("testcity.jld", "city", city)
versioninfo()

save("testsol.jld", "sol", sol2)

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Visualization");
city = load("testcity.jld", "city")

sol = load("testsol.jld", "sol")

pwd()

Pkg.add("GraphViz")
Pkg.build("GraphViz")
using GraphViz
function drawNetwork(pb::TaxiProblem, name::String = "graph")
  stdin, proc = open(`neato -Tpdf -o Outputs/$(name).pdf`, "w")
  to_dot(pb,stdin)
  close(stdin)
end

drawNetwork(city, "test")
dotFile(city, "test")

Pkg.build()
