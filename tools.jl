#----------------------------------------
#-- Useful functions to deal with TaxiProblem and TaxiSolution objects
#----------------------------------------

#Compute the cost of a solution
function solutionCost(pb::TaxiProblem, taxis::Array{TaxiActions, 1},
                                       custs::Array{CustomerAssignment, 1})
  cost = 0.
  road = edges(pb.network)
  #price paid by customers
  for (id,c) in enumerate(custs)
    if c.taxi != 0
      cost -= pb.custs[id].price
    end
  end
  for (k,t) in enumerate(taxis)
    previous_index = 0
    for r in t.path
      if road[r].source == road[r].target
        cost += pb.waitingCost
      elseif r != previous_index
        cost += road[r].attributes["c"] #cost of taking the road
      end
      previous_index = r
    end
  end
  return cost
end

#Print a taxi assignment solution
function printSolution(pb::TaxiProblem, s::TaxiSolution; verbose=0)
  if verbose == 0
    printShort(pb,s)
  elseif verbose == 1
    printMedium(pb,s)
  else
    printLong(pb,s)
  end

  nt = s.notTakenCustomers
  if length(nt) != 0
    println("=== NOT TAKEN")
    println("==========================")
    if length(nt) == 1
      print("Customer $(nt[1])")
    else
      print("Customers $(nt[1])")
    end
    for i in 2:length(nt)
      print(", $(nt[i])")
    end
    print("\n")
  end
  println("=== REVENUE OF THE DAY")
  println("==========================")
  @printf("%.2f dollars\n",-s.cost)

end

function printShort(pb::TaxiProblem, s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("=== TAXI $k")
    println("==========================")
    for c in tax.custs
      println("Takes customer $c at time $(s.custs[c].timeIn)")
    end
  end
end

function printMedium(pb::TaxiProblem, s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("\n=== TAXI $k")
    println("==========================")
    idc = 1
    count = 0
    roadId = Edge(0,0)
    moves = false
    for t in 1:pb.nTime
      if !moves
        print("\nMoves: ")
        moves = true
      end
      if tax.path[t] == roadId
        count += 1
      elseif roadId != 0
        print("$(road[roadId].src)=>$(road[roadId].dst) ($count) - ")
        count = 1
        roadId = tax.path[t]
      else
        count = 1
        roadId = tax.path[t]
      end
      if idc <= length(tax.custs) &&(s.custs[tax.custs[idc]].timeOut == t)
        print("\nDrops customer $(tax.custs[idc]) at time $t")
        moves = false
        idc += 1
      end

      if idc <= length(tax.custs) && (s.custs[tax.custs[idc]].timeIn == t)
        print("\nTakes customer $(tax.custs[idc]) at time $t")
        moves = false
      end
    end
    print("$(road[roadId].source)=>$(road[roadId].source) ($count) - \n")
  end
end

function printLong(pb::TaxiProblem, s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("=== TAXI $k")
    println("==========================")
    road = edges(pb.network)
    idc = 1
    for t in 1:pb.nTime
      println("== time $t")
      if idc <= length(tax.custs) &&(s.custs[tax.custs[idc]].timeOut == t)
        println("Drops customer $(tax.custs[idc]) at location $(pb.custs[tax.custs[idc]].dest)")
        idc += 1
      end

      if idc <= length(tax.custs) && (s.custs[tax.custs[idc]].timeIn == t)
        println("Takes customer $(tax.custs[idc]) at location $(pb.custs[tax.custs[idc]].orig)")
      end

      if road[tax.path[t]].source == road[tax.path[t]].target
        println("Waits at location $(road[tax.path[t]].source)")
      else
        println("Moves from location $(road[tax.path[t]].source) to location $(road[tax.path[t]].target)")
      end
    end
  end
end


#Reconstruct the complete path of the taxis from their assigned customers
#The rule is to wait near the next customers if the taxi has to wait
function taxi_paths(pb::TaxiProblem,
   custs::Array{CustomerAssignment,1}, cpt::Array{Array{Int,1},1})
   sp = pb.sp
   res = Array(Array{Int,1},length(pb.taxis))
   for k in 1:length(res)
     res[k] = Array(Int,pb.nTime)
     endTime = pb.nTime
     endDest = 0
     for i in length(cpt[k]):-1:1
       c = cpt[k][i]

       #Trajectory from origin to dest of customer (computed backward)
       loc = pb.custs[c].dest
       t = custs[c].timeOut

       while t != custs[c].timeIn
         prev = sp.previous[pb.custs[c].orig,loc]
         road = find_edge(pb.network,prev,loc)
         for t2 in (t-road.attributes["l"]):(t-1)
           res[k][t2] = road.index
         end
         loc = prev
         t = t-road.attributes["l"]
       end

       #After last customer: stays at the same place
       if i == length(cpt[k])
         road = find_edge(pb.network,pb.custs[c].dest,pb.custs[c].dest)
         for t = custs[c].timeOut:endTime
           res[k][t] = road.index
         end
       #Travel from the end of the customer to the beginning of the next, then wait
       else
         #Trajectory from dest to orig of next customer (computed backward)
         loc = endDest
         t = custs[c].timeOut + sp.traveltime[pb.custs[c].dest,endDest]
         while t != custs[c].timeOut
           prev = sp.previous[pb.custs[c].dest,loc]
           road = find_edge(pb.network,prev,loc)
           for t2 in (t-road.attributes["l"]):(t-1)
             res[k][t2] = road.index
           end
           loc = prev
           t = t-road.attributes["l"]
         end

         #Wait before taking the next customer
         road = find_edge(pb.network,endDest,endDest)
         for t = (custs[c].timeOut + sp.traveltime[pb.custs[c].dest,endDest]):(endTime-1)
           res[k][t] = road.index
         end
       end
       endTime = custs[c].timeIn
       endDest = pb.custs[c].orig
     end
     #If no customer : wait
     if length(cpt[k]) == 0
       road = find_edge(pb.network,pb.taxis[k].initPos,pb.taxis[k].initPos)
       for t = 1:pb.nTime
         res[k][t] = road.index
       end
     #Travel from origin of taxi to first customer
     else
       endDest = pb.custs[cpt[k][1]].orig
       endTime = custs[cpt[k][1]].timeIn
       #Trajectory from origin of taxi to origin of first cust
       loc = endDest
       t = 1 + sp.traveltime[pb.taxis[k].initPos,endDest]
       while t != 1
         prev = sp.previous[pb.taxis[k].initPos,loc]
         road = find_edge(pb.network,prev,loc)
         for t2 in (t-road.attributes["l"]):(t-1)
           res[k][t2] = road.index
         end
         loc = prev
         t = t-road.attributes["l"]
       end

       #Wait before taking the next customer
       road = find_edge(pb.network,endDest,endDest)
       for t = (1 + sp.traveltime[pb.taxis[k].initPos,endDest]):(endTime-1)
         res[k][t] = road.index
       end
     end
   end
   return res
end

#Transform the list of each customer's assignment into a list of each taxi's
# list of assignments (ordered), plus a list of the non-taken customers
function customers_per_taxi(nTaxis::Int, custs::Array{CustomerAssignment,1})
  dict = Dict{Int64, Array{(Int64, Int64),1}}()
  notTaken = Int[]

  for (cust,temp) in enumerate(custs)
    taxi = temp.taxi
    time = temp.timeIn
    if taxi == 0
      push!(notTaken,cust)
    elseif haskey(dict,taxi)
      push!(dict[taxi],(cust,time))
    else
      dict[taxi] = [(cust,time)]
    end
  end

  result = Array(Array{Int,1},nTaxis)
  for k in 1:nTaxis
    result[k] = Int[]
  end

  for k in sort(collect(keys(dict)))
    for (c,t) in sort(dict[k],by=(x->x[2]))
      push!(result[k],c)
    end
  end
  return result, notTaken
end

function saveTaxiPb(pb::TaxiProblem, name::String; compress=false)
  save("Cities/Saved/$name.jld", "pb", pb, compress=compress)
end

function loadTaxiPb(name::String)
  pb = load("Cities/Saved/$name.jld","pb")
  return pb
end

#return the edge of the network graph corresponding to the origin and dest given
function find_edge(g::Network, i::Int, j::Int)
  for k in out_edges(i,g)
    if k.target == j
      return k
    end
  end
  throw(ArgumentError())
end

traveltime = e::Road -> (e.attributes["l"])
travelcost = e::Road -> (e.attributes["c"])




#Calculate the cost of the shortest path during Dijkstra
function Graphs.include_vertex!(visitor::PathCost, u, v, d)
  if u != v #Special case to handle..
    cost = 0.0
    for road in out_edges(u, visitor.n)
      if target(road, visitor.n) == v
        cost = travelcost(road)
      end
    end
    visitor.pathcost[visitor.i,v] = visitor.pathcost[visitor.i,u] + cost
  end
  return true
end

#Run an all-pair shortest path using dijkstra
function shortestPaths(n::Network)
  nLocs  = num_vertices(n)
  roadlength = AttributeEdgePropertyInspector{Int}("l")
  pathTime = Array(Int, (nLocs,nLocs))
  previous = Array(Int, (nLocs,nLocs))
  visit = PathCost(1,n, zeros(Float64, (nLocs,nLocs)))

  for i in 1:nLocs
    visit.i = i
    res = dijkstra_shortest_paths(n, roadlength, [i], visitor=visit)
    for j in 1:nLocs
      pathTime[i,j] = res.dists[j]
      previous[i,j] = res.parents[j]
    end
  end
  return ShortPaths(pathTime, visit.pathcost, previous)
end

#Compute the shortest paths of a city
function shortestPaths!(pb::TaxiProblem)
  pb.sp = shortestPaths(pb.network)
end
function shortestPaths!(c::InitialData)
  pb.sp = shortestPaths(pb.network)
end

#If the shortest paths have already been computed
spComputed(pb::TaxiProblem) = length(pb.sp.traveltime) > 0
spComputed(init::InitialData) = length(init.sp.traveltime) > 0

#Compute the table of the next locations on the shortest paths
function nextLoc(n::Network, sp::ShortPaths)
  nLocs = size(sp.previous,1)
  next = Array(Int, (nLocs,nLocs))
  for i in 1:nLocs, j in 1:nLocs
    if i == j
      next[i,i] = i
    else
      minTime = typemax(Int)
      mink = 0
      for e in out_edges(i,n)
        mink = (traveltime(e) + sp.traveltime[e.target,j] < minTime) ? e.target : mink
        minTime = (traveltime(e) + sp.traveltime[e.target,j] < minTime) ? traveltime(e) + sp.traveltime[e.target,j] : minTime
      end
      next[i,j] = mink
    end
  end
  return next
end

#Output the graph vizualization to pdf file
function drawNetwork(pb::TaxiProblem)
  stdin, proc = open(`neato -Tpdf -O`, "w")
  to_dot(pb.network,stdin)
  close(stdin)
end


#returns a random order on the customers
function randomOrder(pb::TaxiProblem)
  order = [1:length(pb.custs)]
  for i = length(order):-1:2
    j = rand(1:i)
    order[i], order[j] = order[j], order[i]
  end
  return order
end
