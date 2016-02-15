###################################################
## realdata/nyctaxidata.jl
## loads and saves NYC taxi data
###################################################

"""
    `loadManhattanCustomers`, loads customer from original taxi_csv
    - fare = total fare
    - tmax = tmin + 5min
"""
function loadManhattanCustomers(man::Network, fileName::AbstractString)
    println("Counting lines...")
    f = open(fileName)
    const NLINES = countlines(f) - 1
    const MANHATTAN = Tuple{Float32,Float32}[(-74.01369f0,40.69977f0), (-74.00597f0,40.702637f0), (-73.99944f0,40.70641f0), (-73.991714f0,40.708492f0), (-73.9761f0,40.71044f0), (-73.96923f0,40.72931f0), (-73.973526f0,40.736073f0), (-73.9615f0,40.75402f0), (-73.941765f0,40.774693f0), (-73.94348f0,40.78223f0), (-73.938156f0,40.78535f0), (-73.93593f0,40.79029f0), (-73.928894f0,40.79432f0), (-73.92872f0,40.803024f0), (-73.93318f0,40.80744f0), (-73.9349f0,40.833942f0), (-73.92134f0,40.85745f0), (-73.91893f0,40.858356f0), (-73.913956f0,40.863678f0), (-73.909706f0,40.872345f0), (-73.91829f0,40.875168f0), (-73.92648f0,40.879192f0), (-73.93344f0,40.87244f0), (-73.933525f0,40.86793f0), (-73.943436f0,40.853584f0), (-73.947945f0,40.85164f0), (-73.94713f0,40.84414f0), (-73.9552f0,40.828682f0), (-73.96091f0,40.8205f0), (-73.97734f0,40.79864f0), (-73.98957f0,40.78077f0), (-73.996994f0,40.770725f0), (-74.00352f0,40.761368f0), (-74.01064f0,40.75103f0), (-74.01532f0,40.719486f0), (-74.01764f0,40.719063f0), (-74.02047f0,40.704067f0)]

    close(f)
    println("$NLINES customers to parse")
    customers = RealCustomer[]
    sizehint!(customers, NLINES)

    dateFormat = DateFormat("y-m-d H:M:S")
    f = open(fileName)
    names = split(strip(readline(f)),",")
    const PLON  = findfirst(names, "pickup_longitude")
    const PLAT  = findfirst(names, "pickup_latitude")
    const DLON  = findfirst(names, "dropoff_longitude")
    const DLAT  = findfirst(names, "dropoff_latitude")
    const PTIME = findfirst(names, "tpep_pickup_datetime")
    const FARE  = findfirst(names, "fare_amount")
    const EXTRA = findfirst(names, "extra")
    const TAX1  = findfirst(names, "mta_tax")
    const TAX2  = findfirst(names, "improvement_surcharge")
    const TOLLS = findfirst(names, "tolls_amount")

    # Constructing tree
    dataPos = Array(Float32,(2, nNodes(man)))
    for (i,node) in enumerate(man.nodes)
       dataPos[1,i] = node.lon
       dataPos[2,i] = node.lat
    end
    tree = KDTree(dataPos)

    println("Beginning trip parsing...")
    for (i,ln) in enumerate(eachline(f))
        if i%10_000 == 0
            @printf("\r%.2f%% customers parsed     ",100*i/NLINES)
        end
        s = split(strip(ln),",")
        plon = parse(Float32,s[PLON])
        plat = parse(Float32,s[PLAT])
        dlon = parse(Float32,s[DLON])
        dlat = parse(Float32,s[DLAT])

        if !pointInsidePolygon(plon, plat, MANHATTAN) || !pointInsidePolygon(dlon, dlat, MANHATTAN)
            continue
        end
        orig =  knn(tree,[plon, plat],1)[1][1]
        dest =  knn(tree,[dlon, dlat],1)[1][1]
        if orig == dest
            continue
        end

        tmin  = DateTime(s[PTIME], dateFormat)
        tmax  = tmin + Minute(5)
        tcall = tmin - Minute(5)
        fare  = parse(Float64,s[FARE]) +
                parse(Float64,s[EXTRA])+
                parse(Float64,s[TAX1]) +
                parse(Float64,s[TAX2]) +
                parse(Float64,s[TOLLS])

        push!(customers, RealCustomer(tcall, tmin, tmax, orig, dest, fare))
    end
    print("\r100.00% customers parsed     ")
    return customers
end
