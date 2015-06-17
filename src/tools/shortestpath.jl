#Run an all-pair shortest path using dijkstra, minimizing time and not costs
function shortestPaths!(pb::TaxiProblem)
    pb.sp = shortestPaths(pb.network, pb.roadTime, pb.roadCost)
end


function shortestPaths(n::Network, roadTime::SparseMatrixCSC{Float64, Int},
                                   roadCost::SparseMatrixCSC{Float64, Int})

  nLocs  = length( vertices(n))
  pathTime = Array(Float64, (nLocs,nLocs))
  pathCost = Array(Float64, (nLocs,nLocs))
  previous = Array(Int, (nLocs,nLocs))

  for i in 1:nLocs
    parents, dists, costs = custom_dijkstra(n,i, roadTime, roadCost)
    previous[i,:] = parents
    pathTime[i,:] = dists
    pathCost[i,:] = costs
  end
  return ShortPaths(pathTime, pathCost, previous)
end

#Compute the table of the next locations on the shortest paths
#next[i, j] = location after i when going to j
function nextLoc(n::Network, sp::ShortPaths, roadTime::SparseMatrixCSC{Float64, Int})
  nLocs = size(sp.previous,1)
  next = Array(Int, (nLocs,nLocs))
  for i in 1:nLocs, j in 1:nLocs
    if i == j
      next[i,i] = i
    else
      minTime = Inf
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

#TEMPORARY FIX
#Dijkstra algorithm

function custom_dijkstra(
    g::AbstractGraph,
    src::Int,
    edge_dists::AbstractArray{Float64, 2},
    edge_costs::AbstractArray{Float64,2})


    nvg = nv(g)
    dists = fill(typemax(Float64), nvg)
    costs = fill(typemax(Float64), nvg)
    parents = zeros(Int, nvg)
    visited = falses(nvg)
    H = Int[]
    dists[src] = 0
    costs[src] = 0.0
    sizehint(H, nvg)
    heappush!(H, src)
    while !isempty(H)
        u = heappop!(H)
        for v in out_neighbors(g,u)
            if dists[u] == typemax(Float64)
                alt = typemax(Float64)
                alt2 = typemax(Float64)
            else
                alt = dists[u] + edge_dists[u,v]
                alt2 = costs[u] + edge_costs[u,v]

            end
            if !visited[v]
                dists[v] = alt
                costs[v] = alt2
                parents[v] = u
                visited[v] = true
                heappush!(H, v)
            else
                if alt < dists[v]
                    dists[v] = alt
                    costs[v] = alt2
                    parents[v] = u
                    heappush!(H, v)
                end
            end
        end
    end

    dists[src] = 0
    costs[src] = 0.0
    parents[src] = 0


    return parents, dists, costs
end
