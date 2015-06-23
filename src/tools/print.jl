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
      @printf(io, "Takes customer %i at time $.2f", c.id, c.timeIn)
    end
  end
end

#Print a solution in a reduced way, with factored taxi movements and customers
function printMedium(s::TaxiSolution, io::IO = STDOUT)
  for (k,tax) in enumerate(s.taxis)
    println(io, "\n=== TAXI $k")
    println(io, "==========================")
    idc = 1
    moves = false
    for (i,(t,road)) in enumerate(tax.path)
      if !moves
        print(io, "\nMoves: ")
        moves = true
      end
      if i < length(tax.path)
        @printf(io, "%i=>%i ($.2f) - \n", src(road), dst(road), taxi.path[i+1][1] - t)
      else
        @printf(io, "%i=>%i (until the end) \n\n", src(road), dst(road))
      end

      if idc <= length(tax.custs) && tax.custs[idc].timeOut >= t
        @printf(io, "\nDrops customer %i off at time %.2f\n",tax.custs[idc].id, tax.custs[idc].timeOut)
        moves = false
        idc += 1
      end

      if idc <= length(tax.custs) && (tax.custs[idc].timeIn >= t)
        @printf(io, "\nPicks customer %i up at time %.2f\n",tax.custs[idc].id, tax.custs[idc].timeIn)
        moves = false
      end
    end
  end
end

#Longer print, timestep by timestep
function printLong(s::TaxiSolution, io::IO = STDOUT)
  for (k,tax) in enumerate(s.taxis)
    println(io, "=== TAXI $k")
    println(io, "==========================")
    idc = 1
    for (t, road) in tax.path
      println(io, "== time $t")
      if idc <= length(tax.custs) && (tax.custs[idc].timeOut >= t)
        println(io, "Drops customer $(tax.custs[idc].id) off at location $(src(road))")
        idc += 1
      end

      if idc <= length(tax.custs) && (tax.custs[idc].timeIn == t)
        println(io, "Picks customer $(tax.custs[idc].id) up at location $(src(road))")
      end

      if src(road) == dst(road)
        println(io, "Waits at location $(dst(road))")
      else
        println(io, "Moves from location $(src(road)) to location $(dst(road))")
      end
    end
  end
end

function Base.show(io::IO, sol::TaxiSolution)
    nt= count(i->i, sol.notTaken)
    println(io, "TaxiSolution")
    println(io, "Revenue : $(-sol.cost) dollars")
    println(io, "$nt customers not served. ")
end

function Base.show(io::IO, sol::IntervalSolution)
    nt= count(i->i, sol.notTaken)
    println(io, "IntervalSolution")
    println(io, "Revenue : $(-sol.cost) dollars")
    println(io, "$nt customers not served. ")
end

#Print a City
function Base.show(io::IO, pb::TaxiProblem)
    nLocs = nv(pb.network)
    nRoads = ne(pb.network)
    println(io, "Taxi Problem")
    println(io, "City with $nLocs locations and $nRoads roads")
    if pb.nTime == 0
        println(io, "No simulation created yet")
    else
        @printf(io, "Simulation with %i customers and %i taxis for $.2f units of time\n",
            length(pb.custs), length(pb.taxis), pb.nTime)
    end
end
