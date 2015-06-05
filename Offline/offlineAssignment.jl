#----------------------------------------
#-- Compute a solution, given an order on customers
#----------------------------------------



#Only return cost and list of assignment, given problem and order on customers
function offlineAssignmentQuick(pb::TaxiProblem, order::Vector{Int})
  nTaxis, nCusts = length(pb.taxis), length(pb.custs)

  custs = [CustomerAssignment[] for k in 1:nTaxis]
  sol = IntervalSolution(custs, trues( length(pb.custs)), 0.)
  for i in 1:nCusts
    c = order[i]
    insertCustomer!(pb, sol, c)
  end
  sol.cost = solutionCost(pb,sol.custs)
  return sol
end

#Return the full solution
offlineAssignment(pb::TaxiProblem, order::Vector{Int}) =
  TaxiSolution( offlineAssignmentQuick(pb, order))



#Take an IntervalSolution and insert a not-taken customer
function insertCustomer!(pb::TaxiProblem, sol::IntervalSolution, cId::Int)

  #-------------------------
  # Select the taxi to assign
  #-------------------------
  if !sol.notTaken[cId]
    error("Customer already inserted")
  end
  c = pb.custs[cId]
  cDesc = pb.custs
  mincost = Inf
  mintaxi = 0
  position = 0
  #We need the shortestPaths
  tt = pb.sp.traveltime
  tc = pb.sp.travelcost

  #We test the new customer for each taxi
  for (k,custs) in enumerate(sol.custs)
    initPos = pb.taxis[k].initPos
    #First Case: taking customer before all the others
    if 1 + tt[initPos, c.orig] <= c.tmaxt
      if length(custs) == 0 && #if no customer at all
        1 + tt[initPos, c.orig] + tt[c.orig,c.dest] <= pb.nTime
        cost = tc[initPos, c.orig] + tc[c.orig, c.dest] -
            (tt[initPos, c.orig] + tt[c.orig, c.dest]) * pb.waitingCost
        if cost < mincost
          mincost = cost
          position = 1
          mintaxi = k
        end

      #if there is a customer after
      elseif length(custs) != 0
        c1 = cDesc[custs[1].id]

        if max(1 + tt[initPos, c.orig], c.tmin) +
          tt[c.orig, c.dest] + tt[c.dest, c1.orig] <= custs[1].tSup

          cost = tc[initPos, c.orig] + tc[c.orig, c.dest] +
            tc[c.dest,c1.orig] - tc[initPos, c1.orig] -
            (tt[initPos, c.orig] + tt[c.orig, c.dest] +
               tt[c.dest,c1.orig] - tt[initPos, c1.orig]) * pb.waitingCost
          if cost < mincost
            mincost = cost
            position = 1
            mintaxi = k
          end
        end
      end
    end

    #Second Case: taking customer after all the others
    if length(custs) > 0
      cLast = cDesc[custs[end].id]
      if custs[end].tInf + tt[cLast.orig, cLast.dest] +
        tt[cLast.dest, c.orig] <= c.tmaxt &&
        custs[end].tInf + tt[cLast.orig, cLast.dest] +
        tt[cLast.dest, c.orig] + tt[c.orig,c.dest] <= pb.nTime

        cost = tc[cLast.dest, c.orig] + tc[c.orig, c.dest] -
          (tt[cLast.dest, c.orig] + tt[c.orig, c.dest]) * pb.waitingCost
        if cost < mincost
          mincost = cost
          position = length(custs) + 1
          mintaxi = k
        end
      end
    end

    #Last Case: taking customer in-between two customers
    if length(custs) > 2
      for i in 1:length(custs)-1
        ci = cDesc[custs[i].id]
        cip1 = cDesc[custs[i+1].id]
        if custs[i].tInf + tt[ci.orig, ci.dest] + tt[ci.dest, c.orig] <= c.tmaxt &&
           max(custs[i].tInf + tt[ci.orig, ci.dest] + tt[ci.dest, c.orig], c.tmin)+
                tt[c.orig, c.dest] + tt[c.dest, cip1.orig] <= custs[i+1].tSup
          cost = tc[ci.dest, c.orig] + tc[c.orig, c.dest] +
             tc[c.dest,ccip1.orig] -  tc[ci.dest, cip1.orig] -
             (tt[ci.dest, c.orig] + tc[c.orig, c.dest] +
              tt[c.dest, cip1.orig] - tt[ci.dest, cip1.orig]) * pb.waitingCost
          if cost < mincost
            mincost = cost
            position = i+1
            mintaxi = k
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
    custs = sol.custs[mintaxi]
    #If customer is to be inserted in first position
    if i == 1
      tmin = max(1 + tt[t.initPos, c.orig], c.tmin)
      if length(custs) == 0
        push!( custs, AssignedCustomer(c.id, tmin, min(c.tmaxt, pb.nTime - tt[c.orig,c.dest])))
      else
        tmaxt = min(c.tmaxt,custs[1].tSup - tt[c.orig,c.dest] -
         tt[c.dest,cDesc[custs[1].id].orig])
        insert!(custs, 1, AssignedCustomer(c.id, tmin, tmaxt))
      end
    else
      tmin = max(c.tmin, custs[i-1].tInf +
      tt[cDesc[custs[i-1].id].orig, cDesc[custs[i-1].id].dest] +
      tt[cDesc[custs[i-1].id].dest, c.orig])
      if i > length(custs) #If inserted in last position
        push!(custs, AssignedCustomer(c.id, tmin, min(c.tmaxt, pb.nTime - tt[c.orig,c.dest])))
      else
        tmaxt = min(c.tmaxt,custs[i].tSup - tt[c.orig,c.dest] -
          tt[c.dest,cDesc[custs[i].id].orig])
        insert!(custs, i, AssignedCustomer(c.id, tmin, tmaxt))
      end
    end

     #-------------------------
    # Update the freedom intervals of the other assigned customers
    #-------------------------
    for j = (i-1) :(-1):1
      custs[j].tSup = min(custs[j].tSup, custs[j+1].tSup -
        tt[cDesc[custs[j].id].orig, cDesc[custs[j].id].dest] -
        tt[cDesc[custs[j].id].dest, cDesc[custs[j+1].id].orig])
    end
    for j = (i+1) :length(custs)
      custs[j].tInf = max(custs[j].tInf, custs[j-1].tInf +
        tt[cDesc[custs[j-1].id].orig, cDesc[custs[j-1].id].dest] +
        tt[cDesc[custs[j-1].id].dest, cDesc[custs[j].id].orig])
    end
    sol.notTaken[cId] = false
  end
  return mincost, mintaxi, position
end
