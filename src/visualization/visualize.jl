type customerTime
		window::Tuple{Float64, Float64}
		driving::Tuple{Float64, Float64, Int64}
end

function visualize(c::TaxiProblem, s::TaxiSolution = TaxiSolution(); radiusScale::Float64 = -1.)
	if radiusScale < 0.
		radiusScale = (typeof(c) == Manhattan) ? 0.3 : 1.0
	end

	city = c
	sol = s

	# Create bounds for the graph
	function generateBounds(nodes::Array{Coordinates,1})
		minX = Inf; maxX = -Inf; minY = Inf; maxY = -Inf
		for i = 1:length(nodes)
			minX > nodes[i].x && (minX = nodes[i].x)
			minY > nodes[i].y && (minY = nodes[i].y)
			maxX < nodes[i].x && (maxX = nodes[i].x)
			maxY < nodes[i].y && (maxY = nodes[i].y)
		end
		return (minX, maxX, minY, maxY)
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

	# Finds the minimal and maximal speeds (as determined by distance / roadTime)
	function generateScoreBound(city::TaxiProblem, nodeCoordinates::Vector{Coordinates})
		minscore = Inf; maxscore = -Inf; minedge = Inf
		for edge in edges(city.network)
			xdif = abs(nodeCoordinates[src(edge)].x - nodeCoordinates[dst(edge)].x)
			ydif = abs(nodeCoordinates[src(edge)].y - nodeCoordinates[dst(edge)].y)
			distance = sqrt(xdif * xdif + ydif * ydif)
			score = distance / city.roadTime[src(edge), dst(edge)]

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

	# Creates the roads of the graph
	function generateRoads(city::TaxiProblem, nodeCoordinates::Vector{Coordinates}, min::Float64, max::Float64)
		roads = Line[]
		for edge in edges(city.network)
			startNode = src(edge)
			endNode = dst(edge)
			s = Vector2f(nodeCoordinates[startNode].x, nodeCoordinates[startNode].y)
			e = Vector2f(nodeCoordinates[endNode].x, nodeCoordinates[endNode].y)
			# road = Line(s, e, 1.0)
			road = Line(s, e, 1.0 * radiusScale)
			distance = 0

			xdif = abs(nodeCoordinates[src(edge)].x - nodeCoordinates[dst(edge)].x)
			ydif = abs(nodeCoordinates[src(edge)].y - nodeCoordinates[dst(edge)].y)
			distance = sqrt(xdif * xdif + ydif * ydif)
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
			set_fillcolor(road, SFML.Color(floor(Int,r), floor(Int,g), floor(Int,b)))
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
	function generateTaxis(city::TaxiProblem, solution::TaxiSolution, radius::Float64, nodeCoordinates::Vector{Coordinates})
		taxis = CircleShape[]
		for i = 1:length(solution.taxis)
			taxi = CircleShape()
			set_radius(taxi, radius)
			set_fillcolor(taxi, SFML.red)
			taxiPos = city.taxis[i].initPos
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
			x = nodeCoordinates[city.custs[i].orig].x
			y = nodeCoordinates[city.custs[i].orig].y
			set_position(customer, Vector2f(0, 0))
			if solution.notTaken[i]
				set_fillcolor(customer, SFML.green)
			else
				set_fillcolor(customer, SFML.blue)
			end
			push!(customers, customer)
		end
		return customers
	end

	# Reformats the given customer information into the customerTime type defined above
	function generateCustomerTimes(city::TaxiProblem, solution::TaxiSolution)
		customerTimes = Array(customerTime, length(city.custs))
		for i = 1:length(city.custs)
			min = city.custs[i].tmin
			maxt = city.custs[i].tmaxt
			customerTimes[i] = customerTime((min, maxt), (0, 0, 0))
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
	function findTaxiLocation(city::TaxiProblem, solution::TaxiSolution, id::Int64, time::Float64, nodeCoordinates::Vector{Coordinates})
		if isempty(solution.taxis[id].path)
			return (-1, -1)
		end
		last = solution.taxis[id].path[end]
		pos = 0
		if (0 <= time && time < solution.taxis[id].path[1][1])
			pos = src(solution.taxis[id].path[1][2])
			return (nodeCoordinates[pos].x, nodeCoordinates[pos].y)
		elseif last[1] + city.roadTime[src(last[2]), dst(last[2])] <= time
			pos = dst(last[2])
			return (nodeCoordinates[pos].x, nodeCoordinates[pos].y)
		else
			index = length(solution.taxis[id].path)
			for i = 1:(length(solution.taxis[id].path) - 1)
				if solution.taxis[id].path[i][1] <= time < solution.taxis[id].path[i + 1][1]
					index = i
					break
				end
			end
			mid = solution.taxis[id].path[index]
			s = src(mid[2])
			d = dst(mid[2])
			if mid[1] + city.roadTime[s, d] <= time
				return (nodeCoordinates[d].x, nodeCoordinates[d].y)
			else
				sx = nodeCoordinates[s].x
				sy = nodeCoordinates[s].y
				dx = nodeCoordinates[d].x
				dy = nodeCoordinates[d].y
				slope = (time - mid[1]) / city.roadTime[s, d]
				newx = sx + slope * (dx - sx)
				newy = sy + slope * (dy - sy)
				return (newx, newy)
			end
		end
	end

	# Identifies a location of a given customer at a given time
	function findCustomerLocation(custTime::Array{customerTime,1}, city::TaxiProblem, solution::TaxiSolution, id::Int64, time::Float64, nodeCoordinates::Vector{Coordinates})
		customer = city.custs[id]
		timeWindow = custTime[id].window
		timeDriving = custTime[id].driving

		x = 0
		y = 0
		if sol.notTaken[id]
			if (timeWindow[1] <= time) && (time <= timeWindow[2])
				x = nodeCoordinates[customer.orig].x
				y = nodeCoordinates[customer.orig].y
			end
		else
			if (timeWindow[1] <= time) && (time < timeDriving[1])
				x = nodeCoordinates[customer.orig].x
				y = nodeCoordinates[customer.orig].y
			elseif (timeDriving[1] <= time <= timeDriving[2])
				x = - 1 * time
				y = - 1 * time
			end
		end
		return (x, y)
	end

	# Flag determines if we do not want to draw a solution
	flag = isempty(s.taxis)
	originalNodes = 0

	# If the given taxi problem has coordinates, those are used; else, coordinates are
	# generated with GraphViz
	try
		originalNodes = city.positions
	catch
		originalNodes = graphPositions(city.network)
	end

	# Calls the above functions to create the necessary objects for the visualization
	bounds = generateBounds(originalNodes)
	nodeCoordinates = generateNodeCoordinates(originalNodes, bounds)
	minEdge = generateScoreBound(city, nodeCoordinates)[3]
	nodeRadius = max(minEdge / 10, 1.0 * radiusScale)
	nodes = generateNodes(nodeRadius, nodeCoordinates)
	scoreBound = generateScoreBound(city, nodeCoordinates)
	roads = generateRoads(city, nodeCoordinates, scoreBound[1], scoreBound[2])
	if !flag
		taxiRadius = 1.5 * nodeRadius
		taxis = generateTaxis(city, sol, taxiRadius, nodeCoordinates)
		customerRadius = 2.0 * nodeRadius
		customers = generateCustomers(city, sol, customerRadius, nodeCoordinates)
		customerTimes = generateCustomerTimes(city, sol)
	end

	# Defines the window, an event listener, and view
	window = RenderWindow("Taxi Visualization", 1200, 1200)
	set_framerate_limit(window, 60)
	event = Event()
	view = View(Vector2f(600, 600), Vector2f(1200, 1200))

	# Clocks used to measure elapsed time
	clock = Clock()
	clock2 = Clock()

	# Scales the time by a factor of periodd (default is 1.0)
	period = 1.0
	reverse = false
	zoomScale = 1.0
	rotation = 0.0

	# Variables used for time manipulation
	t = 0
	time = 0
	timeTrue = 0.0
	timeFalse = 0.0
	anchorT = 0.0
	anchorTime = 0.0
	cachedTime = 0.0

	# Resets the clocks
	restart(clock)
	restart(clock2)


	while isopen(window)
		# Handles keyboard inputs
		while pollevent(window, event)
			if get_type(event) == EventType.CLOSED
				close(window)
			end
			if get_type(event) == EventType.RESIZED
				set_size(view, Vector2f(get_size(window).x, get_size(window).y + 49))
			end
			if get_type(event) == EventType.KEY_PRESSED
				if get_key(event).key_code == KeyCode.F
					reverse = !reverse
					if reverse
						cachedTime = timeFalse
					else
						cachedTime = timeTrue
					end
					restart(clock)
					restart(clock2)
				end
			end
		end
		if is_key_pressed(KeyCode.ESCAPE)
			close(window)
		end
		if is_key_pressed(KeyCode.LEFT)
			radius = 6 * get_size(view).x / 1200
			angle = (pi / 180) * (180 + rotation)
			move(view, Vector2f(radius * cos(angle), radius * sin(angle)))
		end
		if is_key_pressed(KeyCode.RIGHT)
			radius = 6 * get_size(view).x / 1200
			angle = (pi / 180) * rotation
			move(view, Vector2f(radius * cos(angle), radius * sin(angle)))
		end
		if is_key_pressed(KeyCode.UP)
			radius = 6 * get_size(view).y / 1200
			angle = (pi / 180) * (270 + rotation)
			move(view, Vector2f(radius * cos(angle), radius * sin(angle)))
		end
		if is_key_pressed(KeyCode.DOWN)
			radius = 6 * get_size(view).y / 1200
			angle = (pi / 180) * (90 + rotation)
			move(view, Vector2f(radius * cos(angle), radius * sin(angle)))
		end
		if is_key_pressed(KeyCode.Z)
			zoom(view, 0.99)
			zoomScale = zoomScale * 0.99
		end
		if is_key_pressed(KeyCode.X)
			zoom(view, 1/0.99)
			zoomScale = zoomScale * 1 / 0.99
		end
		if is_key_pressed(KeyCode.A)
			rotate(view, - 0.5)
			rotation = rotation - 0.5
		end
		if is_key_pressed(KeyCode.S)
			rotate(view, 0.5)
			rotation = rotation + 0.5
		end
		if is_key_pressed(KeyCode.C)
			set_rotation(view, 0)
			zoom(view, 1.0)
			rotation = 0.0
			zoomScale = 1.0
			set_size(view, Vector2f(get_size(window).x, get_size(window).y + 49))
		end

		set_view(window, view)

		# Gets the current time using the clock
		time = 1.0 * (get_elapsed_time(clock) |> as_seconds)

		# Handles time reversal as needed, caching the current time based on the boolean reverse
		if reverse
			time = max(cachedTime - 1.0 * (get_elapsed_time(clock2) |> as_seconds), 0)
			timeTrue = time
		elseif !reverse
			time = (cachedTime + 1.0 * (get_elapsed_time(clock) |> as_seconds))
			timeFalse = time
		end

		# Allows for speeding up, resetting, or slowing simulation time periods
		if is_key_pressed(KeyCode.Q)
			anchorT = anchorT + (time - anchorTime) / period
			anchorTime = time
			period = 0.5 ^ (0.05) * period
		end
		if is_key_pressed(KeyCode.W)
			anchorT = anchorT + (time - anchorTime) / period
			anchorTime = time
			period = 1.0
		end
		if is_key_pressed(KeyCode.E)
			anchorT = anchorT + (time - anchorTime) / period
			anchorTime = time
			period = 2 ^ (0.05) * period
		end
		if is_key_pressed(KeyCode.R)
			anchorT = 0.0
			anchorTime = 0.0
			reverse = false
			cachedTime = 0
			restart(clock)
			restart(clock2)
		end

		# Converts the current time to simulation time based on an anchor simulation time
		# and anchor clock time, as well as the current simulation period
		t = max(anchorT + (time - anchorTime) / period, 0)

		# Displays the current simulation time and time reversal status in the window title
		if !flag
			if reverse
				set_title(window, "Time: " * string(convert(Int, floor(t))) * " Reverse: On")
			else
				set_title(window, "Time: " * string(convert(Int, floor(t))) * " Reverse: Off")
			end
		end

		# Sets the taxi and customer locations as determined by the above functions and current time
		if !flag
			for i = 1:length(taxis)
				taxiloc = findTaxiLocation(city, sol, i, t, nodeCoordinates)
				if taxiloc[1] >= 0
					set_position(taxis[i], Vector2f(taxiloc[1] - taxiRadius, taxiloc[2] - taxiRadius))
				end
			end
			for i = 1:length(customers)
				customerloc = findCustomerLocation(customerTimes, city, sol, i, t, nodeCoordinates)
				if customerloc[1] < 0
					time = - 1 * customerloc[1]
					if time == customerTimes[i].driving[2]
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

		# Draws the objects in the order of customers, roads, nodes, and taxis
		clear(window, SFML.white)
		for i = 1:length(roads)
			draw(window, roads[i])
		end
		for i = 1:length(nodeCoordinates)
			draw(window, nodes[i])
		end
		if !flag
			for i = 1:length(customers)
				if (get_position(customers[i]).x != 0.0f0) && (get_position(customers[i]).y != 0.0f0)
					draw(window, customers[i])
				end
			end
			for i = 1:length(taxis)
				draw(window, taxis[i])
			end
		end

		display(window)
	end
end
