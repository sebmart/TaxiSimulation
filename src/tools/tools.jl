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
    totaltime = 0.
    for (i,(time,road)) in enumerate(t.path)
      cost += pb.roadCost[ src(road), dst(road)]
      totaltime += pb.roadTime[ src(road), dst(road)]
    end
    cost += pb.waitingCost * totaltime
  end
  return cost
end

#Quickly compute the cost using assigned customers
function solutionCost(pb::TaxiProblem, t::Vector{Vector{AssignedCustomer}})
  cost = 0.0
  tt = pb.sp.traveltime
  tc = pb.sp.travelcost
  for (k,custs) in enumerate(t)
    pos = pb.taxis[k].initPos
    time = 0
    for c in custs
      c1 = pb.custs[c.id]
      cost -= c1.price
      cost += tc[pos,c1.orig]
      cost += tc[c1.orig,c1.dest]
      cost += (c.tInf - time - tt[pos,c1.orig])*pb.waitingCost
      time =  c.tInf + tt[c1.orig,c1.dest]
      pos = c1.dest
    end
    cost += (pb.nTime - time)*pb.waitingCost
  end
  return cost
end

#test interval solution, if it is indeed feasible
function testSolution(pb::TaxiProblem, sol::IntervalSolution)
  custs = pb.custs
  nt = trues(length(pb.custs))
  tt = pb.sp.traveltime

  for k = 1:length(pb.taxis)
    list = sol.custs[k]
    if length(list) >= 1
      list[1].tInf = max(custs[list[1].id].tmin, tt[pb.taxis[k].initPos, pb.custs[list[1].id].orig])
      list[end].tSup = custs[list[end].id].tmaxt
      if nt[list[1].id]
          nt[list[1].id] = false
      else
          error("Customer $(list[1].id) picked-up twice")
      end
    end
    for i = 2:(length(list))
      list[i].tInf = max(pb.custs[list[i].id].tmin, list[i-1].tInf+
      tt[pb.custs[list[i-1].id].orig, pb.custs[list[i-1].id].dest]+
      tt[pb.custs[list[i-1].id].dest, pb.custs[list[i].id].orig])
      if nt[list[i].id]
          nt[list[i].id] = false
      else
          error("Customer $(list[i].id) picked-up twice")
      end
    end
    for i = (length(list) - 1):(-1):1
      list[i].tSup = min(pb.custs[list[i].id].tmaxt, list[i+1].tSup-
      tt[pb.custs[list[i].id].orig,pb.custs[list[i].id].dest]-
      tt[pb.custs[list[i].id].dest, pb.custs[list[i+1].id].orig])
    end
    for c in list
      if c.tInf > c.tSup
        error("Solution Infeasible for taxi $k")
      end
    end
  end
  if sol.notTaken != nt
    error("NotTaken is not correct")
  end
  cost = solutionCost(pb,sol.custs)
  if abs(sol.cost - cost) > 1e-5
      error("Cost is not correct (1e-5 precision)")
  end
  println("all good!")
end


#expand the time windows of an interval solution
function expandWindows!(pb::TaxiProblem, sol::IntervalSolution)
  custs = pb.custs
  tt = pb.sp.traveltime

  for k = 1:length(pb.taxis)
    list = sol.custs[k]
    if length(list) >= 1
      list[1].tInf = max(custs[list[1].id].tmin, tt[pb.taxis[k].initPos, pb.custs[list[1].id].orig])
      list[end].tSup = custs[list[end].id].tmaxt
    end
    for i = 2:(length(list))
      list[i].tInf = max(pb.custs[list[i].id].tmin, list[i-1].tInf+
      tt[pb.custs[list[i-1].id].orig, pb.custs[list[i-1].id].dest]+
      tt[pb.custs[list[i-1].id].dest, pb.custs[list[i].id].orig])
    end
    for i = (length(list) - 1):(-1):1
      list[i].tSup = min(pb.custs[list[i].id].tmaxt, list[i+1].tSup-
      tt[pb.custs[list[i].id].orig,pb.custs[list[i].id].dest]-
      tt[pb.custs[list[i].id].dest, pb.custs[list[i+1].id].orig])
    end
    #quick check..
    for c in list
      if c.tInf > c.tSup
        error("Solution Infeasible for taxi $k")
      end
    end
  end
end

#Reconstruct the complete path of a taxis from their assigned customers (in order)
#The rule is to wait before going to the next customers if the taxi has to wait
function taxi_path(pb::TaxiProblem, id_taxi::Int, custs::Array{CustomerAssignment,1})
   sp = pb.sp
   tt = sp.traveltime
   roadTime = pb.roadTime
   path = Tuple{Float64,Road}[]
   endTime = pb.nTime
   endDest = 0
   for i in length(custs):-1:1
     c = custs[i]

     #Travel from the end of the customer to the beginning of the next, then wait
     if i != length(custs)
       #Trajectory from dest to orig of next customer (computed backward)
       loc = endDest
       t = endTime
       while loc != pb.custs[c.id].dest
         prev = sp.previous[pb.custs[c.id].dest,loc]
         push!(path, (t - roadTime[prev,loc], Road(prev,loc)))
         t = t - roadTime[prev,loc]
         loc = prev
       end
       #To make sure that the times are the same:
       path[end] = (endTime - tt[pb.custs[c.id].dest, endDest], path[end][2])
     end

     #Trajectory from origin to dest of customer (computed backward)
     loc = pb.custs[c.id].dest
     t = c.timeOut

     while loc != pb.custs[c.id].orig
       prev = sp.previous[pb.custs[c.id].orig,loc]
       push!(path, (t - roadTime[prev,loc], Road(prev,loc)))
       t = t- roadTime[prev,loc]
       loc = prev
     end
     #To make sure that the times are the same:
     path[end] = (c.timeIn, path[end][2])

     endTime = c.timeIn
     endDest = pb.custs[c.id].orig
   end
   #Travel from origin of taxi to first customer
   if length(custs) != 0
     #Trajectory from origin of taxi to origin of first cust
     loc = pb.custs[custs[1].id].orig
     t = custs[1].timeIn
     while loc != pb.taxis[id_taxi].initPos
       prev = sp.previous[pb.taxis[id_taxi].initPos,loc]
       push!(path, (t - roadTime[prev,loc], Road(prev,loc)))
       t   = t - roadTime[prev, loc]
       loc = prev
     end
     #To make sure that the times are the same:
     path[end] = (max(0.0,custs[1].timeIn - tt[pb.taxis[id_taxi].initPos,pb.custs[custs[1].id].orig]), path[end][2])
     #reverse the list
     reverse!(path)
   end
   return path
end

function saveTaxiPb(pb::TaxiProblem, name::String; compress=false)
  save("../.cache/$name.jld", "pb", pb, compress=compress)
end

function loadTaxiPb(name::String)
  pb = load("../.cache/$name.jld","pb")
  return pb
end

#Output the graph vizualization to pdf file (see GraphViz library)
function drawNetwork(pb::TaxiProblem, name::String = "graph")
  stdin, proc = open(`neato -Tpdf -o ../outputs/$(name).pdf`, "w")
  to_dot(pb,stdin)
  close(stdin)
end

#Output dotfile
function dotFile(pb::TaxiProblem, name::String = "graph")
  open("../outputs/$name.dot","w") do f
    to_dot(pb, f)
  end
end

#Write the graph in dot format
function to_dot(pb::TaxiProblem, stream::IO)
    write(stream, "digraph  citygraph {\n")
    for i in vertices(pb.network), j in out_neighbors(pb.network,i)
      write(stream, "$i -> $j\n")
    end
    write(stream, "}\n")
    return stream
end

#returns a random order on the customers
function randomOrder(n::Int)
  order = collect(1:n)
  for i = n:-1:2
    j = rand(1:i)
    order[i], order[j] = order[j], order[i]
  end
  return order
end
randomOrder(pb::TaxiProblem) = randomOrder(length(pb.custs))

#Return customers that can be taken before other customers
function customersCompatibility(pb::TaxiProblem)
  cust = pb.custs
  tt = pb.sp.traveltime
  nCusts = length(cust)
  pCusts = Array( Array{Int,1}, nCusts)
  nextCusts = Array( Array{Tuple{Int,Int},1},nCusts)
  for i=1:nCusts
    nextCusts[i] = Tuple{Int,Int}[]
  end

  for (i,c1) in enumerate(cust)
    pCusts[i]= filter(c2->c2 != i && cust[c2].tmin +
    tt[cust[c2].orig, cust[c2].dest] + tt[cust[c2].dest, c1.orig] <= c1.tmaxt,
    collect(1:nCusts))
    for (id,j) in enumerate(pCusts[i])
      push!(nextCusts[j], (i,id))
    end
  end
  return pCusts, nextCusts
end

#Given a solution, returns the time-windows
function IntervalSolution(pb::TaxiProblem, sol::TaxiSolution)
  res = Array(Vector{AssignedCustomer}, length(pb.taxis))
  nt = trues(length(pb.custs))
  for k =1:length(sol.taxis)
    res[k] = [AssignedCustomer(c.id, pb.custs[c.id].tmin, pb.custs[c.id].tmaxt) for c in sol.taxis[k].custs]
  end
  tt = pb.sp.traveltime

  for (k,cust) = enumerate(res)
    if length(cust) >= 1
      cust[1].tInf = max(cust[1].tInf, tt[pb.taxis[k].initPos, pb.custs[cust[1].id].orig])
      nt[cust[1].id] = false
    end
    for i = 2:(length(cust))
      cust[i].tInf = max(cust[i].tInf, cust[i-1].tInf+
      tt[pb.custs[cust[i-1].id].orig, pb.custs[cust[i-1].id].dest]+
      tt[pb.custs[cust[i-1].id].dest, pb.custs[cust[i].id].orig])
      nt[cust[i].id] = false
    end
    for i = (length(cust) - 1):(-1):1
      cust[i].tSup = min(cust[i].tSup, cust[i+1].tSup-
      tt[pb.custs[cust[i].id].orig,pb.custs[cust[i].id].dest]-
      tt[pb.custs[cust[i].id].dest, pb.custs[cust[i+1].id].orig])
    end
    for c in cust
      if c.tSup < c.tInf
        error("Solution not feasible")
      end
    end
  end
  return IntervalSolution(res, nt, solutionCost(pb,res))
end

#Transform Interval solution into regular solution
#rule: pick up customers as early as possible
function TaxiSolution(pb::TaxiProblem, sol::IntervalSolution)

  nTaxis, nCusts = length(pb.taxis), length(pb.custs)
  actions = Array(TaxiActions, nTaxis)

  for k in 1:nTaxis
    custs = CustomerAssignment[]
    for c in sol.custs[k]
        push!( custs, CustomerAssignment(c.id,c.tInf,c.tInf + pb.sp.traveltime[pb.custs[c.id].orig, pb.custs[c.id].dest]))
    end
    actions[k] = TaxiActions( taxi_path(pb,k,custs), custs)
  end
  return TaxiSolution(actions, sol.notTaken, sol.cost)

end

TaxiSolution() = TaxiSolution(TaxiActions[],trues(0),0.0)

IntervalSolution(pb::TaxiProblem) =
IntervalSolution([CustomerAssignment[] for k in 1:length(pb.taxis)],
trues(length(pb.custs)), -pb.nTime * length(pb.taxis) * pb.waitingCost)

copySolution(sol::IntervalSolution) = IntervalSolution( deepcopy(sol.custs), copy(sol.notTaken), sol.cost)

toInt(x::Float64) = round(Int,x)
