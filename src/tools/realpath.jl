
traveltimes(paths::RealPaths) = paths.traveltime
travelcosts(paths::RealPaths) = paths.travelcost

"Return path from i to j: list of Roads and list of times (starting at 0)"
function getPath(city::TaxiProblem, p::RealPaths, i::Int, j::Int)
  path = Road[]
  wait = Float64[]
  lastNode = p.newDest[i,j]

  while p.nodeMapping[lastNode] != i
    prev = p.newPrevious[i, lastNode]
    push!(path, Road(p.nodeMapping[prev], p.nodeMapping[lastNode]))

    temp = p.newRoadTime[prev, lastNode] - city.roadTime[p.nodeMapping[prev], p.nodeMapping[lastNode]]
    if abs(temp) > EPS
      push!(wait, temp)
    else
      push!(wait, 0.0)
    end
    lastNode = prev
  end
  reverse(path), reverse(wait)
end

"Create the paths of the city to be the shortest paths in time with turning penalties"
function realPaths(n::Network, roadTime::AbstractArray{Float64, 2},
                               roadCost::AbstractArray{Float64, 2},
                               positions::Vector{Coordinates},
                               turnTime::Float64,
                               turnCost::Float64)

  """
  Given a graph g, modifies it so that left turns are afflicted with the extra time turnTime.
  Requires geographic coordinates of nodes (to determine left turns).
  Returns new network, new edge weights, and map from nodes in g to nodes in the new graph as a list of lists.
  """
  function leftTurnGraph(g::Network,
      roadTime::AbstractArray{Float64, 2},
      roadCost::AbstractArray{Float64, 2},
      coords::Vector{Coordinates},
      turnTime::Float64,
      turnCost::Float64)

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
    sizehint!(new_nodes, nvg)
    # Deal with vertices first
    for i in 1:nvg
      push!(new_nodes,Int[])
      sizehint!(new_nodes[i], length(inn[i]))
      # Create as many new vertices as there are edges into the original vertex
      for j = 1:length(inn[i])
        id = add_vertex!(newGraph)
        push!(new_nodes[i], id)
      end
    end
    newRoadTime = spzeros(nv(newGraph), nv(newGraph))
    newRoadCost = spzeros(nv(newGraph), nv(newGraph))
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
      if angle < π/4 || (length(inn[i]) == 1)
        newRoadTime[new_nodes[i][j], new_nodes[dst][l]] = roadTime[i, dst]
        newRoadCost[new_nodes[i][j], new_nodes[dst][l]] = roadCost[i, dst]
      else
        newRoadTime[new_nodes[i][j], new_nodes[dst][l]] = roadTime[i, dst] + turnTime
        newRoadCost[new_nodes[i][j], new_nodes[dst][l]] = roadCost[i, dst] + turnCost
      end
    end
    return newGraph, newRoadTime, newRoadCost, new_nodes
  end

  newGraph, newRoadTime, newRoadCost, nodeMapping = leftTurnGraph(n,roadTime,roadCost,positions,turnTime,turnCost)

  nLocs  = nv(n)
  nnLocs = nv(newGraph)
  pathTime = Array(Float64, (nLocs,nLocs))
  pathCost = Array(Float64, (nLocs,nLocs))
  newDest =  Array(Int, (nLocs,nLocs))

  previous = Array(Int, (nLocs,nnLocs))

  for i in 1:nLocs
    parents, times, costs = dijkstraWithCosts(newGraph, nodeMapping[i], newRoadTime, newRoadCost)
    previous[i,:] = parents
    for node = 1:nLocs
        pathTime[i,node], index = findmin(times[nodeMapping[node]])
        newDest[i,node] = index + nodeMapping[node][1] - 1
        pathCost[i,node] = costs[newDest[i,node]]
    end
  end

  nodeMappingRev = zeros(Int, nnLocs)
  for (i, array) in enumerate(nodeMapping), j in array
    nodeMappingRev[j] = i
  end

  return RealPaths(pathTime, pathCost, newRoadTime, newRoadCost, previous, newDest, nodeMappingRev)
end

"empty RealPaths object"
RealPaths() =  RealPaths(Array(Float64,(0,0)), Array(Float64,(0,0)),
spzeros(Float64,0,0), spzeros(Float64,0,0), Array(Int,(0,0)), Array(Int,(0,0)),
Int[])
