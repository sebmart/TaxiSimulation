# n*n points randomized square network
#between 1 and 4 time-steps for taking a link
#cost : between(1.5 and 2.5)*time if moving, 1*time if staying

type SquareCity <: TaxiProblem
  network::Network
  roadTime::SparseMatrixCSC{Int8, Int}
  roadCost::SparseMatrixCSC{Float64, Int}
  custs::Array{Customer,1}
  taxis::Array{Taxi,1}
  nTime::Int
  waitingCost::Float64
  sp::ShortPaths

#--------------
#Specific attributes
  width::Int

  #constructor that only create the graph
  function SquareCity(width::Int)
    city = new()
    #automatically select the number of customers
    city.waitingCost = 0.25
    city.width = width
    #Locs are numerated as follow :
    #123
    #456
    #789
    nLocs = width^2

    function coordToLoc(i,j)
      return j + (i-1)*width
    end
    function locToCoord(n)
      return (div((n-1),width) + 1, ((n-1) % width) + 1)
    end


    network  = DiGraph(nLocs)
    roadTime = spzeros(nLocs,nLocs)
    roadCost = spzeros(nLocs,nLocs)

    #We construct the roads

    #return travel time to take one link
    function traveltime()
      return rand(1:4)
    end
    function travelcost(trvltime)
      trvltime * (1 + rand())/4
    end

    for i in 1:(width-1), j in 1:width
      #Vertical roads
      tt = traveltime()
      roadTime[ coordToLoc(i,j), coordToLoc(i+1,j) ] = tt
      roadCost[ coordToLoc(i,j), coordToLoc(i+1,j) ] = travelcost(tt)
      add_edge!(network, coordToLoc(i,j), coordToLoc(i+1,j))

      tt = traveltime()
      roadTime[ coordToLoc(i+1,j), coordToLoc(i,j) ] = tt
      roadCost[ coordToLoc(i+1,j), coordToLoc(i,j) ] = travelcost(tt)
      add_edge!(network, coordToLoc(i+1,j), coordToLoc(i,j))

      #Horizontal roads

      tt = traveltime()
      roadTime[ coordToLoc(j,i), coordToLoc(j,i+1) ] = tt
      roadCost[ coordToLoc(j,i), coordToLoc(j,i+1) ] = travelcost(tt)
      add_edge!(network, coordToLoc(j,i), coordToLoc(j,i+1))

      tt = traveltime()
      roadTime[ coordToLoc(j,i+1), coordToLoc(j,i) ] = tt
      roadCost[ coordToLoc(j,i+1), coordToLoc(j,i) ] = travelcost(tt)
      add_edge!(network, coordToLoc(j,i+1), coordToLoc(j,i))
    end


    city.network = network

    #We compute the shortest paths from everywhere to everywhere (takes time)
    city.sp =  shortestPaths(network)

    return city
  end

  SquareCity(network::Network, roadTime::SparseMatrixCSC{Int8, Int},
    roadCost::SparseMatrixCSC{Float64, Int}, custs::Array{Customer,1},
    taxis::Array{Taxi,1}, nTime::Int, waitingCost::Int, sp::ShortPaths) =
     new(network,roadTime,roadCost,custs,taxis,nTime,waitingCost,sp)
end

#Copy the object
clone(c::SquareCity) = SquareCity(c.network, c.roadTime, c.roadCost, c.custs,
 c.taxis, c.nTime, c.waitingCost, c.sp)


function generateTaxis!(city::SquareCity, nTaxis::Int)
  #List of the taxis
  #Random initial locations
  city.taxis =  [Taxi(i,rand(1:((city.width)^2))) for i in 1:nTaxis]

end

function generateCustomers!(city::SquareCity, nCusts = -1)
  #List of the customers.
  #Customers are randomize, but the time and price depend on the path.
  function locToCoord(n)
    return (div((n-1),city.width) + 1, ((n-1) % city.width) + 1)
  end

  nLocs = (city.width)^2
  if nCusts == -1
    nCusts = 2*int(ceil(city.nTime * length(city.taxis) /(2*2.5*city.width*1.5)))
  end


  customers = Array(Customer,nCusts)
  for c in 1:nCusts
    orig = rand(1:nLocs)
    dest = rand(1:nLocs)
    while orig == dest
      dest = rand(1:nLocs)
    end

    oI, oJ = locToCoord(orig)
    dI, dJ = locToCoord(dest)
    pathlength = abs(oI-dI) + abs(oJ-dJ)

    clienttime = 4*pathlength
    maxWaiting = rand(1:10)

    price = (20+5*rand())*pathlength
    tmaxt = rand(1:max(1, nTime - clienttime))
    tmax  = min(nTime, tmaxt + clienttime)
    tmin = max(1, tmaxt - maxWaiting)

    maxBooking = rand(1:80)

    tcall = max(1,tmin-maxBooking)

    customers[c] = Customer(c,orig,dest,tcall,tmin,tmaxt,tmax,price)
  end

  city.custs = customers
end

function generateProblem!(city::SquareCity, nTaxis::Int, nTime::Int, nCusts = -1)
  city.nTime = nTime
  generateTaxis!(city, nTaxis)
  generateCustomers!(city, nCusts)
end
