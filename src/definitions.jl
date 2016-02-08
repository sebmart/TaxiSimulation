#----------------------------------------






"""
Type used to solve online simulation problems
Needs to implement initialize!(om::OnlineMethod, pb::TaxiProblem), update!(om::OnlineMethod,
    newEndTime::Float64, newCustomers::Vector{Customer})
    initialize! initializes a given OnlineMethod with a selected taxi problem without customers
    update! updates OnlineMethod to account for new customers, returns a list of TaxiActions
    since the last update
"""

abstract OnlineMethod

#time epsilon for float comparisons
