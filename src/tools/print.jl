#----------------------------------------
#-- Print a solution
#----------------------------------------

function printSolution(s::TaxiSolution, io::IO = STDOUT; verbose=1)
  if verbose == 0
    printShort(s, io)
  elseif verbose == 1
    printMedium(s, io)
  else
    printLong(s, io)
  end

  nt = collect(1:length(s.notTaken))[s.notTaken]
  if length(nt) != 0
    println(io, "=== NOT TAKEN")
    println(io, "==========================")
    if length(nt) == 1
      print(io, "Customer $(nt[1])")
    else
      print(io, "Customers $(nt[1])")
    end
    for i in 2:length(nt)
      print(io, ", $(nt[i])")
    end
    print(io, "\n")
  end
  println(io, "=== REVENUE OF THE DAY")
  println(io, "==========================")
  @printf(io, "%.2f dollars\n",-s.cost)

end

function printShort(s::TaxiSolution, io::IO = STDOUT)
  for (k,tax) in enumerate(s.taxis)
    println(io, "=== TAXI $k")
    println(io, "==========================")
    for c in tax.custs
      println(io, "Takes customer $(c.id) at time $(c.timeIn)")
    end
  end
end

#Print a solution in a reduced way, with factored taxi movements and customers
function printMedium(s::TaxiSolution, io::IO = STDOUT)
  for (k,tax) in enumerate(s.taxis)
    println(io, "\n=== TAXI $k")
    println(io, "==========================")
    idc = 1
    count = 0
    road = tax.path[1]
    moves = false
    for t in 1:length(tax.path)
      if !moves
        print(io, "\nMoves: ")
        moves = true
      end
      if tax.path[t] == road
        count += 1
      else
        print(io, "$(src(road))=>$(dst(road)) ($count) - ")
        count = 1
        road = tax.path[t]
      end

      if idc <= length(tax.custs) &&(tax.custs[idc].timeOut == t)
        print(io, "\nDrops customer $(tax.custs[idc].id) off at time $t")
        moves = false
        idc += 1
      end

      if idc <= length(tax.custs) && (tax.custs[idc].timeIn == t)
        print(io, "\n Picks customer $(tax.custs[idc].id) up at time $t")
        moves = false
      end
    end
    print("$(src(road))=>$(dst(road)) ($count) \n")
  end
end

#Longer print, timestep by timestep
function printLong(s::TaxiSolution, io::IO = STDOUT)
  for (k,tax) in enumerate(s.taxis)
    println(io, "=== TAXI $k")
    println(io, "==========================")
    idc = 1
    for t in 1:length(tax.path)
      println(io, "== time $t")
      if idc <= length(tax.custs) && (tax.custs[idc].timeOut == t)
        println(io, "Drops customer $(tax.custs[idc].id) off at location $(src(tax.path[t]))")
        idc += 1
      end

      if idc <= length(tax.custs) && (tax.custs[idc].timeIn == t)
        println(io, "Picks customer $(tax.custs[idc].id) up at location $(src(tax.path[t]))")
      end

      if src(tax.path[t]) == dst(tax.path[t])
        println(io, "Waits at location $(dst(tax.path[t]))")
      else
        println(io, "Moves from location $(src(tax.path[t])) to location $(dst(tax.path[t]))")
      end
    end
  end
end

Base.show(io::IO, sol::TaxiSolution) = printShort(sol, io)

#Print a City
function Base.show(io::IO, pb::TaxiProblem)
    nLocs = nv(pb.network)
    nRoads = ne(pb.network)
    println(io, "Taxi Problem")
    println(io, "City with $nLocs locations and $nRoads roads")
    if pb.nTime == 0
        println(io, "No simulation created yet")
    else
        println(io, "Simulation with $(length(pb.custs)) customers and $(length(pb.taxis)) taxis for $(pb.nTime) timesteps")
    end
end
