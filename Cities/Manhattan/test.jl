using OpenStreetMap, Graphs
mapFile = "Cities/Manhattan/manhattan-raw.osm"
cd("/Users/Sebastien/Documents/Dropbox (MIT)/Research/Taxi/JuliaSimulation")
@time nodes, hwys, builds, feats = getOSMData(mapFile)
length(nodes),  length(hwys)


bounds = Bounds(40.6780, 40.8860, -74.0382, -73.9030)
boundsENU = ENU(bounds)
nodesENU = ENU(nodes,center(bounds))
typeof(nodesENU)
highway_sets = findHighwaySets(hwys)
intersections = findIntersections(hwys)

@time intersection_cluster_mapping = findIntersectionClusters(nodesENU,intersections,highway_sets,max_dist=15)
replaceHighwayNodes!(hwys,intersection_cluster_mapping)
intersections = findIntersections(hwys)
roads = roadways(hwys)

segments = segmentHighways(nodesENU, hwys, intersections, roads, Set(1:7))
network = createGraph(segments, intersections)
network_rev = createGraph(segments, intersections, true)

stdin, proc = open(`neato -n2 -Tpng -o graph.png`, "w")
drawGraph(network.g,stdin)
close(stdin)


bell = bellman_ford_shortest_paths(network.g, network.w, [vertices(network.g)[4578]])
bell_rev = bellman_ford_shortest_paths(network_rev.g, network_rev.w, [vertices(network_rev.g)[4578]])

remove_nodes = Int[]
for (i,d) in enumerate(bell.dists)
  if d == Inf || bell_rev.dists[i] == Inf
    push!(remove_nodes,vertices(network.g)[i].key)
  end
end

network2 = remove_vertices(remove_nodes, segments, intersections, false)
network2_rev = remove_vertices(remove_nodes, segments, intersections, true)

stdin, proc = open(`neato -n2 -Tpng -o graph.png`, "w")
drawGraph(network2.g,stdin)
close(stdin)


bridgestemp = [7662, 14968, 10656, 8172, 20606, 15545, 548, 20992, 2817, 925,
8468,16867, 3980, 17750, 13346, 4776, 17154, 5077, 20065, 1531, 18815, 2626,
13486,8829,14829,12088, 11932, 17513, 9236, 18627, 438, 217, 8064, 14962, 20985,
9664, 11434, 21266, 12592, 12357, 3571, 17112, 20865]
bridges = [vertices(network2.g)[i].key for i in bridgestemp]
append!(remove_nodes, bridges)

network3 = remove_vertices(remove_nodes, segments, intersections, false)
network3_rev = remove_vertices(remove_nodes, segments, intersections, true)

stdin, proc = open(`neato -n2 -Tpng -o graph.png`, "w")
drawGraph(network3.g,stdin)
close(stdin)

bell2 = bellman_ford_shortest_paths(network3.g, network3.w, [vertices(network3.g)[19624]])
bell2_rev = bellman_ford_shortest_paths(network3_rev.g, network3_rev.w, [vertices(network3_rev.g)[19624]])

remove_nodes2 = Int[]
for (i,d) in enumerate(bell2.dists)
  if d == Inf || bell2_rev.dists[i] == Inf
    push!(remove_nodes2, remove_nodes, vertices(network3.g)[i].key)
  end
end
append!(remove_nodes2, remove_nodes)
network4 = remove_vertices(remove_nodes2, segments, intersections)

stdin, proc = open(`neato -n2 -Tpng -o graph.png`, "w")
drawGraph(network4.g,stdin)
close(stdin)


using HDF5, JLD

length(nodesENU)
length(remove_nodes)
nodes = Int[]
for i in vertices(network4.g)
  push!(nodes, i.key)
end
length(nodes)
ENUbis = Dict{Int64,ENU}()
for i in nodes
    ENUbis[i] = nodesENU[i]
end
save("Cities/Manhattan/manhattan.jld", "network", network4)
save("Cities/Manhattan/manhattan.jld", "nodes", ENUbis)



bridges2 = [6155, 3595, 14218, 2148]
bridges2 = Int[vertices(network4.g)[i].key for i in bridges2]

remove_nodes3 = [remove_nodes2, bridges2]::Vector{Int}
network5 = remove_vertices(remove_nodes3, segments, intersections, false)
network5_rev = remove_vertices(remove_nodes3, segments, intersections, true)

stdin, proc = open(`neato -n2 -Tpng -o graph.png`, "w")
drawGraph(network5.g,stdin)
close(stdin)

bell3 = bellman_ford_shortest_paths(network5.g, network5.w, [vertices(network5.g)[4323]])
bell3_rev = bellman_ford_shortest_paths(network5_rev.g, network5_rev.w, [vertices(network5_rev.g)[4323]])

remove_nodes4 = Int[]
for (i,d) in enumerate(bell3.dists)
  if d == Inf || bell3_rev.dists[i] == Inf
    push!(remove_nodes4,vertices(network5.g)[i].key)
  end
end
append!(remove_nodes4, remove_nodes3)
network6 = remove_vertices(remove_nodes4, segments, intersections)

using HDF5, JLD
save("New_York/manhattan.jld", network6)

stdin, proc = open(`neato -n2 -Tpdf -o graph.pdf`, "w")
drawGraph(network6.g,stdin)
close(stdin)


num_vertices(network6.g)



function drawGraph{G<:AbstractGraph}(graph::G, stream::IO)
    has_vertex_attrs = method_exists(attributes, (vertex_type(graph), G))
    has_edge_attrs = method_exists(attributes, (edge_type(graph), G))

    write(stream, "digraph  graphname {\n")

  if implements_edge_list(graph) && implements_vertex_map(graph)
        for edge in edges(graph)
            write(stream, "$(vertex_index(source(edge), graph)) $(edge_op(graph)) $(vertex_index(target(edge), graph))\n")
        end
    elseif implements_vertex_list(graph) && (implements_incidence_list(graph) || implements_adjacency_list(graph))
        for vertex in vertices(graph)
            id = vertex_index(vertex, graph)
            east = nodesENU[vertex.key].east
            north = nodesENU[vertex.key].north
            attr = "\"pos\"=\"$east,$(north)!\""
            write(stream, "$id [$attr]\n")

            if implements_incidence_list(graph)
                for e in out_edges(vertex, graph)
                    n = target(e, graph)
                    if is_directed(graph) || vertex_index(n, graph) > vertex_index(vertex, graph)
                        write(stream, "$(vertex_index(vertex, graph)) -> $(vertex_index(n, graph))$(has_edge_attrs ? string(" ", to_dot(attributes(e, graph))) : "")\n")
                    end
                end
            end
        end
    else
        throw(ArgumentError("More graph Concepts needed: dot serialization requires iteration over edges or iteration over vertices and neighbors."))
    end
    write(stream, "}\n")
    stream
end

function remove_vertices(remInd, segments, intersections, rev=false)
    v = Dict{Int,Graphs.KeyVertex{Int}}()                       # Vertices
    w = Float64[]                                               # Weights
    class = Int[]                                               # Road class
    g = Graphs.inclist(Graphs.KeyVertex{Int}, is_directed=true) # Graph

    for vert in keys(intersections)
      if !in(vert, remInd)
        v[vert] = Graphs.add_vertex!(g, vert)
      end
    end

    for segment in segments
        # Add edges to graph and compute weights
        if rev
          node0 = segment.node1
          node1 = segment.node0
        else
          node0 = segment.node0
          node1 = segment.node1
        end
        if !in(node0, remInd) &&  !in(node1, remInd)
          edge = Graphs.make_edge(g, v[node0], v[node1])
          Graphs.add_edge!(g, edge)
          weight = segment.dist
          push!(w, weight)
          push!(class, segment.class)
          node_set = Set(node0, node1)

          if !segment.oneway
              edge = Graphs.make_edge(g, v[node1], v[node0])
              Graphs.add_edge!(g, edge)
              push!(w, weight)
              push!(class, segment.class)
          end
      end
    end

    return OpenStreetMap.Network(g, v, w, class)

end
