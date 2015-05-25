using OpenStreetMap, Graphs
using HDF5, JLD

type Manhattan <: TaxiProblem
  network::Network
  custs::Array{Customer,1}
  taxis::Array{Taxi,1}
  nTime::Int
  waitingCost::Float64
  sp::ShortPaths

  #--------------
  #Specific attributes
    tStart::DateTime
  
    tEnd::DateTime




end



mapFile = "Cities/Manhattan/manhattan-raw.osm"
cd("/Users/Sebastien/Documents/Dropbox (MIT)/Research/Taxi/JuliaSimulation")
nodes, hwys, builds, feats = getOSMData(mapFile)
1+1


network6.
city = load("Cities/Manhattan/manhattan.jld")
city = city["network"]
stdin, proc = open(`neato -n2 -Tpdf -o graph.pdf`, "w")
drawGraph(city.g,stdin)
close(stdin)
city.
a=3
1+1

[1,2,3]
