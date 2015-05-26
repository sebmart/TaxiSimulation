#----------------------------------------
#-- Print a solution
#----------------------------------------

#Print a taxi assignment solution
function printSolution(pb::TaxiProblem, s::TaxiSolution; verbose=1)
  if verbose == 0
    printShort(pb,s)
  elseif verbose == 1
    printMedium(pb,s)
  else
    printLong(pb,s)
  end

  nt = s.notTakenCustomers
  if length(nt) != 0
    println("=== NOT TAKEN")
    println("==========================")
    if length(nt) == 1
      print("Customer $(nt[1])")
    else
      print("Customers $(nt[1])")
    end
    for i in 2:length(nt)
      print(", $(nt[i])")
    end
    print("\n")
  end
  println("=== REVENUE OF THE DAY")
  println("==========================")
  @printf("%.2f dollars\n",-s.cost)

end

function printShort(pb::TaxiProblem, s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("=== TAXI $k")
    println("==========================")
    for c in tax.custs
      println("Takes customer $c at time $(c.timeIn)")
    end
  end
end

#Print a solution in a reduced way, with factored taxi movements and customers
function printMedium(pb::TaxiProblem, s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("\n=== TAXI $k")
    println("==========================")
    idc = 1
    count = 0
    road = tax.path[1]
    moves = false
    for t in 1:pb.nTime
      if !moves
        print("\nMoves: ")
        moves = true
      end
      if tax.path[t] == road
        count += 1
      else
        print("$(src(road))=>$(dst(road)) ($count) - ")
        count = 1
        road = tax.path[t]
      end

      if idc <= length(tax.custs) &&(tax.custs[idc].timeOut == t)
        print("\nDrops customer $(tax.custs[idc].id) at time $t")
        moves = false
        idc += 1
      end

      if idc <= length(tax.custs) && (tax.custs[idc].timeIn == t)
        print("\nTakes customer $(tax.custs[idc].id) at time $t")
        moves = false
      end
    end
    print("$(src(road))=>$(dst(road)) ($count) \n")
  end
end

#Longer print, timestep by timestep
function printLong(pb::TaxiProblem, s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("=== TAXI $k")
    println("==========================")
    idc = 1
    for t in 1:pb.nTime
      println("== time $t")
      if idc <= length(tax.custs) && (tax.custs[idc].timeOut == t)
        println("Drops customer $(tax.custs[idc].id) at location $(pb.custs[tax.custs[idc].id].dest)")
        idc += 1
      end

      if idc <= length(tax.custs) && (tax.custs[idc].timeIn == t)
        println("Takes customer $(tax.custs[idc].id) at location $(pb.custs[tax.custs[idc].id].orig)")
      end

      if src(tax.path[t]) == dst(tax.path[t])
        println("Waits at location $(dst(tax.path[t]))")
      else
        println("Moves from location $(src(tax.path[t])) to location $(dst(tax.path[t]))")
      end
    end
  end
end
