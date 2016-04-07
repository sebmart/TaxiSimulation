###################################################
## offline/flow.jl
## Fix pick-up time => network flow problem
###################################################


"""
    `flowSolve`: LP formulation of offline taxi assignment
    - the links provided all need to be feasible!!
"""

function flowSolve(pb::TaxiProblem, l::CustomerLinks=allLinks(pb); verbose::Bool=true, solverArgs...)
    taxi = pb.taxis
    cust = pb.custs
    if length(cust) == 0.
        return OfflineSolution(pb)
    end

    #short alias
    tt = getPathTimes(pb.times)
    tc = getPathTimes(pb.costs)

    #Compute the list of the lists of customers that can be taken
    #before each customer
    prv, nxt = l.prv, l.nxt

    #Solver : Gurobi (modify parameters)
    of = verbose ? 1:0
    m = Model(solver= GurobiSolver(OutputFlag=of; solverArgs...))

    # =====================================================
    # Decision variables
    # =====================================================

    #Taxi k takes customer c2, right after customer c1
    @defVar(m, 0<=x[c1=keys(prv), c2 = nxt[c1]]<=1)
    #Taxi k takes customer c, as a first customer
    @defVar(m, 0<=y[k=eachindex(taxi), c=nxt[-k]]<=1)
    #Customer c is picked-up
    @defVar(m, 0<=p[c=keys(prv)]<=1)

    # =====================================================
    # Objective (do not depend on time windows!)
    # =====================================================
    #Price paid by customers
    @defExpr(m, customerCost, sum{
    (tc[cust[c1].dest, cust[c2].orig] +
    tc[cust[c2].orig, cust[c2].dest] - cust[c2].fare) * x[c1, c2],
    c1=keys(prv), c2 = nxt[c1]})

    #Price paid by "first customers"
    @defExpr(m, firstCustomerCost, sum{
    (tc[taxi[k].initPos, cust[c].orig] +
    tc[cust[c].orig, cust[c].dest] - cust[c].fare) * y[k, c],
    k=eachindex(taxi), c=nxt[-k]})

    #Busy time
    @defExpr(m, busyTime, sum{
    (tt[cust[c1].dest, cust[c2].orig] +
    tt[cust[c2].orig, cust[c2].dest] )*(-pb.waitingCost) * x[c1, c2],
    c1=keys(prv), c2 = nxt[c1]})

    #Busy time during "first customer"
    @defExpr(m, firstBusyTime, sum{
    (tt[taxi[k].initPos, cust[c].orig] +
    tt[cust[c].orig, cust[c].dest])*(-pb.waitingCost) * y[k, c],
    k=eachindex(taxi), c=nxt[-k]})

    @setObjective(m, Min, customerCost + firstCustomerCost +
    busyTime + firstBusyTime + pb.simTime*length(taxi)*pb.waitingCost )

    # =====================================================
    # Constraints
    # =====================================================
    # taxi nodes (entering one flow, might exit immediately)
    @addConstraint(m, cs1[k=eachindex(taxi)],
    sum{y[k, c], c=nxt[-k]} <= 1)
    # customer nodes : entry
    @addConstraint(m, cs2[c=keys(prv)],
    sum{x[c1, c], c1 = filter(x->x>0, prv[c])} +
    sum{y[-k, c], k  = filter(x->x<0, prv[c])} == p[c])
    # customer nodes : exit
    @addConstraint(m, cs2[c=keys(prv)],
    sum{x[c, c1], c1= nxt[c]} <= p[c])
    #Each customer can only be taken at most once and can only have one other customer before
    @addConstraint(m, cs1[c=keys(prv)],
    sum{x[c1, c], c1= filter(x->x>0, prv[c])} +
    sum{y[-k, c], k = filter(x->x<0, prv[c])} <= 1)

    status = solve(m)
    if status == :Infeasible
        error("Model is infeasible")
    end

    custs = [CustomerTimeWindow[] for k in eachindex(taxi)]
    rejected = IntSet(keys(prv))
    # reconstruct solution
    for k=eachindex(taxi), c=nxt[-k]
        if getValue(y[k, c]) > 0.9
            push!(custs[k], CustomerTimeWindow(c, 0., 0.))
            c1 = c
            delete!(rejected, c)
            anotherCust = true
            while anotherCust
                anotherCust = false
                for c2 in nxt[c1]
                    if getValue(x[c1, c2]) > 0.9
                        push!(custs[k], CustomerTimeWindow(c2, 0., 0.))
                        delete!(rejected, c2)
                        anotherCust = true; c1 = c2; break;
                    end
                end
            end
        end
    end

    return OfflineSolution(pb, updateTimeWindows!(pb, custs), rejected, - getObjectiveValue(m))
end
