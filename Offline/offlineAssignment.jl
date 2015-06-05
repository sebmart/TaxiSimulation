#----------------------------------------
#-- Compute a solution, given an order on customers
#----------------------------------------



#Only return cost and list of assignment, given problem and order on customers
function offlineAssignmentQuick(pb::TaxiProblem, order::Vector{Int})
  #We need the shortestPaths
  tt = pb.sp.traveltime
  tc = pb.sp.travelcost
  taxis = [AssignedCustomer[] for i =1:length(pb.taxis)]

  for custNb in [order[i] for i in 1:length(pb.custs)]
    #-------------------------
    # Select the taxi to assign
    #-------------------------
    mincost = Inf
    mintaxi = 0
    position = 0
    c = pb.custs[custNb]

    #We test the new customer for each taxi
    for (id,custs) in enumerate(taxis)
      t = pb.taxis[id]
      #First Case: taking customer before all the others
      if 1 + tt[t.initPos, c.orig] <= c.tmaxt
        if length(custs) == 0 && #if no customer at all
          1 + tt[t.initPos, c.orig] + tt[c.orig,c.dest] <= pb.nTime
          cost = tc[t.initPos, c.orig] + tc[c.orig, c.dest] -
              (tt[t.initPos, c.orig] + tt[c.orig, c.dest]) * pb.waitingCost
          if cost < mincost
            mincost = cost
            position = 1
            mintaxi = t.id
          end

        #if there is a customer after
        elseif length(custs) != 0 && max(1 + tt[t.initPos, c.orig], c.tmin) +
            tt[c.orig, c.dest] + tt[c.dest, custs[1].desc.orig] <= custs[1].tSup
          cost = tc[t.initPos, c.orig] + tc[c.orig, c.dest] +
            tc[c.dest,custs[1].desc.orig] - tc[t.initPos, custs[1].desc.orig] -
            (tt[t.initPos, c.orig] + tt[c.orig, c.dest] +
               tt[c.dest,custs[1].desc.orig] - tt[t.initPos, custs[1].desc.orig]) * pb.waitingCost
          if cost < mincost
            mincost = cost
            position = 1
            mintaxi = t.id
          end
        end
      end

      #Second Case: taking customer after all the others
      if length(custs) > 0 &&
          custs[end].tInf + tt[custs[end].desc.orig, custs[end].desc.dest] +
          tt[custs[end].desc.dest, c.orig] <= c.tmaxt &&
          custs[end].tInf + tt[custs[end].desc.orig, custs[end].desc.dest] +
          tt[custs[end].desc.dest, c.orig] + tt[c.orig,c.dest] <= pb.nTime
        cost = tc[custs[end].desc.dest, c.orig] + tc[c.orig, c.dest] -
            (tt[custs[end].desc.dest, c.orig] + tt[c.orig, c.dest]) * pb.waitingCost
        if cost < mincost
          mincost = cost
          position = length(custs) + 1
          mintaxi = t.id
        end
      end

      #Last Case: taking customer in-between two customers
      if length(custs) > 2
        for i in 1:length(custs)-1
          if custs[i].tInf + tt[custs[i].desc.orig, custs[i].desc.dest] +
             tt[custs[i].desc.dest, c.orig] <= c.tmaxt &&
             max(custs[i].tInf +
             tt[custs[i].desc.orig, custs[i].desc.dest] +
               tt[custs[i].desc.dest, c.orig], c.tmin)+
                  tt[c.orig, c.dest] + tt[c.dest, custs[i+1].desc.orig] <= custs[i+1].tSup
            cost = tc[custs[i].desc.dest, c.orig] + tc[c.orig, c.dest] +
               tc[c.dest,custs[i+1].desc.orig] -
               tc[custs[i].desc.dest, custs[i+1].desc.orig] -
               (tt[custs[i].desc.dest, c.orig] + tc[c.orig, c.dest] +
                tt[c.dest, custs[i+1].desc.orig] -
                tt[custs[i].desc.dest, custs[i+1].desc.orig]) * pb.waitingCost
            if cost < mincost
              mincost = cost
              position = i+1
              mintaxi = t.id
            end
          end
        end
      end
    end

    #-------------------------
    # Insert customer into selected taxi's assignments
    #-------------------------
    i = position

    #If customer can be assigned
    if mintaxi != 0
      t = pb.taxis[mintaxi]
      custs = taxis[mintaxi]
      #If customer is to be inserted in first position
      if i == 1
        tmin = max(1 + tt[t.initPos, c.orig], c.tmin)
        if length(custs) == 0
          push!( custs, AssignedCustomer(c,tmin,min(c.tmaxt, pb.nTime - tt[c.orig,c.dest])))
        else
          tmaxt = min(c.tmaxt,custs[1].tSup - tt[c.orig,c.dest] -
           tt[c.dest,custs[1].desc.orig])
          insert!(custs, 1, AssignedCustomer(c, tmin, tmaxt))
        end
      else
        tmin = max(c.tmin, custs[i-1].tInf +
        tt[custs[i-1].desc.orig, custs[i-1].desc.dest] +
        tt[custs[i-1].desc.dest, c.orig])
        if i > length(custs) #If inserted in last position
          push!(custs, AssignedCustomer(c, tmin, min(c.tmaxt, pb.nTime - tt[c.orig,c.dest])))
        else
          tmaxt = min(c.tmaxt,custs[i].tSup - tt[c.orig,c.dest] -
            tt[c.dest,custs[i].desc.orig])
          insert!(custs, i, AssignedCustomer(c, tmin, tmaxt))
        end
      end

       #-------------------------
      # Update the freedom intervals of the other assigned customers
      #-------------------------
      for j = (i-1) :(-1):1
        custs[j].tSup = min(custs[j].tSup, custs[j+1].tSup -
          tt[custs[j].desc.orig, custs[j].desc.dest] -
          tt[custs[j].desc.dest, custs[j+1].desc.orig])
      end
      for j = (i+1) :length(custs)
        custs[j].tInf = max(custs[j].tInf, custs[j-1].tInf +
          tt[custs[j-1].desc.orig, custs[j-1].desc.dest] +
          tt[custs[j-1].desc.dest, custs[j].desc.orig])
      end
    end
  end

  return (solutionCost(pb,taxis), taxis)

end

#Return the full solution
function offlineAssignment(pb::TaxiProblem, order::Vector{Int})
  cost, sol = offlineAssignmentQuick(pb,order)

  return offlineAssignmentSolution(pb, sol, cost)
end

#Return the full solution, rule: pick up customers as early as possible
function offlineAssignmentSolution(pb::TaxiProblem, sol::Vector{Vector{AssignedCustomer}}, cost::Float64)
  nTaxis, nCusts = length(pb.taxis), length(pb.custs)
  actions = Array(TaxiActions, nTaxis)
  notTaken = trues(nCusts)

  for k in 1:nTaxis
    custs = CustomerAssignment[]
    for c in sol[k]
        push!( custs, CustomerAssignment(c.desc.id,c.tInf,c.tInf + pb.sp.traveltime[c.desc.orig, c.desc.dest]))
        notTaken[c.desc.id] = false
    end
    actions[k] = TaxiActions( taxi_path(pb,k,custs), custs)
  end
  return TaxiSolution(actions, notTaken, cost)
end

#Quickly compute the cost using assigned customers
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
      cost += (c.tInf - time - tt[pos,c.desc.orig])*pb.waitingCost
      time =  c.tInf + tt[c.desc.orig,c.desc.dest]
      pos = c.desc.dest
    end
    cost += (pb.nTime - time + 1)*pb.waitingCost
  end
  return cost
end

#Take an IntervalSolution and insert
