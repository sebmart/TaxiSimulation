using SFML

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

# Creates the coordinates of the nodes
##### Change NodeCoordinates to [(x, y), ...] and all associated usage
function generateNodeCoordinates(width::Int64)
	nodeX = [1:width * width]
	nodeY = [1:width * width]
	interval = convert(Int64, 600 / (width - 1))
	for i = 1:width
		for j = 1:width
			nodeX[i + width * (j - 1)] = 300 + interval * (i - 1)
			nodeY[i + width * (j - 1)] = 300 + interval * (j - 1)
		end
	end
	return (nodeX, nodeY)
end

# Creates the nodes of the graph
function generateNodes(city::TaxiProblem, radius::Int64, nodeCoordinates::Tuple{Array{Int64,1},Array{Int64,1}})
	nodes = CircleShape[]
	nodeX = nodeCoordinates[1]
	nodeY = nodeCoordinates[2]
	for i = 1:length(nodeX)
		node = CircleShape()
		set_radius(node, radius)
		set_fillcolor(node, SFML.black)
		set_position(node, Vector2f(nodeX[i] - radius, nodeY[i] - radius))
		push!(nodes, node)
	end
	return nodes
end

# Creates the roads of the graph
function generateRoads(width::Int64, nodeCoordinates::Tuple{Array{Int64,1},Array{Int64,1}})
	roads = Line[]
	nodeX = nodeCoordinates[1]
	nodeY = nodeCoordinates[2]
	for i = 1:(width - 1)
		for j = 0:(width - 1)
			point = i + width * j
			p1 = Vector2f(nodeX[point], nodeY[point])
			p2 = Vector2f(nodeX[point + 1], nodeY[point + 1])
			line = Line(p1, p2, 1)
			set_fillcolor(line, SFML.black)
			push!(roads, line)

			point = (j + 1) + width * (i - 1)
			p1 = Vector2f(nodeX[point], nodeY[point])
			p2 = Vector2f(nodeX[point + width], nodeY[point + width])
			line = Line(p1, p2, 1)
			set_fillcolor(line, SFML.black)
			push!(roads, line)
		end
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
function generateTaxis(paths::Array{Array{Pair{Int64,Int64},1},1}, radius::Int64, nodeCoordinates::Tuple{Array{Int64,1},Array{Int64,1}})
	taxis = CircleShape[]
	nodeX = nodeCoordinates[1]
	nodeY = nodeCoordinates[2]
	for i = 1:length(paths)
		taxi = CircleShape()
		set_radius(taxi, radius)
		set_fillcolor(taxi, SFML.red)
		taxiPos = src(paths[i][1])
		set_position(taxi, Vector2f(nodeX[taxiPos] - radius, nodeY[taxiPos] - radius))
		push!(taxis, taxi)
	end
	return taxis
end

# Creates the customers in the graphs
function generateCustomers(city::TaxiProblem, solution::TaxiSolution, radius::Int64, nodeCoordinates::Tuple{Array{Int64,1},Array{Int64,1}})
	customers = CircleShape[]
	nodeX = nodeCoordinates[1]
	nodeY = nodeCoordinates[2]
	for i = 1:length(city.custs)
		customer = CircleShape()
		set_radius(customer, radius)
		set_fillcolor(customer, SFML.white)
		x = nodeX[city.custs[i].orig]
		y = nodeY[city.custs[i].orig]
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
function findTaxiLocation(roadTime::Base.SparseMatrix.SparseMatrixCSC{Int64,Int64}, path::Array{Pair{Int64,Int64},1}, time::Float32, period::Float64, nodeCoordinates::Tuple{Array{Int64,1},Array{Int64,1}})
	nodeX = nodeCoordinates[1]
	nodeY = nodeCoordinates[2]
	timestep = convert(Int64, floor(time/period + 1))
	s = src(path[timestep]) # edge source
	d = dst(path[timestep]) # edge destination
	totalTimesteps = roadTime[s, d]
	if s == d
		return (nodeX[s], nodeY[s])
	else
		sx = nodeX[s]
		sy = nodeY[s]
		dx = nodeX[d]
		dy = nodeY[d]
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

function findCustomerLocation(id::Int64, custTime::Array{customerTime,1}, city::TaxiProblem, solution::TaxiSolution, time::Float32, period::Float64, nodeCoordinates::Tuple{Array{Int64,1},Array{Int64,1}})
	nodeX = nodeCoordinates[1]
	nodeY = nodeCoordinates[2]
	timestep = convert(Int64, floor(time/period + 1))

	customer = city.custs[id]
	timestepsWindow = custTime[id].window
	timestepsDriving = custTime[id].driving

	x = 0
	y = 0
	if sol.notTaken[id]
		if (timestepsWindow[1] <= timestep) && (timestep <= timestepsWindow[2])
			x = nodeX[customer.orig]
			y = nodeY[customer.orig]
		end
	else
		if (timestepsWindow[1] <= timestep) && (timestep < timestepsDriving[1])
			x = nodeX[customer.orig]
			y = nodeY[customer.orig]
		elseif (timestepsDriving[1] <= timestep <= timestepsDriving[2])
			x = - 1 * timestep
			y = - 1 * timestep
		end
	end
	return (x, y)	
end

function generateNodeCoordinates2()