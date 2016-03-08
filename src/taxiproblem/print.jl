###################################################
## taxiproblem/print.jl
## Printing detailled description of objects
###################################################
"""
  `printSolution`, print details of a taxiSolution, 3 levels
"""
function printSolution(s::TaxiSolution, io::IO = STDOUT; verbose=1)
  if verbose == 0
    printShort(s, io)
  elseif verbose == 1
    printLong(s, io)
  else
    error("wrong verbose value (try 0 or 1)")
  end

  rej = s.rejected
  if !isempty(rej)
    println(io, "=== Rejected")
    println(io, "==========================")
    if length(rej) == 1
      print(io, "Customer $(first(rej))")
    else
      print(io, "Customers $(first(rej))")
    end
    for c in drop(rej,1)
      print(io, ", $c")
    end
    print(io, "\n")
  end
  println(io, "=== PROFIT")
  println(io, "==========================")
  @printf(io, "%.2f dollars\n",s.metrics.profit)

end
"""
  `printShort`, only print customers assignment
"""
function printShort(s::TaxiSolution, io::IO = STDOUT)
  for (k,act) in enumerate(s.actions)
    println(io, "=== TAXI $k")
    println(io, "==========================")
    for c in act.custs
      m, s = minutesSeconds(c.timeIn)
      @printf(io, "Takes customer %i at time %dm%ds\n", c.id, m, s)
    end
  end
end

"""
  `printLong`, print the solution with paths in a reduced way (very condensed)
"""
function printLong(s::TaxiSolution, io::IO = STDOUT)
  for (k,act) in enumerate(s.actions)
    println(io, "\n=== TAXI $k")
    println(io, "==========================")
    idc = 1
    moves = false
    picked = false
    for i in 1:length(act.times)
      if idc <= length(act.custs) && act.custs[idc].timeOut <= act.times[i][1] + EPS
        m, s = minutesSeconds(act.custs[idc].timeOut)
        @printf(io, "\nDrops customer %i off at time %dm%ds", act.custs[idc].id, m, s)
        picked = false
        moves = false
        idc += 1
      end
      if !picked && idc <= length(act.custs) && (act.custs[idc].timeIn <= act.times[i][1] + EPS)
        m, s = minutesSeconds(act.custs[idc].timeIn)
        @printf(io, "\nPicks customer %i up at time %dm%ds",act.custs[idc].id, m, s)
        picked = true
        moves = false
      end
      if !moves
        print(io, "\nMoves: ")
        moves = true
      end
      m, s = minutesSeconds(act.times[i][2] - act.times[i][1])
      if i < length(act.times)
        @printf(io, "%i=>%i (%dm%ds) - ", act.path[i], act.path[i+1], m, s)
        if act.times[i][2] + EPS < act.times[i+1][1]
          m, s = minutesSeconds(act.times[i+1][1] - act.times[i][2])
          @printf(io, "wait (%dm%ds) - ", m, s)
        end
      else

        @printf(io, "%i=>%i (%dm%ds)", act.path[i], act.path[i+1], m, s)
      end
    end
    if idc <= length(act.custs)
      m, s = minutesSeconds(act.custs[idc].timeOut)
      @printf(io, "\nDrops customer %i off at time %dm%ds",act.custs[idc].id, m,s)
    end
    print("\n\n")
  end
end
