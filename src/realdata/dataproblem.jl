###################################################
## realdata/dataproblem.jl
## generate TaxiProblem from real data
###################################################

"""
    `addDataCustomers`, add customers from data
    - between two datetimes
    - cuts tcall and tmax to start and stop
    - demand = percentage of real customers
"""
function addDataCustomers!(pb::TaxiProblem, data::Vector{RealCustomer},
                           start::DateTime, stop::DateTime, demand::Float64=1.0)
    pb.custs = Customer[]
    for c in data
        if  start <= c.tmin <= stop && rand() <= demand
            tmin  = (c.tmin - start).value/1000.
            tcall = (max(c.tcall, start) - start).value/1000.
            tmax  = (min(c.tmax , stop ) - start).value/1000.
            push!(pb.custs, Customer(length(pb.custs)+1, c.orig, c.dest, tcall, tmin, tmax, c.fare))
        end
    end
    pb.simTime = (stop - start).value/1000.
end
