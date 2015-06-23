
width, nSub = 5, 5;
nTaxis, demand = 20, 1.2;
tStart, tEnd = now(), now() + Dates.Hour(2);

city = Metropolis(width, nSub);
generateProblem!(city, nTaxis, demand, tStart, tEnd);
sol = localDescent(city, 100, insertionsDescent(city,15))

testSolution(sol)
