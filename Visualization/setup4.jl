

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Visualization");
include("selectDefinitions.jl")
include("selectSquareCity.jl")

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

city = load("testcity.jld", "city")
sol = load("testsol.jld", "sol")
drawNetwork(city, "test")

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Visualization/Outputs");
lines = readlines(open ("test.txt"))
index = 2
while(split(lines[index])[1] == "node")
	index += 1
end
nodecount = index - 2
width = convert(Int64, sqrt(nodecount))

using SFML

# Creates the coordinates of the nodes
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

nodeCoordinates = generateNodeCoordinates(width)

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

noderadius = 10
nodes = generateNodes(city, noderadius, nodeCoordinates)

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

roads = generateRoads(width, nodeCoordinates)

# Stores the taxi paths in an array
function generateTaxiPaths(solution::TaxiSolution)
	paths = Array{Pair{Int64,Int64},1}[]
	for i = 1:length(solution.taxis)
		push!(paths, solution.taxis[i].path)
	end
	return paths
end

paths = generateTaxiPaths(sol)

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

taxiradius = 15
taxis = generateTaxis(paths, taxiradius, nodeCoordinates)

# Handles the taxi customers
function generateCustomers(solution::TaxiSolution)
	return 0
end

customer = CircleShape()
customerradius = 12
set_radius(customer, customerradius)
set_position(customer, Vector2f(300 - customerradius, 300 - customerradius))
set_outline_thickness(customer, 5)
set_outlinecolor(customer, SFML.blue)

# Identifies a location of a given taxi at a given time
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
			while((src(path[currentTimestep]) == s &&
				dst(path[currentTimestep]) == d) && currentTimestep > 1) 
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

# Creates the window for the visualization
window = RenderWindow("Taxi", 1200, 1200)
set_framerate_limit(window, 60)

# An event listener for keyboard inputs
event = Event()

# Creates the view or camera for the window
view = View(Vector2f(600, 600), Vector2f(1200, 1200))

# Creates a clock to allow us to use time
clock = Clock()
restart(clock)

# Defines a period (float64) for each timestep
period = 1.0

# Draws the visualization 
while isopen(window)
	while pollevent(window, event)
		if get_type(event) == EventType.CLOSED
			close(window)
		end
	end

	# Check keypresses to control the view
	if is_key_pressed(KeyCode.LEFT)
		# Move left
		move(view, Vector2f(-2, 0))
	end
	if is_key_pressed(KeyCode.RIGHT)
		# Move right
		move(view, Vector2f(2, 0))
	end
	if is_key_pressed(KeyCode.UP)
		# Move up
		move(view, Vector2f(0, -2))
	end
	if is_key_pressed(KeyCode.DOWN)
		# Move down
		move(view, Vector2f(0, 2))
	end
	# Zoom out
	if is_key_pressed(KeyCode.Z)
		zoom(view, 0.5)
		set_size(view, Vector2f(1800, 1800))
	end
	# Zoom in
	if is_key_pressed(KeyCode.X)
		zoom(view, 2.0)
		set_size(view, Vector2f(800, 800))
	end
	#reset
	if is_key_pressed(KeyCode.C)
		zoom(view, 1.0)
		set_size(view, Vector2f(1200, 1200))
		view = View(Vector2f(600, 600), Vector2f(1200, 1200))
	end

	set_view(window, view)

	t = get_elapsed_time(clock) |> as_seconds

	if t < length(paths[1]) * period
		for i = 1:length(paths)
			taxiloc = findTaxiLocation(city.roadTime, paths[i], t, period, nodeCoordinates)
			set_position(taxis[i], Vector2f(taxiloc[1] - taxiradius, taxiloc[2] - taxiradius))
		end
	end

	
	# Draws the objects
	clear(window, SFML.white)

	for i = 1:length(roads)
		draw(window, roads[i])
	end
	for i = 1:length(nodeX)
		draw(window, nodes[i])
	end
	for i = 1:length(taxis)
		draw(window, taxis[i])
	end
	
	display(window)
end
