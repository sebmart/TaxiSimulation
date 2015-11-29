"Manhattan City, contains the real city-graph"
type Manhattan <: TaxiProblem
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
    "Distances between neighbor nodes"
    distances::SparseMatrixCSC{Float64, Int}
    "ENU position for each node"
    positions::Vector{Coordinates}
    "Road type, from 1 (fastest) to 8 (slowest)"
    roadType::SparseMatrixCSC{Int, Int}
    "First pickup of the simulation"
    tStart::DateTime
    "Last pickup of the simulation"
    tEnd::DateTime

    #--------------
    #Constant attributes
    "Cost for the taxi to drive for a hour"
    driveCost::Float64
    "Cost for the taxi to wait for a hour"
    waitCost::Float64
    "Time step length in seconds"
    timeSteptoSecond::Float64
    "Left turn time (in time-steps)"
    turnTime::Float64
    "Left turn cost (in dollars)"
    turnCost::Float64

    function Manhattan(;sp=false,emptyType=false)
        c = new()
        if emptyType
            return c
        end
        #Initialize the constants
        c.driveCost = 20.
        c.waitCost  = 10.
        c.timeSteptoSecond = 1.0
        c.customerTime = 30./c.timeSteptoSecond
        c.turnTime = 10./c.timeSteptoSecond
        c.turnCost = c.turnTime * c.timeSteptoSecond * c.driveCost / 3600.
        c.waitingCost = c.waitCost * c.timeSteptoSecond / 3600.


        data = load("$(path)/src/cities/manhattan/manhattan.jld")
        c.network   = data["network"]
        c.distances = data["distances"]
        c.roadType  = data["roadType"]
        timings = [95.,72.,48.,32.,22.,12.,8.,5.] # in km/h
        c.roadTime  = spzeros(nv(c.network),nv(c.network))
        for r in edges(c.network)
            c.roadTime[src(r),dst(r)] = 3.6* c.distances[src(r),dst(r)]/timings[c.roadType[src(r),dst(r)]] / c.timeSteptoSecond
        end
        c.roadCost  = c.roadTime*c.timeSteptoSecond*c.driveCost/3600.
        c.positions = data["positions"]
        if sp
            realPaths!(c)
        else
            c.paths = RealPaths()
        end

        c.custs = Customer[]
        c.taxis = Taxi[]
        c.nTime = 0.
        return c
    end
end

"Output the graph vizualization to pdf file (see GraphViz library)"
function drawNetwork(pb::Manhattan, name::AbstractString = "graph")
    stdin, proc = open(`neato -n2 -Tpdf -o $(path)/outputs/$name.pdf`, "w")
    write(stdin, "digraph  citygraph {\n")
    for i in vertices(pb.network)
        write(stdin, "$i [\"pos\"=\"$(pb.positions[i].x),$(pb.positions[i].y)!\"]\n")
    end
    for i in vertices(pb.network), j in out_neighbors(pb.network,i)
        write(stdin, "$i -> $j\n")
    end
    write(stdin, "}\n")
    close(stdin)
end

"Generate customers and taxis"
function generateProblem!(city::Manhattan, nTaxis::Int, tStart::DateTime,
    tEnd::DateTime, demand::Float64 = 1.0; waitTime::TimePeriod = Minute(5))
    if isempty(traveltimes(city))
        error("shortest paths have to be computed before generating problem")
    end
    if tStart + Second(1) >= tEnd
        error("Time of simulation too short!")
    end
    city.tStart = tStart
    city.tEnd   = tEnd

    generateCustomers!(city, demand, waitTime=waitTime)
    generateTaxis!(city, nTaxis)
    return city
end

"Generate customers in Manhattan using real customer data"
function generateCustomers!(sim::Manhattan, demand::Float64=1.0; waitTime::TimePeriod = Minute(5))
    #Transform a real time into timesteps
    timeToTs(time::DateTime) = (time - sim.tStart).value/(1000*sim.timeSteptoSecond)
    if Date(sim.tStart) != Date(sim.tEnd)
        error("Right now, simulations have to be included in a day.")
    end
    tt = traveltimes(sim)
    println("Extracting NYC customers...")
    df = readtable("$(path)/src/cities/manhattan/customers/$(Date(sim.tStart)).csv")
    sStart = replace(string(sim.tStart), "T", " ")
    sEnd   = replace(string(sim.tEnd), "T", " ")
    maxTime::Float64 = 0.
    empty!(sim.custs)
    for i in 1:nrow(df)
        if sStart <= df[i, :ptime] <= sEnd && df[i, :pnode] != df[i, :dnode] &&
            tt[df[i,:pnode],df[i,:dnode]] > 60./sim.timeSteptoSecond && rand() <= demand
            tInf = DateTime(df[i, :ptime], "y-m-d H:M:S") + Second(rand(-29:30)) #to make up for database rounding
            tSup = tInf + waitTime
            tCall = min(sim.tStart, tInf - Minute(rand(1:60)))
            customer = Customer(
            length(sim.custs)+1,
            df[i,:pnode],
            df[i,:dnode],
            timeToTs(tCall),
            timeToTs(tInf),
            timeToTs(tSup),
            df[i, :price]
            )
            push!(sim.custs, customer)
            maxTime = max(maxTime,timeToTs(tSup))
        end
        sim.nTime = maxTime + EPS
    end
    println("$(length(sim.custs)) NYC customers extracted!")

end

"Generate taxis in Manhattan"
function generateTaxis!(sim::Manhattan, nTaxis::Int)
    empty!(sim.taxis)
    sim.taxis = Array(Taxi,nTaxis);
    for k in 1:nTaxis
        sim.taxis[k] = Taxi(k,rand(1:nv(sim.network)), 0.0);
    end
end

"Compute _real_ paths (with left turns)"
function realPaths!(sim::Manhattan)
    sim.paths = realPaths(sim.network, sim.roadTime, sim.roadCost, sim.positions,
    sim.turnTime, sim.turnCost);
    return
end

function Base.copy(man::Manhattan)
    m =  Manhattan(emptyType=true)
    for k = 1:length(fieldnames(m))
        setfield!(m, k, getfield(man,k))
    end
    return m
end
