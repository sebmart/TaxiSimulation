#----------------------------------------
#-- Import or declare all the tools and types
#--  to represent a taxi problem and its solutions
#----------------------------------------

using HDF5, JLD, LightGraphs

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
#---- roadTime::SparseMatrixCSC{Int8,Int} Time to cross a road
#---- roadCost::SparseMatrixCSC{Float64,Int} Cost to cross a road
#---- custs::Array{Customer,1} (customers)
#---- taxis::Array{Taxi,1} (taxis)
#---- nTime::Int number of timesteps
#---- waitingCost::Float64 cost of waiting
#---- sp::ShortPaths Shortest paths (time, cost and structure)

abstract TaxiProblem

#Represent the assignement of a customer
#taxi == 0 <=> unassigned
immutable CustomerAssignment
  taxi::Int
  timeIn::Int
  timeOut::Int
end

#Represent an assigned customer
type AssignedCustomer
  desc::Customer
  tTake::Int
  tSup::Int
end

#Represent the actions of a taxi during a simulation
#at each time, the road on which the taxi is, and the __ordered__ list of its
#taken customers
immutable TaxiActions
  path::Array{Edge,1}
  custs::Array{Int,1}
end

#Represent the solution of a simulation (paths of taxis, customers, and cost)
immutable TaxiSolution
  taxis::Array{TaxiActions, 1}
  notTakenCustomers::Array{Int,1}
  custs::Array{CustomerAssignment,1}
  cost::Float64
end

immutable ShortPaths
  traveltime::Array{Int8,2}
  travelcost::Array{Float64,2}
  previous::Array{Int,2}
end

ShortPaths() = ShortPaths( Array(Int8, (0,0)), Array(Float64, (0,0)), Array(Int, (0,0)))


#Should I keep this ?
const TAKE, DROP = 1, 2

#Represent a customer-related action of a taxi (take or drop)
immutable CustomerAction
  cust::Int
  action::Int
  taxi::Int
end

#The type of any online model
abstract OnlineModel

# Represent the actions chosen by the online algorithm for the current time-step
immutable OnlineActions
  moves::Array{Int,1} #Edge of each taxi
  actions::Array{CustomerAction, 1}
end

# Represent the new information provided to the online algorithms at each
#new time-step
immutable OnlineUpdate
  newCusts::Array{Customer, 1}
end


# Represent all the informations of the problem, excepted the customers
immutable InitialData
  network::Network
  taxis::Array{Taxi,1}
  nTime::Int
  waitingCost::Float64
  sp::ShortPaths
end

InitialData(pb::TaxiProblem) =
  InitialData(pb.network,pb.taxis,pb.nTime,pb.waitingCost,pb.sp)

#tools
include("Tools/print.jl")
include("Tools/tools.jl")
