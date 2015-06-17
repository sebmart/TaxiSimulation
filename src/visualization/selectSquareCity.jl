# n*n points randomized square network
#between 1 and 4 time-steps for taking a link
#cost : between(1.5 and 2.5)*time if moving, 1*time if staying

type SquareCity <: TaxiProblem
  network::Network
  roadTime::SparseMatrixCSC{Int, Int}
  roadCost::SparseMatrixCSC{Float64, Int}
  custs::Array{Customer,1}
  taxis::Array{Taxi,1}
  nTime::Int
  waitingCost::Float64
  sp::ShortPaths
#--------------
#Specific attributes
  width::Int
end