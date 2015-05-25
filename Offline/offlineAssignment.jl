#----------------------------------------
#-- Compute a solution, given an order on customers
#----------------------------------------

#Only return cost and list of assignment, given problem and order on customers
function offlineAssignment(pb::TaxiProblem, order::Vector{Int})
  #We need the shortestPaths
  tt = pb.sp.traveltime
  tc = pb.sp.travelcost
  road = edges(pb.network)
  taxis = Array( Vector{AssignedCustomer}, length(pb.taxis))
  for i in 1:length(pb.taxis)
    taxis[i] = AssignedCustomer[]
  end
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
          custs[end].tTake + tt[custs[end].desc.orig, custs[end].desc.dest] +
          tt[custs[end].desc.dest, c.orig] <= c.tmaxt &&
          custs[end].tTake + tt[custs[end].desc.orig, custs[end].desc.dest] +
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
          if custs[i].tTake + tt[custs[i].desc.orig, custs[i].desc.dest] +
             tt[custs[i].desc.dest, c.orig] <= c.tmaxt &&
             max(custs[i].tTake +
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
        tmin = max(c.tmin, custs[i-1].tTake +
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
      for j = (i-1):(-1):1
        custs[j].tSup = min(custs[j].tSup, custs[j+1].tSup -
          tt[custs[j].desc.orig, custs[j].desc.dest] -
          tt[custs[j].desc.dest, custs[j+1].desc.orig])
      end
      for j = (i+1):length(custs)
        custs[j].tTake = max(custs[j].tTake, custs[j-1].tTake +
          tt[custs[j-1].desc.orig, custs[j-1].desc.dest] +
          tt[custs[j-1].desc.dest, custs[j].desc.orig])
      end
    end
  end
  res = [CustomerAssignment(0,0,0) for i in 1:length(pb.custs)]
  for (k,custs) in enumerate(taxis)
    for c in custs
      res[c.desc.id] = CustomerAssignment(k,c.tTake,c.tTake +
       tt[c.desc.orig, c.desc.dest])
    end
  end
  return (solutionCost(pb,taxis),res)

end
