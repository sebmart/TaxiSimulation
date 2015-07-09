#Try full opt
# width, nTime, nTaxis, nCusts = 3, 20., 2, 3;
# city = SquareCity(width, discreteTime=true);
# generateProblem!(city, nTaxis, nTime, nCusts);
# sol = fullOpt(city);



#try simple opt
width, nTime, nTaxis, nCusts = 5, 50., 3, 10;
city = SquareCity(width, discreteTime=true);
generateProblem!(city, nTaxis, nTime, nCusts);

sol1 = fixedTimeOpt(city);
sol2 = intervalOpt(city);
sol3 = intervalOptContinuous(city);

@test_approx_eq_eps sol1.cost sol2.cost 1e-5
@test_approx_eq_eps sol2.cost sol3.cost 1e-5
@test_approx_eq_eps sol1.cost solutionCost(city, sol1.custs) 1e-5

sol = TaxiSolution(city,sol1)
#printing
printSolution(sol,verbose=0)
printSolution(sol,verbose=1)
printSolution(sol,verbose=2)

#Try interval opt and heuristics
width, nTime, nTaxis, nCusts = 8, 200., 10, 60;
city = SquareCity(width);
generateProblem!(city, nTaxis, nTime, nCusts);
sol2 = randomInsertions(city, 100)
sol3 = insertionsDescent(city, 100)
sol4 = localDescent(city,1000, sol3)
sol1  = intervalOpt(city, sol2);

@test sol1.cost <= sol2.cost
@test sol1.cost <= sol3.cost
@test sol1.cost <= sol4.cost

testSolution(city, sol1)
testSolution(city, sol2)
testSolution(city, sol3)
expandWindows!(city,sol4)
testSolution(city, sol4)
ts = TaxiSolution(city, sol1)

@test_approx_eq_eps sol1.cost solutionCost(city, sol1.custs) 1e-5
@test_approx_eq_eps sol1.cost solutionCost(city, ts.taxis) 1e-5

testSolution(city, IntervalSolution(city, ts))
