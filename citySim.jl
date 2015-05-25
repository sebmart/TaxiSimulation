#----------------------------------------
#-- To launch simulations on city network
#----------------------------------------
include("definitions.jl")
include("Offline/geneticDescent.jl")
include("Offline/randomDescent.jl")
include("Offline/simpleOpt.jl")
include("Cities/metropolis.jl")

cd("/Users/Sebastien/Documents/Dropbox (MIT)/Research/Taxi/JuliaSimulation")


const width  = 30
const nSub   = 10
const nTaxis = 400
const demand2 = 0.3
tStart = now()
tEnd = now() + Hour(2)

#Create the network
@time city = Metropolis(width, nSub, shortPaths=false)
length(city.network.vertices)
@time shortestPaths!(city)
#saveTaxiPb(city,"big_metro")
city = loadTaxiPb("big_metro")

@time generateProblem!(city, nTaxis, demand2, tStart, tEnd)
descentRes = Float64[]
descentTime = Float64[]
genRes = Float64[]
genTime = Float64[]
length(sol.taxis)
#printSolution(city,simpleOpt(city),verbose=1)
@time sol2 = randomDescent(city, 10000)
@time sol = simpleOpt(city, sol)
@time sol = geneticDescent(city, 30, 10, childrenNumber=10)
srand(1111)
genTime
printSolution(city,sol2, verbose=0)
drawNetwork(city)
length(sol.notTakenCustomers)

using Gadfly
plot(
  layer(x=descentTime,y=descentRes,
        Geom.step),
  layer(x=genTime,y=genRes,
        Geom.step,
        Theme(default_color=color("red"))),

  Guide.xlabel("Time (seconds)"),
  Guide.ylabel("Revenue"),
  Guide.title("Random optimization methods"))

draw(PDF("bigNetwork2.pdf", 20cm, 12cm), p)
