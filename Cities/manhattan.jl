using OpenStreetMap, Graphs
using HDF5, JLD
import LightGraphs

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



cd("/Users/Sebastien/Documents/Dropbox (MIT)/Research/Taxi/JuliaSimulation")


idToVertex = data["network"].v
oldGraph   = data["network"].g
w = data["network"].w

data = load("Cities/Manhattan/manhattan.jld")

graphMan = LightGraphs.DiGraph(num_vertices(oldGraph))

for i in vertices(oldGraph), j in Set( out_neighbors(i,oldGraph))
  LightGraphs.add_edge!(graphMan, i.index, j.index)
end


weights = spzeros(num_vertices(oldGraph),num_vertices(oldGraph))
times   = spzeros(num_vertices(oldGraph),num_vertices(oldGraph))
positions = [(0.0,0.0) for i in 1:num_vertices(oldGraph))

for i in vertices(oldGraph), e in Set( out_edges(i,oldGraph))
  weights[ i.index, target(e).index] = w[e.index]
  times[ i.index, target(e).index] = 3.6*w[e.index]/OpenStreetMap.SPEED_ROADS_URBAN[data["network"].class[e.index]]
end
