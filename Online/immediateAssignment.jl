#----------------------------------------
#-- Immediate Assignment heuristic:
#-- When a customer calls, a taxi is immediately assigned
#----------------------------------------

#Represent all the information about a taxi
type TaxiSituation
  id::Int
  custs::Array{AssignedCustomer, 1}
  road::Int #Road the taxi is currently crossing
  timeLeft::Int #time left for taxi to finish the road
end

type ImmediateAssignment <: OnlineModel
  pb::InitialData

  nextLoc::Array{Int,2}
  tCurrent::Int
  taxis::Array{TaxiSituation,1}
  nTaxis::Int

  #Initialize everything
  function ImmediateAssignment(pb::InitialData)
    ia = new()

    #We need the shortestPaths
    if !spComputed(pb)
      shortestPaths!(pb)
    end

    ia.pb = pb
    ia.nextLoc = nextLoc(pb.network,pb.sp)
    ia.nTaxis = length(pb.taxis)
    ia.tCurrent = 0
    ia.taxis = [
    TaxiSituation(k, AssignedCustomer[],find_edge(pb.network,
    pb.taxis[k].initPos, pb.taxis[k].initPos).index,0) for k in 1:(ia.nTaxis)]
    return ia
  end
end


ImmediateAssignment(pb::TaxiProblem) = ImmediateAssignment(InitialData(pb))


#Called at each timestep of online simulation
function update!(ia::ImmediateAssignment, upd::OnlineUpdate)
  ia.tCurrent += 1
  #-------------------------
  # Assign each new customer
  #-------------------------
  for c in upd.newCusts
    assignCust!(ia,c)
  end

  #-------------------------
  # Compute and return the actions of time t
  #-------------------------
  actions = CustomerAction[]
  moves = Array(Int, ia.nTaxis)
  for k in 1:(ia.nTaxis)
    actionList = updateTaxi!(ia,ia.taxis[k])
    append!(actions,actionList)
    moves[k] = ia.taxis[k].road
  end

  return(OnlineActions(moves,actions))

end

#Assign a new customer to a taxi (or not, then return false)
function assignCust!(ia::ImmediateAssignment, c::Customer)
  tt = ia.pb.sp.traveltime
  tc = ia.pb.sp.travelcost
  road = edges(ia.pb.network)

  #-------------------------
  # Select the taxi to assign
  #-------------------------
  mincost = Inf
  mintaxi = 0
  position = 0

  for t in ia.taxis

    #First Case: taking customer before all the others
    if ia.tCurrent + t.timeLeft + tt[road[t.road].target, c.orig] <= c.tmaxt
      if length(t.custs) == 0 && #if no customer at all
          ia.tCurrent + t.timeLeft + tt[road[t.road].target, c.orig] + tt[c.orig,c.dest] <= ia.pb.nTime
        cost = tc[road[t.road].target, c.orig] + tc[c.orig, c.dest] -
            (tt[road[t.road].target, c.orig] + tt[c.orig, c.dest]) * ia.pb.waitingCost
        if cost < mincost
          mincost = cost
          position = 1
          mintaxi = t.id
        end

      #if customers after
      elseif length(t.custs) != 0 && max(ia.tCurrent + t.timeLeft + tt[road[t.road].target, c.orig], c.tmin) +
              tt[c.orig, c.dest] + tt[c.dest, t.custs[1].desc.orig] <= t.custs[1].tSup
        cost = tc[road[t.road].target, c.orig] + tc[c.orig, c.dest] +
  tc[c.dest,t.custs[1].desc.orig] - tc[road[t.road].target, t.custs[1].desc.orig] -
              (tt[road[t.road].target, c.orig] + tt[c.orig, c.dest] +
  tt[c.dest,t.custs[1].desc.orig] - tt[road[t.road].target, t.custs[1].desc.orig]) *
   ia.pb.waitingCost
        if cost < mincost
          mincost = cost
          position = 1
          mintaxi = t.id
        end
      end
    end

    #Second Case: taking customer after all the others
    if length(t.custs) > 0 &&
        t.custs[end].tTake + tt[t.custs[end].desc.orig, t.custs[end].desc.dest] +
        tt[t.custs[end].desc.dest, c.orig] <= c.tmaxt &&
        t.custs[end].tTake + tt[t.custs[end].desc.orig, t.custs[end].desc.dest] +
        tt[t.custs[end].desc.dest, c.orig] + tt[c.orig,c.dest] <= ia.pb.nTime
      cost = tc[t.custs[end].desc.dest, c.orig] + tc[c.orig, c.dest] -
          (tt[t.custs[end].desc.dest, c.orig] + tt[c.orig, c.dest]) * ia.pb.waitingCost
      if cost < mincost
        mincost = cost
        position = length(t.custs) + 1
        mintaxi = t.id
      end
    end

    #Last Case: taking customer in-between two customers
    if length(t.custs) > 2
      for i in 1:length(t.custs)-1
        if t.custs[i].tTake + tt[t.custs[i].desc.orig, t.custs[i].desc.dest] +
           tt[t.custs[i].desc.dest, c.orig] <= c.tmaxt &&
           max(t.custs[i].tTake +
           tt[t.custs[i].desc.orig, t.custs[i].desc.dest] +
             tt[t.custs[i].desc.dest, c.orig], c.tmin)+
                tt[c.orig, c.dest] + tt[c.dest, t.custs[i+1].desc.orig] <= t.custs[i+1].tSup
          cost = tc[t.custs[i].desc.dest, c.orig] + tc[c.orig, c.dest] +
             tc[c.dest,t.custs[i+1].desc.orig] -
             tc[t.custs[i].desc.dest, t.custs[i+1].desc.orig] -
             (tt[t.custs[i].desc.dest, c.orig] + tc[c.orig, c.dest] +
              tt[c.dest, t.custs[i+1].desc.orig] -
              tt[t.custs[i].desc.dest, t.custs[i+1].desc.orig]) * ia.pb.waitingCost
          if cost < mincost
            mincost = cost
            position = i+1
            mintaxi = t.id
          end
        end
      end
    end
  end
  i = position
  #-------------------------
  # Insert customer into selected taxi's assignments
  #-------------------------
  #If customer cannot be assigned
  if mintaxi == 0
      return false
  else
    t = ia.taxis[mintaxi]
    #If customer is to be inserted in first position
    if i == 1
      tmin = max(ia.tCurrent + t.timeLeft + tt[road[t.road].target, c.orig],
                 c.tmin)
      if length(t.custs) == 0
        push!(t.custs,AssignedCustomer(c,tmin,min(c.tmaxt, ia.pb.nTime - tt[c.orig,c.dest])))
      else
        tmaxt = min(c.tmaxt,t.custs[1].tSup - tt[c.orig,c.dest] -
         tt[c.dest,t.custs[1].desc.orig])
        insert!(t.custs, 1, AssignedCustomer(c, tmin, tmaxt))
      end
    else
      tmin = max(c.tmin, t.custs[i-1].tTake +
      tt[t.custs[i-1].desc.orig, t.custs[i-1].desc.dest] +
      tt[t.custs[i-1].desc.dest, c.orig])
      if i > length(t.custs) #If inserted in last position
        push!(t.custs, AssignedCustomer(c, tmin, min(c.tmaxt, ia.pb.nTime - tt[c.orig,c.dest])))
      else
        tmaxt = min(c.tmaxt,t.custs[i].tSup - tt[c.orig,c.dest] -
          tt[c.dest,t.custs[i].desc.orig])
        insert!(t.custs, i, AssignedCustomer(c, tmin, tmaxt))
      end
    end
  end

  #-------------------------
  # Update the freedom intervals of the other assigned customers
  #-------------------------
  for j = (i-1):(-1):1
    t.custs[j].tSup = min(t.custs[j].tSup, t.custs[j+1].tSup -
      tt[t.custs[j].desc.orig, t.custs[j].desc.dest] -
      tt[t.custs[j].desc.dest, t.custs[j+1].desc.orig])
  end
  for j = (i+1):length(t.custs)
    t.custs[j].tTake = max(t.custs[j].tTake, t.custs[j-1].tTake +
      tt[t.custs[j-1].desc.orig, t.custs[j-1].desc.dest] +
      tt[t.custs[j-1].desc.dest, t.custs[j].desc.orig])
  end

end

#Compute the actions of the taxis for the timestep
function updateTaxi!(ia::ImmediateAssignment, t::TaxiSituation)
  n =  ia.pb.network
  road = edges(n)

  #If travelling on a link
  if t.timeLeft > 0
    t.timeLeft -= 1
    return CustomerAction[]
  else
    #First compute actions related to customers
    actions = CustomerAction[]

    #If customer in taxi and at destination: drop it
    if length(t.custs) > 0 && t.custs[1].tTake <= ia.tCurrent &&
            road[t.road].target == t.custs[1].desc.dest
      push!(actions, CustomerAction(t.custs[1].desc.id, DROP, t.id))
      splice!(t.custs, 1)

    end
    #If time to take new customer
    if length(t.custs) > 0 && t.custs[1].tTake == ia.tCurrent
      if road[t.road].target != t.custs[1].desc.orig
        throw(ErrorException("Taxi supposed to take customer but not at location"))
      end
      push!(actions, CustomerAction(t.custs[1].desc.id, TAKE, t.id))
    end

    #If nothing to do: wait at the same place
    if length(t.custs) == 0
      t.road = find_edge(n, road[t.road].target, road[t.road].target).index

    #If customer in taxi and not at destination, moves one link toward dest
    elseif t.custs[1].tTake <= ia.tCurrent
      t.road = find_edge(n,road[t.road].target,
                      ia.nextLoc[road[t.road].target, t.custs[1].desc.dest]).index

    #Wait the last minute to go to next customer
  elseif ia.tCurrent + ia.pb.sp.traveltime[road[t.road].target,t.custs[1].desc.orig] <
                                                              t.custs[1].tTake
      t.road = find_edge(n, road[t.road].target, road[t.road].target).index

    #Moves the next customer's origin
    else
      t.road = find_edge(n, road[t.road].target,
                      ia.nextLoc[road[t.road].target, t.custs[1].desc.orig]).index
    end
    t.timeLeft = traveltime(road[t.road]) - 1
    return actions
  end
end
