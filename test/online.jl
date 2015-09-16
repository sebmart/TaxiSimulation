println("""
    Online: Testing on SquareCity
""")

pb = squareCityProblem()
generateProblem!(pb)
sol1 = onlineSimulation(pb, FixedAssignment())
sol2 = onlineSimulation(pb, FixedAssignment(period = 0.01))
testSolution(pb,sol1)
testSolution(pb,sol2)

s= intervalOpt(pb)
@test s.cost < sol1.cost + 1e-5

#In the limit period => 0, in the case of continuous data, the results should be the same
# ! if bad luck generating the data, might not work (two tCall closer than 0.01)
@test_approx_eq_eps sol1.cost sol2.cost 1e-5


println("""
    Online: Testing on Metropolis
""")
#We are testing the iterative offline with different parameters
pb = smallMetroProblem()
tUpdate, tHorizon = 5., 60.
solver = intervalOpt
sol = onlineSimulation(pb, IterativeOffline(tUpdate, tHorizon, solver, completeMoves=true))
testSolution(pb,sol)

#Test long updates and no completeMoves
tUpdate, tHorizon = 50., 100.
sol = onlineSimulation(pb, IterativeOffline(tUpdate, tHorizon, completeMoves=false))
testSolution(pb,sol)

#Test localDescent with printing
tUpdate, tHorizon = 5., 100.
solver = p -> localDescent(p,1000)
sol = onlineSimulation(pb, IterativeOffline(tUpdate, tHorizon, solver, completeMoves=false), verbose=true)
testSolution(pb,sol)

#Test localDescent with warmstart and zero-period
tUpdate, tHorizon = 0., 100.
solver = (p,i) -> localDescent(p,10000,i)
s1b = onlineSimulation(pb, IterativeOffline(tUpdate, tHorizon, solver, completeMoves = false, warmStart = true))
testSolution(pb, sol)

#test Uber
sol = onlineSimulation(pb, Uber())
testSolution(pb, sol)
