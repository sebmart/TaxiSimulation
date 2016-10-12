###################################################
## realdata/realdata.jl
## Storing real taxi data
###################################################

"""
    `RealCustomer`, represents a real customer in a network (link to precise time)
"""
immutable RealCustomer
    tcall::DateTime
    tmin::DateTime
    tmax::DateTime
    orig::Int
    dest::Int
    fare::Float64
end

"""
    `saveByDate`, takes an array of real customers, and store them by date of pick-up time
    - the name of the JLD files are `name`-`date`.jld
"""
function saveByDate(data::Vector{RealCustomer}, name::AbstractString)
    # sorting data by date
    dict = Dict{Date,Vector{Int}}()
    for (i,c) in enumerate(data)
        d = Date(c.tmin)
        if haskey(dict, d)
            push!(dict[d], i)
        else
            dict[d] = Int[i]
        end
    end

    # creating the files
    for (d,list) in dict
        fileName = string(name, "-", d, ".jld")
        JLD.save(fileName, "customers", RealCustomer[data[c] for c in list])
        println("created file $fileName")
    end
end
