
traveltimes(paths::ShortestPaths) = paths.traveltime
travelcosts(paths::ShortestPaths) = paths.travelcost

"Return path from i to j: list of Roads and list of times (starting at 0)"
function getPath(city::TaxiProblem, p::ShortestPaths, i::Int, j::Int)
    path = Road[]
    lastNode = j
    while lastNode != i
        push!(path, Road(p.previous[i,lastNode],lastNode))
        lastNode = p.previous[i,lastNode]
    end
    reverse(path), zeros(Float64, length(path))
end

"Updates the paths of the city to be the shortest ones in time"
function shortestPaths!(pb::TaxiProblem)
    pb.paths = shortestPaths(pb.network, pb.roadTime, pb.roadCost)
end

"Run an all-pair shortest path using dijkstra, minimizing time and not costs"
function shortestPaths(n::Network, roadTime::SparseMatrixCSC{Float64, Int},
                                   roadCost::SparseMatrixCSC{Float64, Int})

  nLocs  = length( vertices(n))
  pathTime = Array(Float64, (nLocs,nLocs))
  pathCost = Array(Float64, (nLocs,nLocs))
  previous = Array(Int, (nLocs,nLocs))

  for i in 1:nLocs
    parents, dists, costs = dijkstraWithCosts(n, Int[i], roadTime, roadCost)
    previous[i,:] = parents
    pathTime[i,:] = dists
    pathCost[i,:] = costs
  end
  return ShortestPaths(pathTime, pathCost, previous)
end


#TEMPORARY FIX
#Dijkstra algorithm

# define appropriate comparators for heap entries
<(e1::DijkstraEntry, e2::DijkstraEntry) = e1.dist < e2.dist
Base.isless(e1::DijkstraEntry, e2::DijkstraEntry) = e1.dist < e2.dist

"Run dijkstra while also running costs"
function dijkstraWithCosts(
    g::AbstractGraph,
    src::Vector{Int},
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
    sizehint!(h, nvg)
    H = mutable_binary_minheap(h)
    hmap = zeros(Int, nvg)
    dists[src] = 0.0
    costs[src] = 0.0
    # Add source node to heap
    ref = push!(H, DijkstraEntry{Float64}(src, dists[src], costs[src]))
    hmap[src] = ref
    visited[src] = true
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
