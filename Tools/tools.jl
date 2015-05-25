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
