
tStart, tEnd = now(), now() + Dates.Hour(2);

city = Manhattan(sp=true);
date = DateTime(2013,01,10,12,00)
generateProblem!(city,100,date,date+Dates.Minute(30), demand = 0.1)
sol = localDescent(city, 100, insertionsDescent(city,15))

testSolution(city,sol)
