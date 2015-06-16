

#Try full opt
width, nTime, nTaxis, nCusts = 3, 20, 2, 4;
city = SquareCity(width);
generateProblem!(city, nTaxis, nTime, nCusts);
sol = fullOpt(city);

#printing
printSolution(sol,verbose=0)
printSolution(sol,verbose=1)
printSolution(sol,verbose=2)

#try simple opt
width, nTime, nTaxis, nCusts = 5, 50, 3, 10;
city = SquareCity(width);
generateProblem!(city, nTaxis, nTime, nCusts);sol = simpleOpt(city);
sol2 = intervalBinOpt(city);

sol1 = simpleOpt(city);
sol2 = intervalBinOpt(city);

@test sol1.cost == sol2.cost


#Try interval opt and heuristics
width, nTime, nTaxis, nCusts = 8, 200, 10, 60;
city = SquareCity(width);
generateProblem!(city, nTaxis, nTime, nCusts);
sol2 = randomAssignment(city, 100)
sol3 = randomDescent(city, 100)
sol4 = localOpt(city,1000, sol3)
sol1  = intervalBinOpt(city, sol2);

@test sol1.cost <= sol2.cost
@test sol1.cost <= sol3.cost
@test sol1.cost <= sol4.cost

fixSolution!(city, sol1)
fixSolution!(city, sol2)
fixSolution!(city, sol3)
fixSolution!(city, sol4)

sol5 = TaxiSolution(city, sol1)
