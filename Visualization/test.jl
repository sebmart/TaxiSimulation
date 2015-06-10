cd("/Users/bzeng/Dropbox (MIT)/7 Coding/UROP/taxi-simulation");
Pkg.update()
Pkg.add("HDFS")
Pkg.add("LightGraphs")
include("definitions.jl");
include("Cities/squareCity.jl")
include("Offline/randomDescent.jl");
width, nTime, nTaxis, nCusts = 3, 20, 1, 2
city = SquareCity(width)
generateProblem(city, nTaxis, nTime, nCusts)
sol = randomDescent(city, 1000)
sol2 = TaxiSolution(city, sol)
printSolution(sol2)
