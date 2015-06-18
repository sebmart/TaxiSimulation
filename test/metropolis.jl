width, nSub = 6, 6;
nTaxis, demand = 20, 1.0;
tStart, tEnd = now(), now() + Hour(2);
city = Metropolis(width, nSub);
generateProblem!(city, nTaxis, demand, tStart, tEnd);
sol = localDescent(city, 100)
