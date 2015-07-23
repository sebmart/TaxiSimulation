city = SquareCity()
generateProblem!(city)
sol1 = onlineSimulation(city, FixedAssignment())
sol2 = onlineSimulation(city, FixedAssignment(period = 0.01))
testSolution(city,sol1)
testSolution(city,sol2)

s= intervalOpt(city)
@test s.cost < sol1.cost + 1e-5

#In the limit period => 0, in the case of continuous data, the results should be the same
# ! if bad luck generating the data, might not work (two tCall closer than 0.01)
@test_approx_eq_eps sol1.cost sol2.cost 1e-5

city = Metropolis()
generateProblem!(city)
tUpdate, tHorizon = 5., 60.
solver = intervalOpt
sol1 = onlineSimulation(city, IterativeOffline(tUpdate, tHorizon, solver, completeMoves=true))
testSolution(city,sol1)


tUpdate, tHorizon = 50., 100.
solver = pb -> localDescent(pb,1000)
sol1 = onlineSimulation(city, IterativeOffline(tUpdate, tHorizon, solver, completeMoves=false), verbose=true)
testSolution(city,sol1)
