# shortestPathTests.jl
# Quick test to make sure Dijkstra implementation is working

using LightGraphs

graph = Network(6)
add_edge!(graph, 3, 1)
add_edge!(graph, 2, 1)
add_edge!(graph, 2, 4)
add_edge!(graph, 3, 2)
add_edge!(graph, 6, 3)
add_edge!(graph, 6, 2)
add_edge!(graph, 6, 5)
add_edge!(graph, 5, 2)
roadTime = spzeros(6,6)
roadTime[3,1] = 6.0
roadTime[2,1] = 1.0
roadTime[2,4] = 8.0
roadTime[3,2] = 3.0
roadTime[6,3] = 1.0
roadTime[6,2] = 5.0
roadTime[6,5] = 2.0
roadTime[5,2] = 1.0
parents, dists, costs = TaxiSimulation.custom_dijkstra(graph, 6, roadTime, roadTime)
# Test parents
@test parents[6] == 0
@test parents[5] == 6
@test parents[2] == 5
@test parents[1] == 2
@test parents[3] == 6
@test parents[4] == 2
# Test distances
@test_approx_eq_eps dists[6] 0.0 1e-5
@test_approx_eq_eps dists[5] 2.0 1e-5
@test_approx_eq_eps dists[2] 3.0 1e-5
@test_approx_eq_eps dists[1] 4.0 1e-5
@test_approx_eq_eps dists[3] 1.0 1e-5
@test_approx_eq_eps dists[4] 11.0 1e-5
