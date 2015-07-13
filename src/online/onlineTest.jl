problem = Metropolis(8, 8)
generateProblem!(problem, 20, 0.45, now(), now() + Dates.Hour(3))
onlineSimulation(problem, IterativeOffline(90), period = 10)