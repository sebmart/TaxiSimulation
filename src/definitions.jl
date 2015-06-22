#----------------------------------------
#-- Import or declare all the tools and types
#--  to represent a taxi problem and its solutions
#----------------------------------------

typealias Network   DiGraph
typealias Road      Edge

# Implementations of Networks must have a "graph" element,
#and "ShortestPath" object, "generateCustomers" and "generateTaxis" methods.

immutable Customer
  id::Int
  orig::Int
  dest::Int
  tcall::Int
  tmin::Int
  tmaxt::Int
  tmax::Int
  price::Float64
end

immutable Taxi
  id::Int
  initPos::Int
end

#------------------------
#-- TaxiProblem: All data needed for simulation
#-- has to include:
#---- network::Network (graph of city)
#---- roadTime::SparseMatrixCSC{Int,Int} Time to cross a road
#---- roadCost::SparseMatrixCSC{Float64,Int} Cost to cross a road
#---- sp::ShortPaths Shortest paths (time, cost and structure)
#----
#---- custs::Array{Customer,1} (customers)
#---- taxis::Array{Taxi,1} (taxis)
#---- nTime::Int number of timesteps
#---- waitingCost::Float64 cost of waiting
#---- discreteTime::Bool if time is discrete

abstract TaxiProblem

#Represent the assignement of a customer
#taxi == 0 <=> unassigned
immutable CustomerAssignment
  id::Int
  timeIn::Int
  timeOut::Int
end

#Represent the actions of a taxi during a simulation
#the ordered list of roads taken by taxi, and the __ordered__ list of its
#taken customers
immutable TaxiActions
  path::Vector{ Tuple{ Float64, Edge}} #roads in order : (time, road)
  custs::Vector{ CustomerAssignment} #customer in order: (id, pickup, dropoff)
end

#Represent the solution of a simulation (paths of taxis, customers, and cost)
immutable TaxiSolution
  taxis::Array{TaxiActions, 1}
  notTaken::BitVector
  cost::Float64
end

immutable ShortPaths
  traveltime::Array{Float64,2}
  travelcost::Array{Float64,2}
  previous::Array{Int,2}
end

ShortPaths() = ShortPaths( Array(Float64, (0,0)), Array(Float64, (0,0)), Array(Int, (0,0)))


#Represent an assigned customer (not fixed time-windows)
type AssignedCustomer
  id::Int
  tInf::Int
  tSup::Int
end

#represent a time-window solution
type IntervalSolution
  custs::Vector{Vector{AssignedCustomer}}
  notTaken::BitVector
  cost::Float64
end
