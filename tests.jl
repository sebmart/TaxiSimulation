include("definitions.jl")
include("Cities/squareCity.jl")
include("Offline/randomAssignment.jl")

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







# @time sol2 = fullOpt(pb, sol1)
