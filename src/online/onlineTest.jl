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
	return (revenue, notServed * 1.0 / length(sol.notTaken))
end

profit1 = zeros(5)
servedCustomers = zeros(5)

for i in 1:10
  problem = Metropolis(8, 8)
  generateProblem!(problem, 10, 0.5, now(), now() + Dates.Hour(3))
  
  s0 = TaxiSolution(intervalOpt(problem))
  testSolution(problem, s0)
  profit1[0] = 

  s1 = onlineSimulation(problem, IterativeOffline(10.0, 200.0))
  testSolution(problem, s1)
  push!(result1, loadSolution(s1))

  try
    s2 = onlineSimulation(problem, IterativeOffline(10.0, 200.0, completeMoves = true), verbose = true)
    testSolution(problem, s2)
    push!(result1, loadSolution(s2))
  catch
    println("Solution $(i) for Iterative Offline variant failed.")
    continue
  end

  s3 = onlineSimulation(problem, FixedAssignment())
  testSolution(problem, s3)
  push!(result1, loadSolution(s3))


  s4 = onlineSimulation(problem, Uber())
  testSolution(problem, s4)
  push!(result1, loadSolution(s4))

  s5 = onlineSimulation(problem, Uber(removeTmaxt = false))
  testSolution(problem, s5)
  push!(result1, loadSolution(s5))
end

using Plotly

trace1 = [
  "x" => [- result1[i][1] for i in 1:length(result1)],
  "y" => [result1[i][2] for i in 1:length(result1)],
  "mode" => "markers",
  "text" => ["Offline intervalOpt", "IterativeOffline intervalOpt", "IterativeOffline variant intervalOpt", "FixedAssignment", "Uber", "Uber variant"],
  "type" => "scatter"
]

data = [trace1]
layout = [
  "title" => "Metropolis Online Simulation",
  "xaxis" => [
    "title" => "Profit",
  ],
  "yaxis" => [
    "title" => "Customers Unserved",
  ]
]
response = Plotly.plot(data, ["filename" => "basic-line", "fileopt" => "overwrite"])
plot_url = response["url"]