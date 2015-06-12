

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Visualization");
include("selectDefinitions.jl")
include("selectSquareCity.jl")
city = load("testcity.jld", "city")
sol = load("testsol.jld", "sol")

using SFML

# Output the graph vizualization to pdf file (see GraphViz library)
function drawNetwork(pb::TaxiProblem, name::String = "graph")
  stdin, proc = open(`neato -Tpdf -o Outputs/$(name).pdf`, "w")
  to_dot(pb,stdin)
  close(stdin)
end

# Output dotfile
function dotFile(pb::TaxiProblem, name::String = "graph")
  open("Outputs/$name.dot","w") do f
    to_dot(pb, f)
  end
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
function generateNodeCoordinates()
	return Tuple{Array{Int64,1},Array{Int64,1}}
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

function generateRoads()
	return 0
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
	for taxi = 1:length(paths)
		taxi = CircleShape()
		set_radius(taxi, radius)
		set_fillcolor(node, SFML.blue)
		taxiPos = src(paths[taxi][1])
		set_position(taxi, Vector2f(nodeX[taxiPos] - radius, nodeY[taxiPos] - radius))
		push!(taxis, taxi)
	end
	return taxis
end

# Handles the taxi customers
function generateCustomers(solution::TaxiSolution)
	return 0
end

# Identifies a location of a given taxi at a given time
function findTaxiLocation(paths::Array{Array{Pair{Int64,Int64},1},1}, taxi::Int64, time::Float32, period::Float64, nodeCoordinates::Tuple{Array{Int64,1},Array{Int64,1}})
	nodeX = nodeCoordinates[1]
	nodeY = nodeCoordinates[2]
	timestep = convert(Int64, floor(time/period + 1))
	s = src(taxiPaths[taxi][timestep]) # edge source
	d = dst(taxiPaths[taxi][timestep]) # edge destination
	totalTimesteps = city.roadTime[s, d]
	if s == d
		return [nodeX[s], nodeY[s]]
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
			while(src(taxiPaths[taxi][currentTimestep]) == s &&
				dst(taxiPaths[taxi][currentTimestep]) == d)
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

# X and Y coordinates of the nodes
nodeX = [300, 500, 700, 900, 300, 500, 700, 900, 300, 500, 700, 900, 300, 500, 700, 900]
nodeY = [300, 300, 300, 300, 500, 500, 500, 500, 700, 700, 700, 700, 900, 900, 900, 900]
nodeCoordinates = (nodeX, nodeY)

taxi = CircleShape()
taxiradius = 10
set_radius(taxi, taxiradius)
set_position(taxi, Vector2f(300 - taxiradius, 300 - taxiradius))
set_fillcolor(taxi, SFML.blue)

customer = CircleShape()
customerradius = 25
set_radius(customer, customerradius)
set_position(customer, Vector2f(300 - customerradius, 300 - customerradius))
set_outline_thickness(customer, 5)
set_outlinecolor(customer, SFML.blue)

taxipath = [(1, 2), (2, 3), (3, 7), (7, 8), (8, 12), (12, 16), (16, 15), (15, 11), (11, 10)]
customerpath = [(1, 2), (2, 3), (3, 7), (7, 8), (8, 8), (8, 8), (8, 8), (8, 8), (8, 8)]

agents = [taxi, customer]

function c(t::Float64)
	return convert(Float32, t)
end

# Identifies a location of a given taxi at a given time
function findTaxiLocation2(path::Array{Tuple{Int64,Int64},1}, time::Float32)
	nodeX = nodeCoordinates[1]
	nodeY = nodeCoordinates[2]
	timestep = convert(Int64, floor(time/period + 1))
	s = (path[timestep][1]) # edge source
	d = (path[timestep][2]) # edge destination
	totalTimesteps = 1
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
			while(path[currentTimestep][1] == s &&
				path[currentTimestep][2] == d)
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

# A sample customer
circle2 = CircleShape()
radius2 = 25
set_radius(circle2, radius2)
set_position(circle2, Vector2f(500 - radius2, 300 - radius2))
set_fillcolor(circle2, SFML.white)
set_outline_thickness(circle2, 5)
set_outlinecolor(circle2, SFML.blue)

# A sample taxi
circle3 = CircleShape()
radius3 = 10
set_radius(circle3, radius3)
set_position(circle3, Vector2f(900 - radius3, 700 - radius3))
set_fillcolor(circle3, SFML.blue)

pos = get_position(circle3)


# Creates the nodes
circles = CircleShape[]
for i = 1:16
	circle = CircleShape()
	radius = 20
	set_radius(circle, radius)
	set_fillcolor(circle, SFML.black)
	set_position(circle, Vector2f(nodeX[i] - radius, nodeY[i] - radius))
	push!(circles, circle)
end

# Creates the roads (will replace with an edge list)
horizontalLines = Line[]
for i = 1:3
	for j = 0:3
		point = i + 4 * j
		p1 = Vector2f(nodeX[point], nodeY[point])
		p2 = Vector2f(nodeX[point + 1], nodeY[point + 1])
		line = Line(p1, p2, 1)
		set_fillcolor(line, SFML.black)
		push!(horizontalLines, line)
	end
end

verticalLines = Line[]
for i = 0:2
	for j = 1:4
		point = j + 4 * i
		p1 = Vector2f(nodeX[point], nodeY[point])
		p2 = Vector2f(nodeX[point + 4], nodeY[point + 4])
		line = Line(p1, p2, 1)
		set_fillcolor(line, SFML.black)
		push!(verticalLines, line)
	end
end

# Creates a clock to allow us to use time
clock = Clock()
restart(clock)
period = 1.5

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

	# time = get_elapsed_time(clock)
	# for taxi = 1:length(taxiPaths)
	t = get_elapsed_time(clock) |> as_seconds
	if t < 9 * period
		taxiloc = findTaxiLocation2(taxipath, t)
		customerloc = findTaxiLocation2(customerpath, t)
		set_position(taxi, Vector2f(taxiloc[1] - taxiradius, taxiloc[2] - taxiradius))
		set_position(customer, Vector2f(customerloc[1] - customerradius, customerloc[2] - customerradius))
	end
	
	# Draws the objects
	clear(window, SFML.white)
	#draw(window, circle2)
	draw(window, customer)
	for i = 1:length(circles)
		draw(window, circles[i])
	end
	for i = 1:length(horizontalLines)
		draw(window, horizontalLines[i])
		draw(window, verticalLines[i])
	end
	draw(window, taxi)

	
	display(window)
end
