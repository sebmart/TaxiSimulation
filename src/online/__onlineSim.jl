#----------------------------------------
#--Run a problem the online way
#----------------------------------------


#The type of any online model
abstract OnlineModel

# Represent the actions chosen by the online algorithm for the current time-step
immutable OnlineActions
  moves::Array{Int,1} #Edge of each taxi
  actions::Array{CustomerAction, 1}
end

# Represent the new information provided to the online algorithms at each
#new time-step
immutable OnlineUpdate
  newCusts::Array{Customer, 1}
end


# Represent all the informations of the problem, excepted the customers
immutable InitialData
  network::Network
  taxis::Array{Taxi,1}
  nTime::Int
  waitingCost::Float64
  sp::ShortPaths
end

InitialData(pb::TaxiProblem) =
  InitialData(pb.network,pb.taxis,pb.nTime,pb.waitingCost,pb.sp)
  
function onlineSim(pb::TaxiProblem, model::OnlineModel; verbose=0, noCost=false)
  taxi = pb.taxis
  cust = pb.custs
  road = edges(pb.network)

  nTime = pb.nTime
  nTaxis = length(taxi)
  nCusts = length(cust)



  #Reordering the customers by tcall:
  custCall = Array(Array{Customer,1},nTime)
  for t in 1:nTime
    custCall[t] = Customer[]
  end

  for c in cust
    push!(custCall[c.tcall],c)
  end

  sol_t = [TaxiActions(Array(Int, nTime), Int[]) for k in 1:nTaxis]
  sol_c = Array(CustomerAssignment, nCusts)
  for c = 1:nCusts
    sol_c[c] = CustomerAssignment(0,0,0)
  end
  temp_ntc = [true for i in 1:nCusts]
  sol_ntc = Int[]
  for t in 1:pb.nTime
    if verbose == 1
      println("== Time $t")
    end
    upd = update!(model,OnlineUpdate(custCall[t]))
    for (k,e) in enumerate(upd.moves)
      sol_t[k].path[t] = e
      if verbose == 1
        println("Taxi $k: $(road[e].source)=>$(road[e].target)")
      end
    end
    for act in upd.actions
      if act.action == DROP
        sol_c[act.cust] = CustomerAssignment(act.taxi, sol_c[act.cust].timeIn, t)
        if verbose == 1
          println("Taxi $(act.taxi) takes customer $(act.cust)")
        end
      elseif act.action == TAKE
        sol_c[act.cust] = CustomerAssignment(act.taxi, t, 0)
        push!(sol_t[act.taxi].custs,act.cust)
        temp_ntc[act.cust] = false
        if verbose == 1
          println("Taxi $(act.taxi) drops customer $(act.cust)")
        end
      end
    end
  end

  for (i,t) in enumerate(temp_ntc)
    if t == true
      push!(sol_ntc,i)
    end
  end
  if noCost
    return TaxiSolution(sol_t,sol_ntc,sol_c,0.)
  else
    return TaxiSolution(sol_t,sol_ntc,sol_c,solutionCost(pb,sol_t,sol_c))
  end
end
