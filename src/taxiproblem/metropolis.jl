
"""
Elaborate network, depending on parameters
- width = main city width
- nSub  = number of city's suburb (half the city width)
Represent whole city, with commuting effects
"""
type Metropolis <: TaxiProblem
    network::Network
    roadTime::SparseMatrixCSC{Float64, Int}
    roadCost::SparseMatrixCSC{Float64, Int}
    custs::Array{Customer,1}
    taxis::Array{Taxi,1}
    nTime::Float64
    waitingCost::Float64
    paths::Paths
    customerTime::Float64
    #--------------
    #Specific attributes
    width::Int
    subWidth::Int
    nSub::Int
    tStart::DateTime
    tEnd::DateTime

    #--------------
    #Constant attributes
    "Cost for the taxi to drive for a hour"
    driveCost::Float64
    "Cost for the taxi to wait for a hour"
    waitCost::Float64
    "Fare for a hour drive at a given time"
    hourFare::Function
    "Time step length in seconds"
    timeSteptoSecond::Float64
    "Left turn time (in time-steps)"
    turnTime::Float64
    "Left turn cost (in dollars)"
    turnCost::Float64


    function Metropolis(width::Int=8, nSub::Int=8; emptyType=false)
        c = new()
        if emptyType
            return c
        end
        #Load the constants
        c.hourFare = (t::DateTime -> 150)
        c.driveCost = 20.
        c.waitCost  = 10.
        c.timeSteptoSecond = 60.
        c.customerTime = 30./c.timeSteptoSecond
        c.turnTime = 10/c.timeSteptoSecond
        c.turnCost = c.turnTime * c.timeSteptoSecond * c.driveCost / 3600.
        function cityTrvlTime()
            (30+90*rand())/c.timeSteptoSecond
        end
        function longTrvlTime()
            (150+300*rand())/c.timeSteptoSecond
        end
        cityTrvlCost(trvltime) = trvltime * c.driveCost*c.timeSteptoSecond/3600
        longTrvlCost(trvltime) = trvltime * c.driveCost*c.timeSteptoSecond/3600

        # Add a square-city to the graph
        function addSquare(n::Network,roadTime::SparseMatrixCSC{Float64, Int},
            roadCost::SparseMatrixCSC{Float64, Int}, width::Int, start::Int)

            function coordToLoc(i,j)
                return start + j + (i-1)*width
            end
            for i in 1:(width-1), j in 1:width
                #Vertical roads
                a, b = coordToLoc(i,j), coordToLoc(i+1,j)
                add_edge!(n, a, b)
                tt = cityTrvlTime()
                roadTime[a, b] = tt
                roadCost[a, b] = cityTrvlCost(tt)

                add_edge!(n, b, a)
                tt = cityTrvlTime()
                roadTime[b, a] = tt
                roadCost[b, a] = cityTrvlCost(tt)

                #Horizontal roads
                a, b = coordToLoc(j,i), coordToLoc(j,i+1)
                add_edge!(n, a, b)
                tt = cityTrvlTime()
                roadTime[a, b] = tt
                roadCost[a, b] = cityTrvlCost(tt)

                add_edge!(n, b, a)
                tt = cityTrvlTime()
                roadTime[b, a] = tt
                roadCost[b, a] = cityTrvlCost(tt)
            end
        end
        c.width = width
        c.subWidth = floor(Int, width/2)
        c.nSub = nSub
        c.waitingCost = c.waitCost*c.timeSteptoSecond/3600

        #-----------------------------------
        #First, we construct the network
        nLocs = width^2 + nSub * (c.subWidth^2)
        c.network  = DiGraph(nLocs)
        c.roadTime = spzeros(nLocs,nLocs)
        c.roadCost = spzeros(nLocs,nLocs)
        #add the main city
        addSquare(c.network, c.roadTime, c.roadCost, width,0)
        #add the sub cities
        for sub in 1:nSub
            addSquare(c.network, c.roadTime, c.roadCost, c.subWidth, width^2 + (sub - 1 )*(c.subWidth^2))
        end

        #link subs to city
        function sortOrder(x)
            s,t = x
            return (s-1)*width + t
        end
        anchors = sort( [(rand(1:4), rand(1:(width-1))) for i in 1:nSub], by=sortOrder)
        for sub in 1:nSub
            #random anchor in big city
            s, t = anchors[sub]
            i, j = 0, 0
            if s == 1
                i, j = 1, t
            elseif s == 2
                i, j = t, width
            elseif s == 3
                i, j = width, (width - t + 1)
            else
                i, j = (width - t + 1), 1
            end
            a, b = coordToLoc(1,1,sub,c), coordToLoc(i,j,0,c)
            add_edge!(c.network, a, b)
            tt = longTrvlTime()
            c.roadTime[a, b] = tt
            c.roadCost[a, b] = longTrvlCost(tt)

            add_edge!(c.network, b, a)
            tt = longTrvlTime()
            c.roadTime[b, a] = tt
            c.roadCost[b, a] = longTrvlCost(tt)
        end

        #link subs between then (in a circle)
        for sub in 1:(nSub-1)
            a, b = coordToLoc(1,c.subWidth,sub,c), coordToLoc(c.subWidth,1, sub+1,c)
            add_edge!(c.network, a, b)
            tt = cityTrvlTime()
            c.roadTime[a, b] = tt
            c.roadCost[a, b] = cityTrvlCost(tt)

            add_edge!(c.network, b, a)
            tt = cityTrvlTime()
            c.roadTime[b, a] = tt
            c.roadCost[b, a] = cityTrvlCost(tt)
        end
        #last link
        if nSub >1
            a, b = coordToLoc(1,c.subWidth,nSub,c), coordToLoc(c.subWidth,1, 1,c)
            add_edge!(c.network, a, b)
            tt = cityTrvlTime()
            c.roadTime[a, b] = tt
            c.roadCost[a, b] = cityTrvlCost(tt)

            add_edge!(c.network, b, a)
            tt = cityTrvlTime()
            c.roadTime[b, a] = tt
            c.roadCost[b, a] = cityTrvlCost(tt)
        end

        #We compute the shortest paths from everywhere to everywhere (takes time)
        c.paths = shortestPaths(c.network, c.roadTime, c.roadCost)
        c.custs = Customer[]
        c.taxis = Taxi[]
        c.nTime = 0.

        return c
    end
end

"""
    Standard "small" Metropolis problem
"""
function smallMetroProblem()
    width=4; nSub=4; nTaxis = 5; demand = 0.4; tStart=now(); tEnd=now()+Minute(90)
    pb = Metropolis(width, nSub)
    generateProblem!(pb, nTaxis, demand, tStart, tEnd)
    return pb
end

"""
    Standard "big" Metropolis problem
"""
function bigMetroProblem()
    width=8; nSub=8; nTaxis = 20; demand = 0.32; tStart=now(); tEnd=now()+Hour(2)
    pb = Metropolis(width, nSub)
    generateProblem!(pb, nTaxis, demand, tStart, tEnd)
    return pb
end

"""
    Generate customers and taxis, demand is a parameter correlated to the number of customers
"""
function generateProblem!(city::Metropolis, nTaxis::Int = 25, demand::Float64 = 0.55,
    tStart::DateTime=now(), tEnd::DateTime=(now()+Hour(2)))

    city.tStart = tStart
    city.tEnd   = tEnd
    city.nTime  = (tEnd-tStart).value/(city.timeSteptoSecond *1000)

    if city.nTime < 1
        error("Time of simulation too small !")
    end
    generateCustomers!(city, demand)
    generateTaxis!(city, nTaxis)
    return city
end

#compute the demand probabilities for a particular time
# (overall probability, [city=>city, sub=>sub, city=>sub, sub=>city])
#overall probability is the mean of a Poisson law, in customers per hour

function metroDemand(sim::Metropolis, time::DateTime, demand::Float64)
    meanPerHour = (2*sim.width^2 + 0.5*sim.nSub*sim.subWidth^2)*demand
    cityCity = 0.4
    subSub   = 0.1
    citySub  = 0.25
    SubCity  = 0.25
    return (meanPerHour, [cityCity, subSub, citySub, SubCity])
end

#to generate the customers
function generateCustomers!(sim::Metropolis, demand::Float64)
    sim.custs = Customer[]
    tCurrent = sim.tStart
    tt = traveltimes(sim)
    t = 0
    while tCurrent < sim.tEnd
        meanPerHour, catProb = metroDemand(sim, tCurrent, demand)
        category = rand(Categorical(catProb))
        orig, dest = 0, 0
        #-------------
        #-- city=>city
        if category == 1
            orig = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
            dest = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
            while orig == dest
                dest = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
            end
            #-------------
            #-- sub=>sub
        elseif category == 2
            orig = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
            dest = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
            while orig == dest
                dest = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
            end
            #-------------
            #-- city=>sub
        elseif category == 3
            orig = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
            dest = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
            #-------------
            #-- sub=>city
        else
            dest = coordToLoc(rand(1:sim.width), rand(1:sim.width), 0, sim)
            orig = coordToLoc(rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim)
        end
        price = (sim.hourFare(tCurrent)/3600)*tt[orig,dest]*sim.timeSteptoSecond
        tmin  = t
        tmaxt = min(sim.nTime, t + 5*60*rand()/sim.timeSteptoSecond)
        tcall = max(0., tmin - 60*60*rand()/sim.timeSteptoSecond)
        push!(sim.custs,
        Customer(length(sim.custs)+1,orig,dest,tcall,tmin,tmaxt,price))

        #First, get the number of customers to generate
        tCurrent += Millisecond(toInt(rand(Exponential((3600*1000)/meanPerHour))))
        #value of timeStep
        t = (tCurrent - sim.tStart).value/(1000*sim.timeSteptoSecond)
    end
end


function generateTaxis!(sim::Metropolis, nTaxis::Int)
    sim.taxis = Taxi[]
    for k in 1:nTaxis
        if rand(1:2) == 1 #taxi in city
            push!(sim.taxis, Taxi( k, coordToLoc( rand(1:sim.width), rand(1:sim.width), 0, sim), 0.0))
        else
            push!(sim.taxis, Taxi( k, coordToLoc( rand(1:sim.subWidth), rand(1:sim.subWidth), rand(1:sim.nSub), sim), 0.0))
        end
    end
end

#Gives the index of vertex, given coords and city number
function coordToLoc(i::Int, j::Int, c::Int, city::Metropolis)
    if c ==0
        return j + (i-1)*city.width
    else
        return city.width^2 + (c-1)*city.subWidth^2 + j + (i-1)*city.subWidth
    end
end


"Compute _real_ paths (with left turns)"
function realPaths!(sim::Metropolis)
    sim.paths = realPaths(sim.network, sim.roadTime, sim.roadCost, graphPositions(sim.network),
    sim.turnTime, sim.turnCost);
    return
end

function Base.copy(city::Metropolis)
    m =  Metropolis(emptyType=true)
    for k = 1:length(fieldnames(m))
        setfield!(m, k, getfield(city,k))
    end
    return m
end
