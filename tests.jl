using LightGraphs
g = Graph(2)

a = 1
a += 1
add_vertex!(g)
methods(add_vertex!)
g
vertices(g)
add_edge!(g,1,1)
g = DiGraph(10,30)
edges(g)
A = sparse([1,2,4,5],[2,3,5,20],[1.1,2.2,3.3,4.4])
typeof(A)
SparseMatrixCSC
typeof(g)
#Main file: launch the simulations

include("definitions.jl")
# include("Online/onlineSim.jl")
# include("Online/immediateAssignment.jl")
include("Offline/randomAssignment.jl")
include("Offline/simpleOpt.jl")
include("Offline/fullOpt.jl")
include("Cities/squareCity.jl")

const width  = 10
const nTime  = 150
const nTaxis = 10

#Create the network
city2 = SquareCity(width, shortPaths=true)

#Populate the network
generateProblem!(city2, nTaxis, nTime)

# printSolution(pb,sol1,verbose=1)

#@time sol = randomDescent(city, 100, 1)
#printSolution(city,sol,verbose=0)

@time sol = simpleOpt(city2)
printSolution(city2,sol,verbose=0)



# @time sol2 = fullOpt(pb, sol1)
