include("definitions.jl")
include("Cities/squareCity.jl")
include("Cities/metropolis.jl")
include("Offline/randomAssignment.jl")
include("Offline/randomDescent.jl")

const width  = 5
const nTime  = 100
const nTaxis = 10
const nCusts = 50

#Create the network
city = SquareCity(width)

#Populate the network
generateProblem!(city, nTaxis, nTime, nCusts)


@time sol = randomAssignment(city, 100)
printSolution(city,sol,verbose=0)
printSolution(city,sol,verbose=1)
printSolution(city,sol,verbose=2)

@time printSolution(city, randomDescent(city, 100))

#Create the network
city = Metropolis(width, 4)

#Populate the network
generateProblem!(city, nTaxis, 1.0, now(), now()+Hour(2))


@time sol = randomAssignment(city, 100)
printSolution(city,sol,verbose=0)
printSolution(city,sol,verbose=1)
printSolution(city,sol,verbose=2)

@time randomDescent(city, 100).cost
