"Manhattan City, contains the real city-graph"
type Manhattan <: TaxiProblem
  network::Network
  roadTime::SparseMatrixCSC{Float64, Int}
  roadCost::SparseMatrixCSC{Float64, Int}
  custs::Array{Customer,1}
  taxis::Array{Taxi,1}
  nTime::Int
  waitingCost::Float64
  sp::ShortPaths
  discreteTime::Bool

  #--------------
  #Specific attributes
  "Distances between neighbor nodes"
  distances::SparseMatrixCSC{Float64, Int}
  "ENU position for each node"
  positions::Vector{Coordinates}
  "Starting time of the simulation"
  tStart::DateTime
  "End time of the simulation"
  tEnd::DateTime

  function Manhattan(;sp=false)
    c = new()
    data = load("$(path)/src/cities/manhattan/manhattan.jld")
    c.network   = data["network"]
    c.distances = data["distances"]
    c.roadTime  = data["timings"]
    c.roadCost  = c.roadTime/100 #temporary
    c.positions = [Coordinates(i,j) for (i,j) in data["positions"]]
    if sp
        c.sp = shortestPaths(c.network, c.roadTime, c.roadCost)
    end
    c.custs = Customer[]
    c.taxis = Taxi[]
    c.nTime = 0
    c.discreteTime = false
    return c
  end
end

"Output the graph vizualization to pdf file (see GraphViz library)"
function drawNetwork(pb::Manhattan, name::String = "graph")
  stdin, proc = open(`neato -n2 -Tpdf -o $(path)/outputs/$name.pdf`, "w")
  write(stdin, "digraph  citygraph {\n")
  for i in vertices(pb.network)
    write(stdin, "$i [\"pos\"=\"$(pb.positions[i].x),$(pb.positions[i].y)!\"]\n")
  end
  for i in vertices(pb.network), j in out_neighbors(pb.network,i)
    write(stdin, "$i -> $j\n")
  end
  write(stdin, "}\n")
  close(stdin)
end

#Generate customers and taxis, demand is a parameter correlated to the number of
# customers
function generateProblem!(city::Manhattan, nTaxis::Int, tStart::DateTime,
     tEnd::DateTime; demand::Float64 = 1.0)
  city.tStart = tStart
  city.tEnd   = tEnd
  city.nTime  = (tEnd-tStart).value/(timeSteptoSecond *1000)
  if city.nTime < 1
    error("Time of simulation too small !")
  end
  generateCustomers!(city, demand)
  generateTaxis!(city, nTaxis)
  return city
end

# "Generate customers in Manhattan using real customer data"
# function generateCustomers!(city::SquareCity, tStart::DateTime,
#      tEnd::DateTime; demand=1.0)
