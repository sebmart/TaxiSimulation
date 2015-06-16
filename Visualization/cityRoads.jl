cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/Visualization");
include("selectDefinitions.jl")

include("selectManhattan.jl")
using SFML

man = Manhattan()

minX = Inf; maxX = -Inf; minY = Inf; maxY = -Inf

for i = 1:length(man.positions)
	x = man.positions[i].x
	y = man.positions[i].y
	if (x < minX)
		minX = x
	end
	if (x > maxX)
		maxX = x
	end
	if (y < minY)
		minY = y
	end
	if (y > maxY)
		maxY = y
	end
end

bounds = (minX, maxX, minY, maxY)

function generateNodeCoordinates(m::Manhattan, bounds::Tuple{Float64,Float64,Float64,Float64})
	minX = bounds[1]
	maxX = bounds[2]
	minY = bounds[3]
	maxY = bounds[4]
	scale = 600 / max(maxX - minX, maxY - minY)
	nodeCoordinates = []
	for pos = 1:length(m.positions)
		c = m.positions[pos]
		nodeC = Coordinates(scale * (c.x - minX) + 300, scale * (c.y - minY) + 300)
		push!(nodeCoordinates, nodeC)
	end
	return nodeCoordinates
end

nodeCoordinates = generateNodeCoordinates(man, bounds)

function generateNodes(radius::Float64, nc::Vector{Any})
	nodes = CircleShape[]
	for i = 1:length(nc)
		node = CircleShape()
		set_radius(node, radius)
		set_fillcolor(node, SFML.black)
		set_position(node, Vector2f(nc[i].x, nc[i].y))
		push!(nodes, node)
	end
	return nodes
end

nodes = generateNodes(1.0, nodeCoordinates)

minscore = Inf; maxscore = -Inf
for edge in edges(man.network)
	if man.roadTime[src(edge), dst(edge)] == 0
		println(edge)
	end
	score = man.distances[src(edge), dst(edge)] / man.roadTime[src(edge), dst(edge)]
	if score < minscore
		minscore = score
	end
	if score > maxscore
		maxscore = score 
	end
end

function generateRoads(m::Manhattan, nc::Vector{Any})
	roads = Line[]
	for edge in edges(m.network)
		startNode = src(edge)
		endNode = dst(edge)
		s = Vector2f(nc[startNode].x, nc[startNode].y)
		e = Vector2f(nc[endNode].x, nc[endNode].y)
		road = Line(s, e, 1)
		set_fillcolor(road, SFML.black)
		push!(roads, road)
	end
	return roads
end

roads = generateRoads(man, nodeCoordinates)

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
	# Zoom out
	if is_key_pressed(KeyCode.Z)
		zoom(view, 0.5)
		#set_size(view, Vector2f(1800, 1800))
	end
	# Zoom in
	if is_key_pressed(KeyCode.X)
		zoom(view, 10.0)
		# set_size(view, Vector2f(100, 100))
	end
	#reset
	if is_key_pressed(KeyCode.C)
		zoom(view, 1.0)
		set_size(view, Vector2f(1200, 1200))
		view = View(Vector2f(600, 600), Vector2f(1200, 1200))
	end

	set_view(window, view)

	# t = get_elapsed_time(clock) |> as_seconds
	
	# set_string(text, "Timestep: "*string(convert(Int64, floor(t/period + 1))))
	# set_position(text, Vector2f(600.0 - get_globalbounds(text).width / 2, 10.0))

	# Draws the objects
	clear(window, SFML.white)
	
	for i = 1:length(roads)
	# for i = 1:1
		draw(window, roads[i])
	end
	for i = 1:length(nodes)
	# for i = 1:1
		draw(window, nodes[i])
	end
	# draw(window, text)
	
	display(window)
end
