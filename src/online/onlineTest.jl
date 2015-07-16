using TaxiSimulation
using LightGraphs

problem = Metropolis(8, 8)
generateProblem!(problem, 10, 0.2, now(), now() + Dates.Hour(3))

problem2 = Square
cd("/Users/bzeng/.julia/v0.4/TaxiSimulation/src/online")

# onlineSimulation(problem, IterativeOffline(90), period = 10)
# cd("Dropbox (MIT)/7 Coding/UROP/taxi-simulation/src/online")


include("onlineSimulation.jl")
include("IterativeOffline.jl")
s1 = onlineSimulation(problem, IterativeOffline(90.0), period = 10.0)
visualize(problem, s1)

include("onlineSimulation.jl")
include("IterativeOffline2.jl")
s2 = onlineSimulation(problem, IterativeOffline2(90.0), period = 10.0)
visualize(problem, s2)

include("onlineSimulation.jl")
include("uber.jl")
s3 = onlineSimulation(problem, Uber(90.0), period = 10.0, noTCall = true)
visualize(problem, s3)
