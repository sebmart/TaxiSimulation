using TaxiSimulation
using LightGraphs
cd("/Users/bzeng/.julia/v0.4/TaxiSimulation/src/online")
include("onlineSimulation2.jl")
include("IterativeOffline.jl")
problem = Metropolis(8, 8)
generateProblem!(problem, 5, 0.1, now(), now() + Dates.Hour(3))

s1 = onlineSimulation2(problem, IterativeOffline(90.0), period = 10.0)
testSolution(problem, s1)

s2 = onlineSimulation2(problem, IterativeOffline2(90.0), period = 10.0)
testSolution(problem, s2)

include("uber.jl")
s3 = onlineSimulation2(problem, Uber(90.0), period = 10.0)
testSolution(problem, s3)
printSolution(s3)

visualize(problem, s3)
