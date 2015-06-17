cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation")
include("src/visualization/setup.jl")

cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src")
# city = load("visualization/tests/testcity.jld", "city")
city = Manhattan()
# sol = load("visualization/tests/testsol.jld", "sol")


flag = false 
originalNodes = 0

try
	originalNodes = city.positions
	flag = true
catch
	cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/outputs");
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

	originalNodes = GraphVizNodes
end

bounds = generateBounds(originalNodes)
nodeCoordinates = generateNodeCoordinates(originalNodes, bounds)
minEdge = generateScoreBound(city, flag, nodeCoordinates)[3]
nodeRadius = max(minEdge / 10, 1.0)
nodes = generateNodes(nodeRadius, nodeCoordinates)
scoreBound = generateScoreBound(city, flag, nodeCoordinates)
roads = generateRoads(city, nodeCoordinates, scoreBound[1], scoreBound[2])
if !flag
	paths = generateTaxiPaths(sol)
	taxiRadius = 1.5 * nodeRadius
	taxis = generateTaxis(paths, taxiRadius, nodeCoordinates)
	customerRadius = 2.0 * nodeRadius
	customers = generateCustomers(city, sol, customerRadius, nodeCoordinates)
	customerTimes = generateCustomerTimes(city, sol)
end

window = RenderWindow("Taxi Visualization", 1200, 1200)
set_framerate_limit(window, 60)
event = Event()
view = View(Vector2f(600, 600), Vector2f(1200, 1200))

clock = Clock()
restart(clock)
period = 1.0

text = RenderText()
set_color(text, SFML.black)
set_charactersize(text, 25)

while isopen(window)
	while pollevent(window, event)
		if get_type(event) == EventType.CLOSED
			close(window)
		end
	end
	if is_key_pressed(KeyCode.LEFT)
		move(view, Vector2f(-2, 0))
	end
	if is_key_pressed(KeyCode.RIGHT)
		move(view, Vector2f(2, 0))
	end
	if is_key_pressed(KeyCode.UP)
		move(view, Vector2f(0, -2))
	end
	if is_key_pressed(KeyCode.DOWN)
		move(view, Vector2f(0, 2))
	end
	if is_key_pressed(KeyCode.Z)
		zoom(view, 0.99)
	end
	if is_key_pressed(KeyCode.X)
		zoom(view, 1/0.99)
	end
	if is_key_pressed(KeyCode.A)
		rotate(view, - 0.5)
	end
	if is_key_pressed(KeyCode.S)
		rotate(view, 0.5)
	end
	if is_key_pressed(KeyCode.C)
		set_rotation(view, 0)
		zoom(view, 1.0)
		view = View(Vector2f(600, 600), Vector2f(1200, 1200))
	end

	set_view(window, view)

	t = get_elapsed_time(clock) |> as_seconds
	
	set_string(text, "Timestep: "*string(convert(Int64, floor(t/period + 1))))
	set_position(text, Vector2f(600.0 - get_globalbounds(text).width / 2, 10.0))

	if (t < length(paths[1]) * period && !flag)
		for i = 1:length(taxis)
			taxiloc = findTaxiLocation(city.roadTime, paths[i], t, period, nodeCoordinates)
			set_position(taxis[i], Vector2f(taxiloc[1] - taxiRadius, taxiloc[2] - taxiRadius))
		end
		for i = 1:length(customers)
			customerloc = findCustomerLocation(i, customerTimes, city, sol, t, period, nodeCoordinates)
			if customerloc[1] < 0
				timestep = - 1 * customerloc[1]
				if timestep == customerTimes[i].driving[2]
					posX = nodeCoordinates[city.custs[i].dest].x
					posY = nodeCoordinates[city.custs[i].dest].y
					set_position(customers[i], Vector2f(posX - customerRadius, posY - customerRadius))
				else
					taxi = customerTimes[i].driving[3]
					pos = get_position(taxis[taxi])
					set_position(customers[i], Vector2f(pos.x + taxiRadius - customerRadius, pos.y + taxiRadius - customerRadius))
				end
			elseif customerloc[1] == 0
				set_position(customers[i], Vector2f(0, 0))
			else
				set_position(customers[i], Vector2f(customerloc[1] - customerRadius, customerloc[2] - customerRadius))
			end
		end
	end
	
	# Draws the objects
	clear(window, SFML.white)
	if !flag
		for i = 1:length(customers)
			if (get_position(customers[i]).x != 0.0f0) && (get_position(customers[i]).y != 0.0f0)
				draw(window, customers[i])
			end
		end
	end
	for i = 1:length(roads)
		draw(window, roads[i])
	end
	for i = 1:length(nodeCoordinates)
		draw(window, nodes[i])
	end
	if !flag
		for i = 1:length(taxis)
			draw(window, taxis[i])
		end
	end

	draw(window, text)
	display(window)
end



