cd("/Users/Sebastien/Documents/Dropbox (MIT)/Research/Taxi/JuliaSimulation")
include("definitions.jl")
include("Cities/squareCity.jl")
include("Cities/metropolis.jl")
include("Offline/randomAssignment.jl")
include("Offline/randomDescent.jl")
include("Offline/simpleOpt.jl")
include("Offline/intervalOpt.jl")
include("Offline/intervalBinOpt.jl")

const width  = 5
const nTime  = 75
const nTaxis = 3
const nCusts = 20

#Create the network
city = SquareCity(width)

#Populate the network
generateProblem!(city, nTaxis, nTime, nCusts)


@time sol = simpleOpt(city)

printSolution(city,sol,verbose=0)
printSolution(city,sol,verbose=1)
printSolution(city,sol,verbose=2)

@time sol = randomAssignment(city, 100)
printSolution(city,sol,verbose=0)
printSolution(city,sol,verbose=1)
printSolution(city,sol,verbose=2)

@time printSolution(city, randomDescent(city, 1000), verbose=0)

@time printSolution(city, intervalOpt(city), verbose=0)
@time printSolution(city, intervalBinOpt(city), verbose=0)



#Create the network
city = Metropolis(width, 10)

#Populate the network
generateProblem!(city, nTaxis, 1.0, now(), now()+Hour(2))


@time sol = randomAssignment(city, 100)
println(sol.cost)
printSolution(city,sol,verbose=0)
printSolution(city,sol,verbose=1)
printSolution(city,sol,verbose=2)

@time randomDescent(city, 20000).cost

drawNetwork(city, "test")
dotFile(city, "test")

methods(y)



#------------------------
#-- Manhattan
#------------------------
include("Cities/manhattan.jl")
man =
