type PathCost <:AbstractDijkstraVisitor
  costs::SparseMatrixCSC{Float64,Int}
  init::Int
  pathCost::Array{Float64,2}
end


#Calculate the cost of the shortest path during Dijkstra
function LightGraphs.include_vertex!(visitor::PathCost, u, v, d)
  if u!=v
    visitor.pathcost[visitor.i,v] = visitor.pathcost[visitor.i,u] + costs[u,v]
  end
  return true
end

#Run an all-pair shortest path using dijkstra, minimizing time and not costs
function shortestPaths(n::Network, roadTime::SparseMatrixCSC{Int8, Int},
                                   roadCost::SparseMatrixCSC{Float64, Int})

  nLocs  = length( vertices(n))
  pathTime = Array(Int, (nLocs,nLocs))
  previous = Array(Int, (nLocs,nLocs))
  visit = PathCost(n,1, zeros(Float64, (nLocs,nLocs)))

  for i in 1:nLocs
    visit.i = i
    res = dijkstra_shortest_paths(n,i, edge_dists=roadTime, visitor=visit)
    for j in 1:nLocs
      pathTime[i,j] = res.dists[j]
      previous[i,j] = res.parents[j]
    end
  end
  return ShortPaths(pathTime, visit.pathcost, previous)
end

#Compute the table of the next locations on the shortest paths
#next[i, j] = location after i when going to j
function nextLoc(n::Network, sp::ShortPaths, roadTime::SparseMatrixCSC{Int8, Int})
  nLocs = size(sp.previous,1)
  next = Array(Int, (nLocs,nLocs))
  for i in 1:nLocs, j in 1:nLocs
    if i == j
      next[i,i] = i
    else
      minTime = typemax(Int)
      mink = 0
      for n in out_neighbors(n,i)
        if roadTime(i,n) + sp.traveltime[n,j] < minTime
          mink = n
          minTime = roadTime(i,n) + sp.traveltime[n,j]
        end
      end
      next[i,j] = mink
    end
  end
  return next
end