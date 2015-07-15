
"Insert customer in a taxi timeline, but cannot be modified later"
type FixedAssignment <: OnlineMethod
	pb::TaxiProblem
	sol::IntervalSolution
    currentCust::Vector{Int}

	FixedAssignment() = new()
end

"""
Initializes a given FixedAssignment with a selected taxi problem without customers
"""
function initialize!(om::FixedAssignment, pb::TaxiProblem)
	om.pb = pb
    om.currentCust = ones(Int, length(pb.taxis))
    om.sol = IntervalSolution(pb)
end


function update!(om::FixedAssignment, endTime::Float64, newCustomers::Vector{Customer})
    pb = om.pb
    tt = traveltimes(pb)
    for c in sort(newCustomers, by=x->x.tmin)
        if length(pb.custs) < c.id
            resize!(pb.custs, c.id)
            for i = 1:(c.id-length(pb.custs))
                push!(om.sol.notTaken, true)
            end
        end
        pb.custs[c.id] = c

        insertCustomer!(pb,om.sol)
    end
    actions = TaxiActions[TaxiActions(Tuple{Float64, Road}[], CustomerAssignment[]) for i in 1:length(pb.taxis)]

    for (k,custs) in enumerate(om.sol)
        for i = currentCust[k]:length(custs)
            c = custs[i]
            if c.tSup <= endTime
                if i == 1
                    append!(actions[k].path, getPath(pb, pb.taxis[k].initPos,
                    pb.custs[c.id].orig, c.tSup - tt[pb.taxis[k].initPos, pb.custs[c.id].orig]))
                else
                    append!(actions[k].path, getPath(pb, pb.custs[custs[i-1]].dest, pb.custs[c.id].orig,
                    c.tSup - tt[pb.custs[custs[i-1]].dest, pb.custs[c.id].orig]))
                end
                append!(actions[k].path, getPath(pb,pb.custs[c.id].orig,
                pb.custs[c.id].dest, c.tSup + customerTime))
                push!(actions[k].custs, CustomerAssignment(
                c.id, c.tSup, c.tSup + 2*pb.customerTime + tt[pb.custs[c.id].orig,
                pb.custs[c.id].dest]))
                currentCust[k] += 1
            elseif c.tInf < endTime
                c.tInf = endTime
            else
                break
            end
        end
    end

    println("===============")
	@printf("%.2f %% solved", 100 * endTime / om.pb.nTime)

	return actions
end
