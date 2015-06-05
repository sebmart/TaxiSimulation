cd("/Users/Sebastien/Documents/Dropbox (MIT)/Research/Taxi/JuliaSimulation");
include("definitions.jl");
include("Cities/squareCity.jl");
include("Cities/metropolis.jl");
include("Offline/randomAssignment.jl");
include("Offline/randomDescent.jl");
include("Offline/simpleOpt.jl");
include("Offline/fullOpt.jl");
include("Offline/intervalOpt.jl");
include("Offline/intervalBinOpt.jl");

width, nTime, nTaxis, nCusts = 3, 20, 1, 2;

city = SquareCity(width);

generateProblem!(city, nTaxis, nTime, nCusts);
@time sol = fullOpt(city);
printSolution(sol)


width, nTime, nTaxis, nCusts = 5, 50, 2, 10;


#Create the network
city = SquareCity(width);

#Populate the network
generateProblem!(city, nTaxis, nTime, nCusts);


@time sol = simpleOpt(city);
@time sol = intervalBinOpt(city);

printSolution(citysol,verbose=0)
printSolution(citysol,verbose=1)
printSolution(citysol,verbose=2)
@time sol = randomAssignment(city, 100)
printSolution(sol,verbose=0)
printSolution(sol,verbose=1)
printSolution(sol,verbose=2)

@time printSolution(randomDescent(city, 1000), verbose=0)

@time printSolution( intervalOpt(city), verbose=0)
@time printSolution( intervalBinOpt(city), verbose=0)



#Create the network
city = Metropolis(width, 10)

#Populate the network
generateProblem!(city, nTaxis, 1.0, now(), now()+Hour(2))


@time sol = randomAssignment(city, 100)
println(sol.cost)
printSolution(sol,verbose=0)
printSolution(sol,verbose=1)
printSolution(sol,verbose=2)

@time randomDescent(city, 20000).cost

drawNetwork(city, "test")
dotFile(city, "test")

methods(y)



#------------------------
#-- Manhattan
#------------------------
include("Cities/manhattan.jl")
using DataFrames
man = Manhattan();
df = DataFrame(east = [c.x for c in man.positions], north = [c.y for c in man.positions])

writetable("nodesENU.csv", df)
