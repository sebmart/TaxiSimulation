
traveltimes(paths::RealPaths) = paths.traveltime
travelcosts(paths::RealPaths) = paths.travelcost

"Return path from i to j: list of Roads and list of times (starting at 0)"
function getPath(city::TaxiProblem, p::RealPaths, i::Int, j::Int)
    # path = Road[]
    # lastNode = j
    # while lastNode != i
    #     push!(path, Road(p.previous[i,lastNode],lastNode))
    #     lastNode = p.previous[i,lastNode]
    # end
    # reverse(path), zeros(Float64, length(path))
end

"Updates the paths of the city to be the shortest paths in time with turning costs"
function realPaths!(pb::TaxiProblem)
    pb.paths = realPaths(pb.network, pb.roadTime, pb.roadCost, pb.positions)
end

function realPaths(n::Network, roadTime::SparseMatrixCSC{Float64, Int},
                               roadCost::SparseMatrixCSC{Float64, Int},
                               positions::Vector{Coordinates})

  """
  Given mapping from old nodes to new, returns mapping from new nodes to old.
  """
  function getInverseMapping(new_nodes::Array{Array{Int}}, numNewVertices::Int)
    old_nodes = zeros(Int, numNewVertices)
    for (i, array) in enumerate(new_nodes), j in array
      old_nodes[j] = i
    end
    return old_nodes
  end

  """
  Given a graph g, modifies it so that left turns are afflicted with the extra cost turn_cost.
  Requires old edge_costs as well as geographic coordinates of nodes (to determine left turns).
  Returns new network, new edge weights, and map from nodes in g to nodes in the new graph as a list of lists.
  """
  function modifyGraphForDijkstra(g::AbstractGraph, edge_dists::AbstractArray{Float64, 2},
  coords::Vector{Coordinates}; turn_cost::Float64 = 10.0)

    """
    Get angle to a given point from a given point, given a current heading.
    """
    function getAngleToPoint(currentAngle::Float64, currentX::Float64, currentY::Float64, targetX::Float64, targetY::Float64)
      angle = atan2(targetY - currentY, targetX - currentX) - currentAngle
      # Make sure it's between -pi and pi
      while angle > pi
        angle = angle - 2 * pi
      end
      while angle < -pi
        angle = angle + 2 * pi
      end
      return angle
    end

    """
    Get angle between two edges in a graph.
    """
    function getAngleEdges(xs::Float64, ys::Float64, xm::Float64, ym::Float64, xe::Float64, ye::Float64)
      currentAngle = getAngleToPoint(0.0, xs, ys, xm, ym)
      edgeAngle = getAngleToPoint(currentAngle, xm, ym, xe, ye)
      return edgeAngle
    end

    # Define some early variables
    nvg = nv(g)
    out = [sort(out_neighbors(g,i)) for i = 1:nvg]
    inn = [sort(in_neighbors(g,i)) for i = 1:nvg]
    # Create new graph
    newGraph = Network()
    new_nodes = Array{Int}[]
    sizehint(new_nodes, nvg)
    # Deal with vertices first
    for i in 1:nvg
      push!(new_nodes,Int[])
      sizehint(new_nodes[i], length(inn[i]))
      # Create as many new vertices as there are edges into the original vertex
      for j = 1:length(inn[i])
        id = add_vertex!(newGraph)
        push!(new_nodes[i], id)
      end
    end
    new_edge_dists = spzeros(nv(newGraph), nv(newGraph))
    # Now deal with edges
    for i = 1:nvg, j = 1:length(inn[i]), k = 1:length(out[i])
      # Find correct sub-node of i to connect to k
      l = findfirst(inn[out[i][k]], i)
      add_edge!(newGraph, new_nodes[i][j], new_nodes[out[i][k]][l])
      src = inn[i][j]
      dst = out[i][k]
      # Add extra edge weight appropriately
      # Make sure not to add weight if the node has only one incoming edge and one outgoing edge
      angle = getAngleEdges(coords[src].x, coords[src].y, coords[i].x, coords[i].y, coords[dst].x, coords[dst].y)
      if angle < pi/4 || (length(out[i]) == 1 && length(inn[i]) == 1)
        new_edge_dists[new_nodes[i][j], new_nodes[dst][l]] = edge_dists[i, dst]
      else
        new_edge_dists[new_nodes[i][j], new_nodes[dst][l]] = edge_dists[i, dst] + turn_cost
      end
    end
    return newGraph, new_edge_dists, new_nodes
  end

  newGraph, newRoadTime, nodeMapping = modifyGraphForDijkstra(n,roadTime,positions,turn_cost=2.0)

  nLocs  = length( vertices(n))
  pathTime = Array(Float64, (nLocs,nLocs))
  pathCost = Array(Float64, (nLocs,nLocs))
  previous = Array(Int, (nLocs,nLocs))

  for i in 1:nLocs
    parents, dists, costs = dijkstra_with_turn_cost(n, newGraph, i, newRoadTime, nodeMapping)(n,i, roadTime, roadCost)
    previous[i,:] = parents
    pathTime[i,:] = dists
    pathCost[i,:] = costs
  end
  nodeMappingRev = getInverseMapping(nodeMapping, nv(new_graph))

  return RealPaths(pathTime, pathCost, newRoadTime, nodeMappingRev)
end







#TEMPORARY FIX
#Dijkstra algorithm

# define appropriate comparators for heap entries
<(e1::DijkstraEntry, e2::DijkstraEntry) = e1.dist < e2.dist
Base.isless(e1::DijkstraEntry, e2::DijkstraEntry) = e1.dist < e2.dist

"Run dijkstra while also running costs"
function dijkstraWithCosts(
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
    sizehint!(h, nvg)
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
