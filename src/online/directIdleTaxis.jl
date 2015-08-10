"""
Uses historical data to select customers from a certain time and day
"""
function selectCustomers(taxis::Int64, demand::Float64, date::Dates.DateTime, startTime::Float64, endTime::Float64)
	city = loadTaxiPb("manhattan")
	date = DateTime(2013, 03, 01, 12, 00)
	generateProblem!(city, taxis, date, date + Dates.Minute(60), demand = demand)
	return city.custs
end

"""
Direct idle taxis using virtual customers to distrbute taxis more uniformly amongst the city
"""
function usingVirtualCustomers(pb::TaxiProblem, solver, startTime::Float64, endTime::Float64, customers::Vector{Customer})
	newpb = copy(pb)
	idleTaxis = Vector{Taxi}
	for t in pb.taxis
		if t.initTime == 0
			push!(idleTaxis)
		end
	end
	
	newpb.taxis = idleTaxis
	newpb.custs = customers
	idleSolution = solver(newpb)
	tt = TaxiSimulation.traveltimes(newpb)

	idleTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(om.pb.taxis)]
	for (i, assignments) in enumerate(idleSolution.custs)
		startPos = pb.taxis[i].initPos
		for (j, customer) in enumerate(assignments)
			c = newpb.custs[customer.id]
			path = getPath(om.pb, startPos, c.orig, customer.tInf + startTime - tt[startPos, c.orig])
			for (t, r) in path
				if t < endTime
					push!(idleTaxiActions.path, (t, r))
				end
			end
			break
		end
	end
	return idleTaxiActions
end

# Output the graph vizualization to pdf file (see GraphViz library)
using LightGraphs, Clustering
function drawNetwork(pb::TaxiProblem, name::String = "graph")
 	stdin, proc = open(`neato -Tplain -o $(path)/outputs/$(name).txt`, "w")
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

"""
Clustering a city using kmeans
"""
function clusterCity(city::TaxiProblem, k::Int64)
	originalNodes = 0
	try
		originalNodes = city.positions
	catch
		path = "/Users/bzeng/.julia/v0.4/TaxiSimulation"
		GraphVizC = Coordinates[]
		indices = Int64[]
		drawNetwork(city, "test1")
		fileExists = false
		while (!fileExists)
			sleep(1)
			fileExists = isfile("$(path)/outputs/test1.txt")
		end
		lines = readlines(open("$(path)/outputs/test1.txt"))
		rm("$(path)/outputs/test1.txt")
		index = 2
		while(split(lines[index])[1] == "node")
			push!(indices, convert(Int64, float(split(lines[index])[2])))
			nodeC = Coordinates(float(split(lines[index])[3]), float(split(lines[index])[4]))
			push!(GraphVizC, nodeC)
			index += 1
		end
		GraphVizNodes = copy(GraphVizC)
		for i = 1:length(GraphVizC)
			GraphVizNodes[indices[i]] = GraphVizC[i]
		end
		originalNodes = GraphVizNodes
	end
	coordinatesArray = Float64[]
	for c in originalNodes
		push!(coordinatesArray, c.x)
		push!(coordinatesArray, c.y)
	end
	coordinateMatrix = reshape(coordinatesArray, 2, length(originalNodes))
	R = kmeans(coordinateMatrix, k, maxiter = 1000)
	index = R.assignments[10]
	return R
end

"""
Helper function to find nearest node for each cluster center
"""
function findClosestNode(pb::TaxiProblem, coordinates::Vector{TaxiSimulation.Coordinates})
	closestNode = [0 for i in 1:length(coordinates)]
	for (i, c) in enumerate(coordinates)
		minDistance = Inf
		minIndex = 0
		for (j, pos) in enumerate(pb.positions)
			distance = sqrt((pos.x - c.x) ^ 2 + (pos.y - c.y) ^ 2)
			if distance < minDistance
				minDistance = distance
				minIndex = j
			end
		end
		closestNode[i] = minIndex
	end
	return closestNode
end

"""
Directing idle taxis using customer demand prediction by scoring a cluster for each idle taxi
and having the taxi move towards the cluster with the hightest score
"""
function usingDemandPrediction(pb::TaxiProblem, startTime::Float64, endTime::Float64, customers::Vector{Customer}, R::Clustering.KmeansResult{Float64})
	tt = TaxiSimulation.traveltimes(pb)

	scores = [0.0 for i in 1:maximum(R.assignments)]
	for c in customers
		scores[R.assignments[c.orig]] += 1.0
	end
	nodeCount = [0 for i in 1:maximum(R.assignments)]
	for i in 1:length(pb.positions)
		nodeCount[R.assignments[i]] += 1
	end
	coordinates = [TaxiSimulation.Coordinates(0.0, 0.0) for i in 1:maximum(R.assignments)]
	for (i, coordinate) in enumerate(pb.positions)
		index = R.assignments[i]
		coordinates[index] = TaxiSimulation.Coordinates(coordinates[index].x + coordinate.x / nodeCount[index], coordinates[index].y + coordinate.y / nodeCount[index])
	end 
	closestNode = findClosestNode(pb, coordinates)
	idleTaxiActions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(pb.taxis)]
	for (i, t) in enumerate(pb.taxis)
		if t.initTime == 0.0
			# p = Tuple{Int64, Float64}[]
			# for (j, score) in enumerate(scores)
			# 	if startTime + 0.5 * tt[t.initPos, closestNode[j]] <= endTime
			# 		push!(p, (j, score))
			# 	end
			# end
			# psum = sum([i[2] for i in p])
			# pscore = [(i[1], i[2] / psum) for i in p]

			pscore = copy(scores)
			for (j, score) in enumerate(scores)
				pscore[j] = score / (1 + tt[t.initPos, closestNode[j]])
			end
			maxScore = 0
			maxIndex = 0
			for (j, score) in pscore
			# for (j, score) in enumerate(pscore)
				if score > maxScore
					maxScore = score
					maxIndex = j
				end
			end
			if maxScore != 0
				append!(idleTaxiActions[i].path, TaxiSimulation.getPath(pb, t.initPos, closestNode[maxIndex], startTime))
			end
		end
	end
	return idleTaxiActions
end







