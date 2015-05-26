#----------------------------------------
#-- Useful functions to deal with TaxiProblem and TaxiSolution objects
#----------------------------------------

#Compute the cost of a solution
function solutionCost(pb::TaxiProblem, taxis::Array{TaxiActions, 1},
                                       custs::Array{CustomerAssignment, 1})
  cost = 0.

  #price paid by customers
  for (id,c) in enumerate(custs)
    if c.taxi != 0
      cost -= pb.custs[id].price
    end
  end
  for (k,t) in enumerate(taxis)
    previousRoad = Road(0,0)
    for r in t.path
      if src(r) == dst(r)
        cost += pb.waitingCost
      elseif r != previousRoad
        cost += pb.roadCost[ src(r), dst(r)] #cost of taking the road
      end
      previousRoad = r
    end
  end
  return cost
end




#Reconstruct the complete path of a taxis from their assigned customers (in order)
#The rule is to wait near the next customers if the taxi has to wait
function taxi_path(pb::TaxiProblem, id_taxi::Int, custs::Array{CustomerAssignment,1})
   sp = pb.sp
   path = Array(Road,pb.nTime)
   endTime = pb.nTime
   endDest = 0
   for i in length(custs):-1:1
     c = custs[i]

     #Trajectory from origin to dest of customer (computed backward)
     loc = pb.custs[c.id].dest
     t = c.timeOut

     while t != c.timeIn
       prev = sp.previous[pb.custs[c.id].orig,loc]
       for t2 in (t - pb.roadTime[prev,loc] ):(t-1)
         path[t2] = Road(prev,loc)
       end
       t = t-pb.roadTime[prev,loc]
       loc = prev
     end

     #After last customer: stays at the same place
     if i == length(custs)
       for t = c.timeOut:endTime
         path[t] = Road(pb.custs[c.id].dest,pb.custs[c.id].dest)
       end
     #Travel from the end of the customer to the beginning of the next, then wait
     else
       #Trajectory from dest to orig of next customer (computed backward)
       loc = endDest
       t = c.timeOut + sp.traveltime[pb.custs[c.id].dest,endDest]
       while t != c.timeOut
         prev = sp.previous[pb.custs[c.id].dest,loc]
         for t2 in (t -  pb.roadTime[prev,loc] ):(t-1)
           path[t2] = Road(prev, loc)
         end
         t = t - pb.roadTime[prev,loc]
         loc = prev
       end

       #Wait before taking the next customer
       for t = (c.timeOut + sp.traveltime[pb.custs[c.id].dest, endDest] ):(endTime-1)
         path[t] = Road(endDest,endDest)
       end
     end
     endTime = c.timeIn
     endDest = pb.custs[c.id].orig
   end
   #If no customer : wait
   if length(custs) == 0
     for t = 1:pb.nTime
       path[t] = Road(pb.taxis[id_taxi].initPos, pb.taxis[id_taxi].initPos)
     end
   #Travel from origin of taxi to first customer
   else
     endDest = pb.custs[custs[1].id].orig
     endTime = custs[1].timeIn
     #Trajectory from origin of taxi to origin of first cust
     loc = endDest
     t = 1 + sp.traveltime[pb.taxis[id_taxi].initPos,endDest]
     while t != 1
       prev = sp.previous[pb.taxis[id_taxi].initPos,loc]
       for t2 in (t - pb.roadTime[prev, loc] ):(t-1)
         path[t2] = Road(prev, loc)
       end
       t   = t - pb.roadTime[prev, loc]
       loc = prev
     end

     #Wait before taking the next customer
     for t = (1 + sp.traveltime[pb.taxis[id_taxi].initPos, endDest] ):(endTime-1)
       path[t] = Road(endDest, endDest)
     end
   end
   return path
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
