

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Visualization");
include("selectDefinitions.jl")
include("selectSquareCity.jl")
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

immutable Coordinates
  x::Float64
  y::Float64
end

city = load("testcity.jld", "city")
sol = load("testsol.jld", "sol")

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Outputs");

GraphViz = []
indices = []
lines = readlines(open ("test.txt"))

index = 2
while(split(lines[index])[1] == "node")
	push!(indices, convert(Int64, float(split(lines[index])[2])))
	nodeC = Coordinates(float(split(lines[index])[3]), float(split(lines[index])[4])) 
	push!(GraphViz, nodeC)
	index += 1
end

GraphVizNodes = copy(GraphViz)
for i = 1:length(GraphViz)
	GraphVizNodes[indices[i]] = GraphViz[i]
end


width = city.width

minX = 0; maxX = 0; minY = 0; maxY = 0
X = Float64[]
Y = Float64[]
for i = 1:length(GraphVizNodes)
	push!(X, GraphVizNodes[i].x)
	push!(Y, GraphVizNodes[i].y)
end
minX = minimum(X)
maxX = maximum(X)
minY = minimum(Y)
maxY = maximum(Y)

bounds = (minX, maxX, minY, maxY)

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


function generateNodeCoordinates2(nodes::Vector{Any}, bounds::Tuple{Float64,Float64,Float64,Float64})
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

# nodeCoordinates = generateNodeCoordinates(width)
nodeCoordinates = generateNodeCoordinates2(GraphVizNodes, bounds)

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

function generateNodes2(city::TaxiProblem, radius::Int64, nodeCoordinates::Vector{Any})
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

noderadius = 10
# nodes = generateNodes(city, noderadius, nodeCoordinates)
nodes = generateNodes2(city, noderadius, nodeCoordinates)

# Creates the roads of the graph
function generateRoads(width::Int64, nodeCoordinates::Vector{Any})
	roads = Line[]
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

minscore = Inf; maxscore = -Inf
for edge in edges(city.network)
	xdif = abs(nodeCoordinates[src(edge)].x - nodeCoordinates[dst(edge)].x)
	ydif = abs(nodeCoordinates[src(edge)].y - nodeCoordinates[dst(edge)].y)
	distance = sqrt(xdif * xdif + ydif * ydif)
	score = distance/ city.roadTime[src(edge), dst(edge)]
	if score < minscore
		minscore = score
	end
	if score > maxscore
		maxscore = score 
	end
end

function generateRoads2(city::TaxiProblem, nodeCoordinates::Vector{Any}, min::Float64, max::Float64)
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

roads = generateRoads2(city, nodeCoordinates, minscore, maxscore)

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
function generateTaxis(paths::Array{Array{Pair{Int64,Int64},1},1}, radius::Int64, nodeCoordinates::Vector{Any})
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

taxiradius = 15
taxis = generateTaxis(paths, taxiradius, nodeCoordinates)

# Creates the customers in the graphs
function generateCustomers(city::TaxiProblem, solution::TaxiSolution, radius::Int64, nodeCoordinates::Vector{Any})
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

customerradius = 20
customers = generateCustomers(city, sol, customerradius, nodeCoordinates)

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

customerTimes = generateCustomerTimes(city, sol)

# Identifies a location of a given taxi at a given time
##### Change to simplify the required inputs
function findTaxiLocation(roadTime::Base.SparseMatrix.SparseMatrixCSC{Int64,Int64}, path::Array{Pair{Int64,Int64},1}, time::Float32, period::Float64, nodeCoordinates::Vector{Any})
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

text = RenderText()
set_color(text, SFML.black)
set_charactersize(text, 25)


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
	# Zoom in
	if is_key_pressed(KeyCode.Z)
		zoom(view, 0.99)
	end
	# Zoom in
	if is_key_pressed(KeyCode.X)
		zoom(view, 1/0.99)
	end
	#rotate clockwise
	if is_key_pressed(KeyCode.A)
		rotate(view, - 0.5)
	end
	#rotate counterclockwise
	if is_key_pressed(KeyCode.S)
		rotate(view, 0.5)
	end
	#reset zoom
	if is_key_pressed(KeyCode.C)
		set_rotation(view, 0)
		zoom(view, 1.0)
		view = View(Vector2f(600, 600), Vector2f(1200, 1200))
	end

	set_view(window, view)

	t = get_elapsed_time(clock) |> as_seconds
	
	set_string(text, "Timestep: "*string(convert(Int64, floor(t/period + 1))))
	set_position(text, Vector2f(600.0 - get_globalbounds(text).width / 2, 10.0))

	if t < length(paths[1]) * period
		for i = 1:length(taxis)
			taxiloc = findTaxiLocation(city.roadTime, paths[i], t, period, nodeCoordinates)
			set_position(taxis[i], Vector2f(taxiloc[1] - taxiradius, taxiloc[2] - taxiradius))
		end
		for i = 1:length(customers)
			customerloc = findCustomerLocation(i, customerTimes, city, sol, t, period, nodeCoordinates)
			if customerloc[1] < 0
				timestep = - 1 * customerloc[1]
				if timestep == customerTimes[i].driving[2]
					posX = nodeCoordinates[city.custs[i].dest].x
					posY = nodeCoordinates[city.custs[i].dest].y
					set_position(customers[i], Vector2f(posX - customerradius, posY - customerradius))
				else
					taxi = customerTimes[i].driving[3]
					pos = get_position(taxis[taxi])
					set_position(customers[i], Vector2f(pos.x + taxiradius - customerradius, pos.y + taxiradius - customerradius))
				end
			elseif customerloc[1] == 0
				set_position(customers[i], Vector2f(0, 0))
			else
				set_position(customers[i], Vector2f(customerloc[1] - customerradius, customerloc[2] - customerradius))
			end
		end
	end
	
	# Draws the objects
	clear(window, SFML.white)
	for i = 1:length(customers)
		if (get_position(customers[i]).x != 0.0f0) && (get_position(customers[i]).y != 0.0f0)
			draw(window, customers[i])
		end
	end
	for i = 1:length(roads)
		draw(window, roads[i])
	end
	for i = 1:length(nodeCoordinates)
		draw(window, nodes[i])
	end
	for i = 1:length(taxis)
		draw(window, taxis[i])
	end
	draw(window, text)
	
	display(window)
end
