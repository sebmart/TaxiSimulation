using TaxiSimulation
# using Gadfly, Cairo

# using LightGraphs
# cd("/Users/bzeng/.julia/v0.4/TaxiSimulation/src/tools/")
# using("tools.jl")

function loadSolution(sol::TaxiSolution)
	revenue = sol.cost
	notServed = 0
	for flag in sol.notTaken
		if !flag
			notServed += 1
		end
	end
	return (-revenue, notServed * 1.0 / length(sol.notTaken))
end

profit = zeros(6)
servedCustomers = zeros(6)

for i in 1:10
  problem = SquareCity()
  generateProblem!(problem)

  @time s1 = TaxiSolution(problem, intervalOpt(problem, timeLimit = 500))
  testSolution(problem, s1)
  profit[1] = (profit[1] * (i - 1) + loadSolution(s1)[1]) / i
  servedCustomers[1] = (servedCustomers[1] * (i - 1) + loadSolution(s1)[2]) / i

  using TaxiSimulation
  problem = Metropolis()
  generateProblem!(problem)
  @time s2a = onlineSimulation(problem, IterativeOffline(5.0, 60.0))
  @time s2a = onlineSimulation(problem, IterativeOffline(5.0, 60.0, warmStart = true))
  @time s2c = onlineSimulation(problem, IterativeOffline(5.0, 60.0, completeMoves = true), verbose = true)
  @time s2d = onlineSimulation(problem, IterativeOffline(5.0, 60.0, completeMoves = true, warmStart = true), verbose = true)
  testSolution(problem, s2)
  profit[2] = (profit[2] * (i - 1) + loadSolution(s2)[1]) / i
  servedCustomers[2] = (servedCustomers[2] * (i - 1) + loadSolution(s2)[2]) / i

  try
    s3 = onlineSimulation(problem, IterativeOffline(5.0, 60.0, completeMoves = true), verbose = true)
    testSolution(problem, s3)
    profit[3] = (profit[3] * (i - 1) + loadSolution(s3)[1]) / i
    servedCustomers[3] = (servedCustomers[3] * (i - 1) + loadSolution(s3)[2]) / i
  catch
    println("Solution $(i) for Iterative Offline variant failed.")
    break
  end

  s4 = onlineSimulation(problem, FixedAssignment())
  testSolution(problem, s4)
  profit[4] = (profit[4] * (i - 1) + loadSolution(s4)[1]) / i
  servedCustomers[4] = (servedCustomers[4] * (i - 1) + loadSolution(s4)[2]) / i

  s5 = onlineSimulation(problem, Uber())
  testSolution(problem, s5)
  profit[5] = (profit[5] * (i - 1) + loadSolution(s5)[1]) / i
  servedCustomers[5] = (servedCustomers[5] * (i - 1) + loadSolution(s5)[2]) / i

  s6 = onlineSimulation(problem, Uber(removeTmaxt = false))
  testSolution(problem, s6)
  profit[6] = (profit[6] * (i - 1) + loadSolution(s6)[1]) / i
  servedCustomers[6] = (servedCustomers[6] * (i - 1) + loadSolution(s6)[2]) / i
end

for i in 1:10
  problem = loadTaxiPb("manhattan")
  date = DateTime(2013,01,10,12,00)
  generateProblem!(problem, 100, date, date+Dates.Minute(30), demand = 0.1)

  @time s1 = TaxiSolution(problem, intervalOpt(problem, timeLimit = 500))
  testSolution(problem, s1)
  profit[1] = (profit[1] * (i - 1) + loadSolution(s1)[1]) / i
  servedCustomers[1] = (servedCustomers[1] * (i - 1) + loadSolution(s1)[2]) / i

  @time s2 = onlineSimulation(problem, IterativeOffline(60.0, 300.0))
  @time s2 = onlineSimulation(problem, IterativeOffline(60.0, 300.0, warmStart = true))
  testSolution(problem, s2)
  profit[2] = (profit[2] * (i - 1) + loadSolution(s2)[1]) / i
  servedCustomers[2] = (servedCustomers[2] * (i - 1) + loadSolution(s2)[2]) / i

  @time s3 = onlineSimulation(problem, IterativeOffline(5.0, 60.0, completeMoves = true))
  testSolution(problem, s3)
  profit[3] = (profit[3] * (i - 1) + loadSolution(s3)[1]) / i
  servedCustomers[3] = (servedCustomers[3] * (i - 1) + loadSolution(s3)[2]) / i

  @time s4 = onlineSimulation(problem, FixedAssignment())
  testSolution(problem, s4)
  profit[4] = (profit[4] * (i - 1) + loadSolution(s4)[1]) / i
  servedCustomers[4] = (servedCustomers[4] * (i - 1) + loadSolution(s4)[2]) / i

  @time s5 = onlineSimulation(problem, Uber())
  testSolution(problem, s5)
  profit[5] = (profit[5] * (i - 1) + loadSolution(s5)[1]) / i
  servedCustomers[5] = (servedCustomers[5] * (i - 1) + loadSolution(s5)[2]) / i

  @time s6 = onlineSimulation(problem, Uber(removeTmaxt = false))
  testSolution(problem, s6)
  profit[6] = (profit[6] * (i - 1) + loadSolution(s6)[1]) / i
  servedCustomers[6] = (servedCustomers[6] * (i - 1) + loadSolution(s6)[2]) / i
end


using Plotly

trace1 = [
  "x" => [profit[i] for i in 1:length(profit)],
  "y" => [servedCustomers[i] for i in 1:length(servedCustomers)],
  "mode" => "markers",
  "text" => ["Offline intervalOpt", "IterativeOffline intervalOpt", "IterativeOffline variant intervalOpt", "FixedAssignment", "Uber", "Uber variant"],
  "type" => "scatter"
]

data = [trace1]
layout = [
  "title" => "Metropolis Online Simulation",
  "xaxis" => [
    "title" => "Average Profit",
  ],
  "yaxis" => [
    "title" => "Average Percentage Customers Served",
  ]
]
response = Plotly.plot(data, ["filename" => "basic-line", "fileopt" => "overwrite"])
plot_url = response["url"]