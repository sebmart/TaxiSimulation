include("definitions.jl")
include("Cities/squareCity.jl")
include("Offline/randomAssignment.jl")


const width  = 5
const nTime  = 100
const nTaxis = 10
const nCusts = 50

#Create the network
city2 = SquareCity(width)

#Populate the network
generateProblem!(city2, nTaxis, nTime, nCusts)

# printSolution(pb,sol1,verbose=1)

#@time sol = randomDescent(city, 100, 1)
#printSolution(city,sol,verbose=0)

@time sol = simpleOpt(city2)
printSolution(city2,sol,verbose=0)



# @time sol2 = fullOpt(pb, sol1)
