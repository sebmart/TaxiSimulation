
width, nSub = 5, 5;
nTaxis, demand = 15, 1.;
tStart, tEnd = now(), now() + Dates.Hour(2);

city = Metropolis(width, nSub);
generateProblem!(city, nTaxis, demand, tStart, tEnd);
sol = localDescent(city, 100, insertionsDescent(city,15))

testSolution(city,sol)

width, nSub = 4, 4;
nTaxis, demand = 10, 1.;
tStart, tEnd = now(), now() + Dates.Hour(1);

city = Metropolis(width, nSub, discreteTime=true);
generateProblem!(city, nTaxis, demand, tStart, tEnd);
sol1 = intervalOptDiscrete(city)
sol2 = intervalOptContinuous(city)
@test_approx_eq_eps sol1.cost sol2.cost 1e-5
