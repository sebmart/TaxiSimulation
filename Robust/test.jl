#Main file: launch the simulations
cd("/Users/Sebastien/Documents/Dropbox (MIT)/Research/Taxi/JuliaSimulation")

include("../definitions.jl")
include("intervalOpt.jl")

include("../Cities/squareCity.jl")

simNumber = 2
res = [Float64[] for i in 1:simNumber]
res2 = [Float64[] for i in 1:simNumber]
const width  = 5
const nTime  = 150
const nTaxis = 4


#Create the network
city = SquareCity(width, shortPaths=true)
for i=1:simNumber
#Populate the network
  generateProblem!(city, nTaxis, nTime, 40)
  for tau = 0:10
    #Baseline
    push!(res[i],-intervalOpt(city,tau, true).cost)
    #Robust time-windows
    push!(res2[i],-intervalOpt(city,tau, false).cost)
  end
end

res
using Gadfly
x = [0:10]
for i in 1:simNumber
  p = Gadfly.plot(
    layer(x=x,y=res[i],
          Geom.line),
    layer(x=x,y=res2[i],
          Geom.line,
          Theme(default_color=color("red"))),

    Guide.xlabel("Gamma"),
    Guide.ylabel("Revenue, in dollars"),
    Guide.title("Revenue of taxi company, simulation $i"))

  draw(PDF("bigNetwork$(i).pdf", 20cm, 12cm), p)
end
