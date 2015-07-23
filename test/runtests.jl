using TaxiSimulation
using Base.Test

tests = [
    # "manhattan",
    "shortestPathTests",
    "squareCity",
    "metropolis",
    "online"
    ]
testdir = joinpath(Pkg.dir("TaxiSimulation"),"test")


for t in tests
    tp = joinpath(testdir,"$(t).jl")
    println("running $(tp) ...")
    include(tp)
end

println("All tests are good!")
