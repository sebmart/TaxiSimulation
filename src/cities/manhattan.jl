#----------------------------------------
#-- Real Manhattan network, from OpenStreetMap data
#----------------------------------------

immutable Coordinates
  x::Float64
  y::Float64
end

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
  positions::Vector{Coordinates}
  tStart::DateTime
  tEnd::DateTime
  function Manhattan(;sp=false)
    c = new()
    data = load("cities/manhattan/manhattan.jld")
    c.network   = data["network"]
    c.distances = data["distances"]
    c.roadTime  = data["timings"]
    c.roadCost  = c.roadTime/100 #temporary
    c.positions = [Coordinates(i,j) for (i,j) in data["positions"]]
    if sp
        c.sp = shortestPaths(c.network, c.roadTime, c.roadCost)
    end
    return c
  end
end

#Output the graph vizualization to pdf file (see GraphViz library)
function drawNetwork(pb::Manhattan, name::String = "graph")
  stdin, proc = open(`neato -n2 -Tpdf -o ../outputs/$name.pdf`, "w")
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
