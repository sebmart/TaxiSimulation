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

#compute the cost using a different way (must be equivalent)
function solutionCost(pb::TaxiProblem, t::Vector{Vector{AssignedCustomer}})
  cost = 0.0
  tt = pb.sp.traveltime
  tc = pb.sp.travelcost
  for (k,custs) in enumerate(t)
    pos = pb.taxis[k].initPos
    time = 1
    for c in custs
      cost -= c.desc.price
      cost += tc[pos,c.desc.orig]
      cost += tc[c.desc.orig,c.desc.dest]
      cost += (c.tTake - time - tt[pos,c.desc.orig])*pb.waitingCost
      time =  c.tTake + tt[c.desc.orig,c.desc.dest]
      pos = c.desc.dest
    end
    cost += (pb.nTime - time + 1)*pb.waitingCost
  end
  return cost
end



#Reconstruct the complete path of the taxis from their assigned customers
#The rule is to wait near the next customers if the taxi has to wait
function taxi_paths(pb::TaxiProblem,
   custs::Array{CustomerAssignment,1}, cpt::Array{Array{Int,1},1})
   sp = pb.sp
   res = Array( Array{Road,1}, length(pb.taxis))
   for k in 1:length(pb.taxis)
     res[k] = Array(Road,pb.nTime)
     endTime = pb.nTime
     endDest = 0
     for i in length(cpt[k]):-1:1
       c = cpt[k][i]

       #Trajectory from origin to dest of customer (computed backward)
       loc = pb.custs[c].dest
       t = custs[c].timeOut

       while t != custs[c].timeIn
         prev = sp.previous[pb.custs[c].orig,loc]
         for t2 in (t - pb.roadTime[prev,loc] ):(t-1)
           res[k][t2] = Road(prev,loc)
         end
         t = t-pb.roadTime[prev,loc]
         loc = prev
       end

       #After last customer: stays at the same place
       if i == length(cpt[k])
         for t = custs[c].timeOut:endTime
           res[k][t] = Road(pb.custs[c].dest,pb.custs[c].dest)
         end
       #Travel from the end of the customer to the beginning of the next, then wait
       else
         #Trajectory from dest to orig of next customer (computed backward)
         loc = endDest
         t = custs[c].timeOut + sp.traveltime[pb.custs[c].dest,endDest]
         while t != custs[c].timeOut
           prev = sp.previous[pb.custs[c].dest,loc]
           for t2 in (t -  pb.roadTime[prev,loc] ):(t-1)
             res[k][t2] = Road(prev, loc)
           end
           t = t - pb.roadTime[prev,loc]
           loc = prev
         end

         #Wait before taking the next customer
         for t = (custs[c].timeOut + sp.traveltime[pb.custs[c].dest, endDest] ):(endTime-1)
           res[k][t] = Road(endDest,endDest)
         end
       end
       endTime = custs[c].timeIn
       endDest = pb.custs[c].orig
     end
     #If no customer : wait
     if length(cpt[k]) == 0
       for t = 1:pb.nTime
         res[k][t] = Road(pb.taxis[k].initPos, pb.taxis[k].initPos)
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
         for t2 in (t - pb.roadTime[prev, loc] ):(t-1)
           res[k][t2] = Road(prev, loc)
         end
         t   = t - pb.roadTime[prev, loc]
         loc = prev
       end

       #Wait before taking the next customer
       for t = (1 + sp.traveltime[pb.taxis[k].initPos, endDest] ):(endTime-1)
         res[k][t] = Road(endDest, endDest)
       end
     end
   end
   return res
end

#Transform the list of each customer's assignment into a list of each taxi's
# list of assignments (ordered), plus a list of the non-taken customers
function customers_per_taxi(nTaxis::Int, custs::Array{CustomerAssignment,1})
  taxis = [(Int64, Int64)[] for i in 1:nTaxis]
  notTaken = Int64[]

  for (cust,temp) in enumerate(custs)
    taxi = temp.taxi
    time = temp.timeIn
    if taxi == 0
      push!(notTaken,cust)
    else
      push!(taxis[taxi], (cust,time))
    end
  end

  result = [Int64[] for i in 1:nTaxis]

  for k in 1:nTaxis
    for (c,t) in sort(taxis[k], by = (x->x[2]))
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
