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
