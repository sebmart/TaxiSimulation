# n*n points randomized square network
#between 1 and 4 time-steps for taking a link
#cost : between(1.5 and 2.5)*time if moving, 1*time if staying

type SquareCity <: TaxiProblem
  network::Network
  roadTime::SparseMatrixCSC{Float64, Int}
  roadCost::SparseMatrixCSC{Float64, Int}
  custs::Array{Customer,1}
  taxis::Array{Taxi,1}
  nTime::Float64
  waitingCost::Float64
  sp::ShortPaths
  discreteTime::Bool

#-----------------------------------------
#Specific attributes
  width::Int

  #constructor that only create the graph
  function SquareCity(width::Int; discreteTime = false)
    c = new()
    #automatically select the number of customers
    c.waitingCost = 0.25
    c.width = width
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


    c.network  = DiGraph(nLocs)
    c.roadTime = spzeros(nLocs,nLocs)
    c.roadCost = spzeros(nLocs,nLocs)

    #We construct the roads

    #return travel time to take one link
    function traveltime()
      if discreteTime
        return rand(1:4)
      else
        return 1+3*rand()
      end
    end
    function travelcost(trvltime)
      trvltime * (1 + rand())/4
    end

    for i in 1:(width-1), j in 1:width
      #Vertical roads
      tt = traveltime()
      c.roadTime[ coordToLoc(i,j), coordToLoc(i+1,j) ] = tt
      c.roadCost[ coordToLoc(i,j), coordToLoc(i+1,j) ] = travelcost(tt)
      add_edge!(c.network, coordToLoc(i,j), coordToLoc(i+1,j))

      tt = traveltime()
      c.roadTime[ coordToLoc(i+1,j), coordToLoc(i,j) ] = tt
      c.roadCost[ coordToLoc(i+1,j), coordToLoc(i,j) ] = travelcost(tt)
      add_edge!(c.network, coordToLoc(i+1,j), coordToLoc(i,j))

      #Horizontal roads

      tt = traveltime()
      c.roadTime[ coordToLoc(j,i), coordToLoc(j,i+1) ] = tt
      c.roadCost[ coordToLoc(j,i), coordToLoc(j,i+1) ] = travelcost(tt)
      add_edge!(c.network, coordToLoc(j,i), coordToLoc(j,i+1))

      tt = traveltime()
      c.roadTime[ coordToLoc(j,i+1), coordToLoc(j,i) ] = tt
      c.roadCost[ coordToLoc(j,i+1), coordToLoc(j,i) ] = travelcost(tt)
      add_edge!(c.network, coordToLoc(j,i+1), coordToLoc(j,i))
    end

    #We compute the shortest paths from everywhere to everywhere (takes time)
    c.sp =  shortestPaths(c.network, c.roadTime, c.roadCost)
    c.custs = Customer[]
    c.taxis = Taxi[]
    c.nTime = 0
    c.discreteTime = false
    return c
  end
end



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

    clienttime = city.sp.traveltime[orig,dest]

    if clienttime > city.nTime
        error("simulation too short to generate customer")
    end

    price = (5+rand())*clienttime
    if city.discreteTime
      tmaxt = rand(1:(city.nTime - clienttime))
      tmax  = tmaxt + clienttime
      tmin = max(1, tmaxt - rand(1:10))
      tcall = max(1,tmin-rand(1:80))
    else
      tmaxt = rand()*(city.nTime - clienttime)
      tmax  = tmaxt + clienttime
      tmin = max(0.0, tmaxt - (EPS+10*rand()))
      tcall = max(0.0,tmin-(EPS + 80*rand()))
    end

    customers[c] = Customer(c,orig,dest,tcall,tmin,tmaxt,tmax,price)
  end

  city.custs = customers
end

function generateProblem!(city::SquareCity, nTaxis::Int, nTime::Float64, nCusts = -1)
  city.nTime = nTime
  generateTaxis!(city, nTaxis)
  generateCustomers!(city, nCusts)
end
