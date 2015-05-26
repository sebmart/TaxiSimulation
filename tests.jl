cd("/Users/Sebastien/Documents/Dropbox (MIT)/Research/Taxi/JuliaSimulation")
include("definitions.jl")
include("Cities/squareCity.jl")
include("Cities/metropolis.jl")
include("Offline/randomAssignment.jl")
include("Offline/randomDescent.jl")
include("Offline/simpleOpt.jl")

@time sol = simpleOpt(city)

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

@time printSolution(city, randomDescent(city, 1000))

#Create the network
city = Metropolis(width, 4)

#Populate the network
generateProblem!(city, nTaxis, 1.0, now(), now()+Hour(2))


@time sol = randomAssignment(city, 100)
printSolution(city,sol,verbose=0)
printSolution(city,sol,verbose=1)
printSolution(city,sol,verbose=2)

@time randomDescent(city, 100).cost

a =1
a +=1
