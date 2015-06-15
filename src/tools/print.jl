#----------------------------------------
#-- Print a solution
#----------------------------------------

function printSolution(s::TaxiSolution; verbose=1)
  if verbose == 0
    printShort(s)
  elseif verbose == 1
    printMedium(s)
  else
    printLong(s)
  end

  nt = [1:length(s.notTaken)][s.notTaken]
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

function printShort(s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("=== TAXI $k")
    println("==========================")
    for c in tax.custs
      println("Takes customer $(c.id) at time $(c.timeIn)")
    end
  end
end

#Print a solution in a reduced way, with factored taxi movements and customers
function printMedium(s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("\n=== TAXI $k")
    println("==========================")
    idc = 1
    count = 0
    road = tax.path[1]
    moves = false
    for t in 1:length(tax.path)
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
        print("\nDrops customer $(tax.custs[idc].id) off at time $t")
        moves = false
        idc += 1
      end

      if idc <= length(tax.custs) && (tax.custs[idc].timeIn == t)
        print("\n Picks customer $(tax.custs[idc].id) up at time $t")
        moves = false
      end
    end
    print("$(src(road))=>$(dst(road)) ($count) \n")
  end
end

#Longer print, timestep by timestep
function printLong(s::TaxiSolution)
  for (k,tax) in enumerate(s.taxis)
    println("=== TAXI $k")
    println("==========================")
    idc = 1
    for t in 1:length(tax.path)
      println("== time $t")
      if idc <= length(tax.custs) && (tax.custs[idc].timeOut == t)
        println("Drops customer $(tax.custs[idc].id) off at location $(src(tax.path[t]))")
        idc += 1
      end

      if idc <= length(tax.custs) && (tax.custs[idc].timeIn == t)
        println("Picks customer $(tax.custs[idc].id) up at location $(src(tax.path[t]))")
      end

      if src(tax.path[t]) == dst(tax.path[t])
        println("Waits at location $(dst(tax.path[t]))")
      else
        println("Moves from location $(src(tax.path[t])) to location $(dst(tax.path[t]))")
      end
    end
  end
end
