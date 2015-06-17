using HDF5
using JLD
using LightGraphs
using SFML

include("../definitions.jl")
include("../cities/manhattan.jl")
include("../cities/metropolis.jl")
include("../cities/squareCity.jl")

# Output the graph vizualization to pdf file (see GraphViz library)
function drawNetwork(pb::TaxiProblem, name::String = "graph")
  stdin, proc = open(`neato -Tplain -o Outputs/$(name).txt`, "w")
  to_dot(pb,stdin)
  close(stdin)
end

# Write the graph in dot format
function to_dot(pb::TaxiProblem, stream::IO)
    write(stream, "digraph  citygraph {\n")
    for i in vertices(pb.network), j in out_neighbors(pb.network,i)
      write(stream, "$i -> $j\n")
    end
    write(stream, "}\n")
    return stream
end

# Create bounds for the graph
function generateBounds(nodes::Array{Any,1})
	minX = 0; maxX = 0; minY = 0; maxY = 0
	X = Float64[]
	Y = Float64[]
	for i = 1:length(nodes)
		push!(X, nodes[i].x)
		push!(Y, nodes[i].y)
	end
	minX = minimum(X)
	maxX = maximum(X)
	minY = minimum(Y)
	maxY = maximum(Y)
	bounds = (minX, maxX, minY, maxY)
	return bounds
end

# Creates the coordinates of the nodes
function generateNodeCoordinates(nodes::Array{Any,1}, bounds::Tuple{Float64,Float64,Float64,Float64})
	minX = bounds[1]
	maxX = bounds[2]
	minY = bounds[3]
	maxY = bounds[4]
	scale = 600 / max(maxX - minX, maxY - minY)
	nodeCoordinates = []
	for pos = 1:length(nodes)
		c = nodes[pos]
		nodeC = Coordinates(scale * (c.x - minX) + 300, - scale * (c.y - minY) + 900)
		push!(nodeCoordinates, nodeC)
	end
	return nodeCoordinates
end

# Creates the nodes of the graph
function generateNodes(radius::Float64, nodeCoordinates::Vector{Any})
	nodes = CircleShape[]
	for i = 1:length(nodeCoordinates)
		node = CircleShape()
		set_radius(node, radius)
		set_fillcolor(node, SFML.black)
		set_position(node, Vector2f(nodeCoordinates[i].x - radius, nodeCoordinates[i].y - radius))
		push!(nodes, node)
	end
	return nodes
end

function generateScoreBound(city::TaxiProblem, flag::Bool, nodeCoordinates::Vector{Any})
	minscore = Inf; maxscore = -Inf; minedge = Inf
	for edge in edges(city.network)
		if flag
			score = city.distances[src(edge), dst(edge)] / city.roadTime[src(edge), dst(edge)]
		else
			xdif = abs(nodeCoordinates[src(edge)].x - nodeCoordinates[dst(edge)].x)
			ydif = abs(nodeCoordinates[src(edge)].y - nodeCoordinates[dst(edge)].y)
			distance = sqrt(xdif * xdif + ydif * ydif)
			score = distance/ city.roadTime[src(edge), dst(edge)]
		end
		if score < minscore
			minscore = score
		end
		if score > maxscore
			maxscore = score
		end
		dist = score * city.roadTime[src(edge), dst(edge)]
		if dist < minedge
			minedge = dist
		end
	end
	return (minscore, maxscore, minedge)
end

# Creates the roads of the graph, using coordinates from GraphViz
function generateRoads(city::TaxiProblem, nodeCoordinates::Vector{Any}, min::Float64, max::Float64)
	roads = Line[]
	for edge in edges(city.network)
		startNode = src(edge)
		endNode = dst(edge)
		println((startNode, endNode))
		s = Vector2f(nodeCoordinates[startNode].x, nodeCoordinates[startNode].y)
		e = Vector2f(nodeCoordinates[endNode].x, nodeCoordinates[endNode].y)
		
		road = Line(s, e, 1.0)
		xdif = abs(nodeCoordinates[src(edge)].x - nodeCoordinates[dst(edge)].x)
		ydif = abs(nodeCoordinates[src(edge)].y - nodeCoordinates[dst(edge)].y)
		distance = sqrt(xdif * xdif + ydif * ydif)

		score = distance / city.roadTime[src(edge), dst(edge)]
		difscore = max - min
		r = 255 * (score - max) / (- 1 * difscore)
		g = 255 * (score - min) / (difscore)
		set_fillcolor(road, SFML.Color(Int(floor(r)), Int(floor(g)), 0))
		push!(roads, road)
	end
	return roads
end

# Stores the taxi paths in an array
function generateTaxiPaths(solution::TaxiSolution)
	paths = Array{Pair{Int64,Int64},1}[]
	for i = 1:length(solution.taxis)
		push!(paths, solution.taxis[i].path)
	end
	return paths
end

# Creates the taxis in the graph
function generateTaxis(paths::Array{Array{Pair{Int64,Int64},1},1}, radius::Float64, nodeCoordinates::Vector{Any})
	taxis = CircleShape[]
	for i = 1:length(paths)
		taxi = CircleShape()
		set_radius(taxi, radius)
		set_fillcolor(taxi, SFML.red)
		taxiPos = src(paths[i][1])
		set_position(taxi, Vector2f(nodeCoordinates[taxiPos].x - radius, nodeCoordinates[taxiPos].y - radius))
		push!(taxis, taxi)
	end
	return taxis
end

# Creates the customers in the graphs
function generateCustomers(city::TaxiProblem, solution::TaxiSolution, radius::Float64, nodeCoordinates::Vector{Any})
	customers = CircleShape[]
	for i = 1:length(city.custs)
		customer = CircleShape()
		set_radius(customer, radius)
		set_fillcolor(customer, SFML.white)
		x = nodeCoordinates[city.custs[i].orig].x
		y = nodeCoordinates[city.custs[i].orig].y
		set_position(customer, Vector2f(0, 0))

		set_outline_thickness(customer, 5)
		set_outlinecolor(customer, SFML.blue)
		push!(customers, customer)
	end
	return customers
end

type customerTime
	window::Tuple{Int64, Int64}
	driving::Tuple{Int64, Int64, Int64}
end

function generateCustomerTimes(city::TaxiProblem, solution::TaxiSolution)
	customerTimes = customerTime[]
	for i = 1:length(city.custs)
		min = city.custs[i].tmin
		maxt = city.custs[i].tmaxt
		first = (min, max)
		second = 
		time = customerTime((min, maxt), (0, 0, 0))
		push!(customerTimes, time)
	end
	for i = 1:length(solution.taxis)
		for j = 1:length(solution.taxis[i].custs)
			assignment = solution.taxis[i].custs[j]
			customer = assignment.id
			tin = assignment.timeIn
			tout = assignment.timeOut
			customerTimes[customer].driving = (tin, tout, i)
		end
	end 
	return customerTimes
end

# Identifies a location of a given taxi at a given time
##### Change to simplify the required inputs
function findTaxiLocation(roadTime::Base.SparseMatrix.SparseMatrixCSC{Float64,Int64}, path::Array{Pair{Int64,Int64},1}, time::Float32, period::Float64, nodeCoordinates::Vector{Any})
	timestep = convert(Int64, floor(time/period + 1))
	s = src(path[timestep]) # edge source
	d = dst(path[timestep]) # edge destination
	totalTimesteps = roadTime[s, d]
	if s == d
		return (nodeCoordinates[s].x, nodeCoordinates[s].y)
	else
		sx = nodeCoordinates[s].x
		sy = nodeCoordinates[s].y
		dx = nodeCoordinates[d].x
		dy = nodeCoordinates[d].y
		slope = 0
		if timestep == 1
			totaltime = period * totalTimesteps
			slope = time / totaltime
		else 
			currentTimestep = timestep
			while(currentTimestep > 0 && (src(path[currentTimestep]) == s &&
				dst(path[currentTimestep]) == d)) 
				currentTimestep -= 1
			end
			starttime = currentTimestep * period 
			totaltime = period * totalTimesteps
			slope = (time - starttime) / totaltime
		end
		newx = sx + slope * (dx - sx)
		newy = sy + slope * (dy - sy)
		return (newx, newy) 
	end
end

function findCustomerLocation(id::Int64, custTime::Array{customerTime,1}, city::TaxiProblem, solution::TaxiSolution, time::Float32, period::Float64, nodeCoordinates::Vector{Any})
	timestep = convert(Int64, floor(time/period + 1))

	customer = city.custs[id]
	timestepsWindow = custTime[id].window
	timestepsDriving = custTime[id].driving

	x = 0
	y = 0
	if sol.notTaken[id]
		if (timestepsWindow[1] <= timestep) && (timestep <= timestepsWindow[2])
			x = nodeCoordinates[customer.orig].x
			y = nodeCoordinates[customer.orig].y
		end
	else
		if (timestepsWindow[1] <= timestep) && (timestep < timestepsDriving[1])
			x = nodeCoordinates[customer.orig].x
			y = nodeCoordinates[customer.orig].y
		elseif (timestepsDriving[1] <= timestep <= timestepsDriving[2])
			x = - 1 * timestep
			y = - 1 * timestep
		end
	end
	return (x, y)	
end

