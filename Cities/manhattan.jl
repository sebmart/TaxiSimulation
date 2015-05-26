#----------------------------------------
#-- Real Manhattan network, from OpenStreetMap data
#----------------------------------------



type Manhattan <: TaxiProblem
  network::Network
  roadTime::SparseMatrixCSC{Float64, Int}
  roadCost::SparseMatrixCSC{Float64, Int}
  custs::Array{Customer,1}
  taxis::Array{Taxi,1}
  nTime::Int
  waitingCost::Float64
  sp::ShortPaths

  #--------------
  #Specific attributes
  distances::SparseMatrixCSC{Float64, Int}
  positions::Vector{ (Float64, Float64)}
  tStart::DateTime
  tEnd::DateTime
  function Manhattan()
    c = new()
    data = load("Manhattan/manhattan.jld")
    c.network   = data["network"]
    c.distances = data["distances"]
    c.roadTime  = data["timings"]
    c.positions = data["positions"]
  end


end
