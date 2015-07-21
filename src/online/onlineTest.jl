using TaxiSimulation
# using LightGraphs
# cd("/Users/bzeng/.julia/v0.4/TaxiSimulation/src/tools/")
# using("tools.jl")

problem = Metropolis(8, 8)
generateProblem!(problem, 2, 0.5, now(), now() + Dates.Hour(3))
# s0 = intervalOpt(problem)

s1 = onlineSimulation(problem, IterativeOffline(200.0, true, true), period = 5.0)
testSolution(problem, s1)

s2 = onlineSimulation(problem, IterativeOffline(200.0, true, false), period = 5.0)
testSolution(problem, s2)

s3 = onlineSimulation(problem, FixedAssignment(false), period = 10.0)
testSolution(problem, s3)

s4 = onlineSimulation(problem, Uber(false), period = 10.0)
testSolution(problem, s4)

visualize(problem, s1)