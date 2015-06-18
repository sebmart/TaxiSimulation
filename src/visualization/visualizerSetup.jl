cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/src");
using TaxiSimulation
using HDF5
using JLD
using SFML
using LightGraphs

type customerTime
		window::Tuple{Int64, Int64}
		driving::Tuple{Int64, Int64, Int64}
end

function visualize(c::TaxiProblem, s::TaxiSolution, r::Bool)
	city = c
	sol = s
	repeat = r

	# Output the graph vizualization to pdf file (see GraphViz library)
	function drawNetwork(pb::TaxiProblem, name::String = "graph")
		cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/outputs")
	 	stdin, proc = open(`neato -Tplain -o $(name).txt`, "w")
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
	function generateBounds(nodes::Array{Coordinates,1})
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
	function generateNodeCoordinates(nodes::Array{Coordinates,1}, bounds::Tuple{Float64,Float64,Float64,Float64})
		minX = bounds[1]
		maxX = bounds[2]
		minY = bounds[3]
		maxY = bounds[4]
		scale = 600 / max(maxX - minX, maxY - minY)
		nodeCoordinates = Coordinates[]
		for pos = 1:length(nodes)
			c = nodes[pos]
			nodeC = Coordinates(scale * (c.x - minX) + 300, - scale * (c.y - minY) + 900)
			push!(nodeCoordinates, nodeC)
		end
		return nodeCoordinates
	end

	# Creates the nodes of the graph
	function generateNodes(radius::Float64, nodeCoordinates::Vector{Coordinates})
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

	function generateScoreBound(city::TaxiProblem, flag::Bool, nodeCoordinates::Vector{Coordinates})
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
	function generateRoads(city::TaxiProblem, flag::Bool, nodeCoordinates::Vector{Coordinates}, min::Float64, max::Float64)
		roads = Line[]
		for edge in edges(city.network)
			startNode = src(edge)
			endNode = dst(edge)
			s = Vector2f(nodeCoordinates[startNode].x, nodeCoordinates[startNode].y)
			e = Vector2f(nodeCoordinates[endNode].x, nodeCoordinates[endNode].y)
			road = Line(s, e, 1.0)

			distance = 0
			if flag
				distance = city.distances[src(edge), dst(edge)]
			else
				xdif = abs(nodeCoordinates[src(edge)].x - nodeCoordinates[dst(edge)].x)
				ydif = abs(nodeCoordinates[src(edge)].y - nodeCoordinates[dst(edge)].y)
				distance = sqrt(xdif * xdif + ydif * ydif)
			end
			score = distance / city.roadTime[src(edge), dst(edge)]
			difscore = max - min
			avg = (max + min)/2
	        if score < min
	                r = 128.0
	                g = 0.0
	                b = 0.0
	        elseif score < (max + min)/2
	                r = 255.0
	                g = 255.0 * 2 * (score - min) / (difscore)
	                b = 0.0
	        elseif score < max
	                r = 255.0 * 2 * (score - max) / (- 1 * difscore)
	                g = 255.0
	                b = 0.0
	        else
	                r = 0.0
	                g = 128.0
	                b = 0.0
	        end
			set_fillcolor(road, SFML.Color(Int(floor(r)), Int(floor(g)), Int(floor(b))))
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
	function generateTaxis(paths::Array{Array{Pair{Int64,Int64},1},1}, radius::Float64, nodeCoordinates::Vector{Coordinates})
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
	function generateCustomers(city::TaxiProblem, solution::TaxiSolution, radius::Float64, nodeCoordinates::Vector{Coordinates})
		customers = CircleShape[]
		for i = 1:length(city.custs)
			customer = CircleShape()
			set_radius(customer, radius)
			set_fillcolor(customer, SFML.white)
			x = nodeCoordinates[city.custs[i].orig].x
			y = nodeCoordinates[city.custs[i].orig].y
			set_position(customer, Vector2f(0, 0))

			set_outline_thickness(customer, 5)
			if solution.notTaken[i]
				set_outlinecolor(customer, SFML.green)
			else
				set_outlinecolor(customer, SFML.blue)
			end	
			push!(customers, customer)
		end
		return customers
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
	function findTaxiLocation(roadTime::Base.SparseMatrix.SparseMatrixCSC{Float64,Int64}, path::Array{Pair{Int64,Int64},1}, time::Float64, period::Float64, nodeCoordinates::Vector{Coordinates})
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

	function findCustomerLocation(id::Int64, custTime::Array{customerTime,1}, city::TaxiProblem, solution::TaxiSolution, time::Float64, period::Float64, nodeCoordinates::Vector{Coordinates})
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

	flag = false 
	originalNodes = 0

	try
		originalNodes = city.positions
		flag = true
	catch
		cd("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/outputs");
		GraphViz = Coordinates[]
		indices = Int64[]
		drawNetwork(city, "test1")
		fileExists = false
		while (!fileExists)
			sleep(1)
			fileExists = isfile("/Users/bzeng/Dropbox (MIT)/7\ Coding/UROP/taxi-simulation/outputs/test1.txt")
		end
		lines = readlines(open ("test1.txt"))
		rm("test1.txt")
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
	roads = generateRoads(city, flag, nodeCoordinates, scoreBound[1], scoreBound[2])
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
	period = 1.00
	timestep = 0

	text = RenderText()
	set_color(text, SFML.black)
	set_charactersize(text, 25)

	while isopen(window)
		while pollevent(window, event)
			if get_type(event) == EventType.CLOSED
				close(window)
			end
			if is_key_pressed(KeyCode.ESCAPE)
				close(window)
			end
			if get_type(event) == EventType.RESIZED
				set_size(view, Vector2f(get_size(window).x, get_size(window).y))
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
		if is_key_pressed(KeyCode.Q)
			period = max(period - 0.01, 0.01)
		end
		if is_key_pressed(KeyCode.W)
			period = 1.0
		end
		if is_key_pressed(KeyCode.E)
			period = period + 0.01
		end
		if is_key_pressed(KeyCode.R)
			restart(clock)
		end
		set_view(window, view)

		t = 1.0 * (get_elapsed_time(clock) |> as_seconds)
		if repeat
			set_string(text, "Timestep: " * string(convert(Int64, floor(t/period + 1))) * " Repeat: ON")
		else
			set_string(text, "Timestep: " * string(convert(Int64, floor(t/period + 1))) * " Repeat: OFF")
		end

		set_position(text, Vector2f(600.0 - get_globalbounds(text).width / 2, 10.0))

		if !flag
			if (t < length(paths[1]) * period)
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
			elseif (t > length(paths[1]) * period && !flag &&repeat)
				restart(clock)
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
end





