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

# define appropriate comparators for heap entries
< (e1::DijkstraEntry, e2::DijkstraEntry) = e1.dist < e2.dist
Base.isless(e1::DijkstraEntry, e2::DijkstraEntry) = e1.dist < e2.dist

function custom_dijkstra(
    g::AbstractGraph,
    src::Int,
    edge_dists::AbstractArray{Float64, 2},
    edge_costs::AbstractArray{Float64, 2})

    # find number of vertices
    nvg = nv(g)
    # initialize return types
    dists = fill(typemax(Float64), nvg)
    costs = fill(typemax(Float64), nvg)
    parents = zeros(Int, nvg)
    visited = falses(nvg)
    # Create mutable binary heap and associated hashmap
    h = DijkstraEntry{Float64}[]
    sizehint(h, nvg)
    H = mutable_binary_minheap(h)
    hmap = zeros(Int, nvg)
    dists[src] = 0.0
    costs[src] = 0.0
    # Add source node to heap
    ref = push!(H, DijkstraEntry{Float64}(src, dists[src], costs[src]))
    hmap[src] = ref
    # As long as all edges have not been explored
    while !isempty(H)
        # Retrieve closest element to source
        hentry = pop!(H)
        u = hentry.vertex
        # Look at all its neighbors and update relevant distances if necessary
        for v in out_neighbors(g,u)
            if dists[u] == typemax(Float64)
                alt = typemax(Float64)
                alt2 = typemax(Float64)
            else
                alt = dists[u] + edge_dists[u,v]
                alt2 = costs[u] + edge_costs[u,v]
            end
            if !visited[v]  # If a vertex has never been visited, push it to the heap
                dists[v] = alt
                costs[v] = alt2
                parents[v] = u
                visited[v] = true
                ref = push!(H, DijkstraEntry{Float64}(v, alt, alt2))
                hmap[v] = ref
            else            # If a vertex has been visited, decrease its key if distance estimate decreases
                if alt < dists[v]
                    dists[v] = alt
                    costs[v] = alt2
                    parents[v] = u
                    update!(H, hmap[v], DijkstraEntry{Float64}(v, alt, alt2))
                end
            end
        end
    end

    dists[src] = 0
    costs[src] = 0.0
    parents[src] = 0


    return parents, dists, costs
end