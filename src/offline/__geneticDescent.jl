#----------------------------------------
#-- Random "genetic descent"
#----------------------------------------
include("offlineAssignment.jl")

function geneticDescentOrder(pb::TaxiProblem, popSize::Int, generations::Int;
                             childrenNumber = -1)
  if childrenNumber == -1
    childrenNumber = popsize
  end
  initT = time()
  sp = pb.sp

  population = generatePopulation(pb,popSize)
  costs = [offlineAssignmentQuick(pb,p)[1] for p in population]
  sort = sortperm(costs)
  costs = costs[sort]
  lastCost = Inf
  population = population[sort]
  println("==== generation 1 : $(-costs[1]) dollars")
  push!(genTime,time()-initT)
  push!(genRes,-costs[1])
  #For each generation
  for i in 2:generations
    #---------------------------
    #-- We generate the children
    #---------------------------
    d = reproduction(costs) #The chance of an individual to reproduce
    child = Array(Vector{Int},childrenNumber)
    for j in 1:childrenNumber
      child[j] = childOrder(parents(d,population))
    end
    childCosts = [offlineAssignmentQuick(pb,p)[1] for p in child]

    #---------------------------
    #-- We eliminate the worst results
    #---------------------------
    bigOrder = sortperm([childCosts, costs])
    population = ([child, population][bigOrder])[1:popSize]
    costs = ([childCosts, costs][bigOrder])[1:popSize]
    if lastCost!= costs[1]
      println("==== generation $i : $(-costs[1]) dollars")
      lastCost = costs[1]
      push!(genTime,time()-initT)
      push!(genRes,-costs[1])
    end
      println(costs)

  end
  bestCost, bestSol =  offlineAssignmentQuick(pb,population[1])
  cpt, nt = customers_per_taxi(length(pb.taxis),bestSol)
  tp = taxi_paths(pb,bestSol,cpt)

  taxiActs = Array(TaxiActions,length(pb.taxis))
  for i = 1:length(pb.taxis)
    taxiActs[i] = TaxiActions(tp[i],cpt[i])
  end
  return (TaxiSolution(taxiActs, nt, bestSol, bestCost), population[1])
end

geneticDescent(pb::TaxiProblem, popSize::Int, generations::Int; childrenNumber = -1) =
  geneticDescentOrder(pb,popSize,generations,childrenNumber=childrenNumber)[1]

function parents(d::Categorical , population::Vector{Vector{Int}})
  mum = rand(d)
  dad = mum
  while dad == mum
    dad = rand(d)
  end

  return(population[mum],population[dad])
end

function childOrder(parents::(Vector{Int},Vector{Int}))
  mum,dad = parents
  childOrders = zeros(Float64,length(mum))
  for i in 1:length(mum)
    childOrders[mum[i]] += i/2.
    childOrders[dad[i]] += i/2.
  end
  return mutation(sortperm(childOrders), rand(0:4))
end

function generatePopulation(pb::TaxiProblem, popSize::Int)
#   return [randomOrder(pb) for i in 1:popSize]
#   pop = [childOrder((randomOrder(pb),[1:length(pb.custs)])) for i in 1:popSize]
#   pop[1] = [1:length(pb.custs)]
  pop = [[1:length(pb.custs)] for i in 1:popSize]
  return pop
end

function reproduction(costs::Vector{Float64})
  # return Categorical(costs/sum(costs))
  p = [c /(log(i+2))^(1.5) for (i,c) in enumerate(costs)]
  println(p/sum(p))
  return Categorical(p/sum(p))
end

function mutation(order::Vector{Int}, n)
  for k = 1:n
    i = rand(1:length(order))
    j = rand(1:length(order))
    order[i], order[j] = order[j], order[i]
  end
  return order
end
