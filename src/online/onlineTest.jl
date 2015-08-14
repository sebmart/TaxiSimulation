using TaxiSimulation

p1 = Float64[]
p2 = Float64[]
p3 = Float64[]

for i in 1:10
  taxis = 100
  demand = 0.05
  cityA = loadTaxiPb("manhattan")
  dateA = DateTime(2013, 03, 08, 12, 00)
  generateProblem!(cityA, taxis, dateA, dateA + Dates.Minute(60), demand = demand)

  # cityB = loadTaxiPb("manhattan")
  # dateB = DateTime(2013, 03, 01, 12, 00)
  # generateProblem!(cityB, taxis, dateB, dateB + Dates.Minute(60), demand = demand)
  # cityB.custs = Customer[]

  # s5b = onlineSimulation(cityA, cityB, Uber2(removeTmaxt = false, period = 300.0))  
  # testSolution(cityA, s5b)

  # s5a = onlineSimulation(cityA, Uber(removeTmaxt = false, period = 300.0))
  # testSolution(cityA, s5a)

  @time s2a = onlineSimulation(cityA, IterativeOffline(60.0, 300.0, completeMoves = false, warmStart = true), verbose = true)
  @time s2b = onlineSimulation(cityA, TaxiSimulation.IterativeOfflineVariant(60.0, 300.0, completeMoves = false, warmStart = true), verbose = true)
  @time s2c = onlineSimulation(cityA, TaxiSimulation.IterativeOfflineVariant2(60.0, 300.0, completeMoves = false, warmStart = true))

  push!(p1, -s2a.cost)
  push!(p2, -s2b.cost)
  push!(p3, -s2c.cost)
end

using Plotly

trace1 = [
  "x" => [1:length(p1)],
  "y" => p1,
  "mode" => "lines+markers",
  "name" => "Iterative Offline",
  "type" => "scatter"
]
trace2 = [
  "x" => [1:length(p2)],
  "y" => p2,
  "mode" => "lines+markers",
  "name" => "Iterative Offline with Virtual Customers",
  "type" => "scatter"
]
trace3 = [
  "x" => [1:length(p3)],
  "y" => p3,
  "mode" => "lines+markers",
  "name" => "Iterative Offline with Demand Prediction",
  "type" => "scatter"
]

data = [trace1, trace2, trace3]
response = Plotly.plot(data, ["filename" => "Manhattan Iterative Offline Test 6 (tuning travel time limit)", "fileopt" => "overwrite"])
plot_url = response["url"]



p1 = Float64[]
p2 = Float64[]
p3 = Float64[]
p4 = Float64[]
p5 = Float64[]
# taxis = 100
taxis = 100
customerDemand = 0.1
# customerDemand = [0.01, 0.05, 0.1, 0.2]
n = 10

tic()
for i in 1:n
  city = loadTaxiPb("manhattan")
  date = DateTime(2013,01,10,12,00)
  generateProblem!(city, taxis, date, date+Dates.Minute(30), demand = customerDemand)
  # city = Metropolis()
  # generateProblem!(city)
  # city = SquareCity()
  # generateProblem!(city)
  p = copy(city)
  shiftedCustomers = Customer[]
  for c in p.custs
    newC = Customer(c.id, c.orig, c.dest, min(c.tcall + 120, c.tmin), c.tmin, c.tmaxt, c.price)
    push!(shiftedCustomers, newC)
  end
  p.custs = shiftedCustomers
  solver = p -> localDescent(p,1000)
  s1 = TaxiSolution(p, localDescent(p, 10000))
  s2 = onlineSimulation(p, IterativeOffline(0.0, 300.0, solver, completeMoves=false))
  s3 = onlineSimulation(p, IterativeOffline(0.0, 300.0, completeMoves = true, warmStart = true))
  s4 = onlineSimulation(p, FixedAssignment(period = 0.0))
  s5 = onlineSimulation(p, Uber(removeTmaxt = false))

  push!(p1, -s1.cost)
  push!(p2, -s2.cost)
  push!(p3, -s3.cost)
  push!(p4, -s4.cost)
  push!(p5, -s5.cost)
end
x = toq()

trace1 = [
  "x" => [1:length(p1)],
  "y" => p1,
  "mode" => "lines+markers",
  "name" => "Offline intervalOpt",
  "type" => "scatter"
]
trace2 = [
  "x" => [1:length(p2)],
  "y" => p2,
  "mode" => "lines+markers",
  "name" => "IterativeOffline A",
  "type" => "scatter"
]
trace3 = [
  "x" => [1:length(p3)],
  "y" => p3,
  "mode" => "lines+markers",
  "name" => "IterativeOffline B",
  "type" => "scatter"
]
trace4 = [
  "x" => [1:length(p4)],
  "y" => p4,
  "mode" => "lines+markers",
  "name" => "FixedAssignment",
  "type" => "scatter"
]
trace5 = [
  "x" => [1:length(p5)],
  "y" => p5,
  "mode" => "lines+markers",
  "name" => "Uber",
  "type" => "scatter"
]

data = [trace1, trace2, trace3, trace4, trace5]
# response = Plotly.plot(data, ["filename" => "Manhattan with $(taxis) taxis, $(minutes) minutes, $(customerDemand) customer demand"])
response = Plotly.plot(data, ["filename" => "Default Metropolis"])
# response = Plotly.plot(data, ["filename" => "Square City with half demand", "fileopt" => "overwrite"])
plot_url = response["url"]


n = 10
shifts = [10 * i for i in 0:12]
numShifts = length(shifts)
averageProfit0A = [zeros(5) for i in 1:length(shifts)]
averageProfit5A = [zeros(5) for i in 1:length(shifts)]
averageProfit10A = [zeros(5) for i in 1:length(shifts)]
averageProfit0B = [zeros(5) for i in 1:length(shifts)]
averageProfit5B = [zeros(5) for i in 1:length(shifts)]
averageProfit10B = [zeros(5) for i in 1:length(shifts)]

for i in 1:n
  p = Metropolis()
  generateProblem!(p, 30, 0.5)
  for j in 1:length(shifts)
    p = copy(city)
    shiftedCustomers = Customer[]
    for c in p.custs
      newC = Customer(c.id, c.orig, c.dest, min(c.tcall + shifts[j], c.tmin), c.tmin, c.tmaxt, c.price)
      push!(shiftedCustomers, newC)
    end
    p.custs = shiftedCustomers

    if i == 1
      s1 = TaxiSolution(p, intervalOpt(p, timeLimit = 1800))
      averageProfit0A[j][1] += - s1.cost 
      averageProfit5A[j][1] += - s1.cost 
      averageProfit10A[j][1] += - s1.cost 
      averageProfit0B[j][1] += - s1.cost 
      averageProfit5B[j][1] += - s1.cost 
      averageProfit10B[j][1] += - s1.cost 
    end

    s2 = onlineSimulation(p, IterativeOffline(0.0, 60.0, completeMoves = false, warmStart = true), verbose = true)
    averageProfit0A[j][2] += - s2.cost / n
    s2 = onlineSimulation(p, IterativeOffline(5.0, 60.0, completeMoves = false, warmStart = true))
    averageProfit5A[j][2] += - s2.cost / n
    s2 = onlineSimulation(p, IterativeOffline(10.0, 60.0, completeMoves = false, warmStart = true))
    averageProfit10A[j][2] += - s2.cost / n

    s3 = onlineSimulation(p, IterativeOffline(0.0, 60.0, completeMoves = true, warmStart = true))
    averageProfit0A[j][3] += - s3.cost / n
    s3 = onlineSimulation(p, IterativeOffline(5.0, 60.0, completeMoves = true, warmStart = true))
    averageProfit5A[j][3] += - s3.cost / n
    s3 = onlineSimulation(p, IterativeOffline(10.0, 60.0, completeMoves = true, warmStart = true))
    averageProfit10A[j][3] += - s3.cost / n

    s4 = onlineSimulation(p, FixedAssignment(period = 0.0))
    averageProfit0A[j][4] += - s4.cost / n
    averageProfit0B[j][4] += - s4.cost / n

    s4 = onlineSimulation(p, FixedAssignment(period = 5.0))
    averageProfit5A[j][4] += - s4.cost / n
    averageProfit5B[j][4] += - s4.cost / n

    s4 = onlineSimulation(p, FixedAssignment(period = 10.0))
    averageProfit10B[j][4] += - s4.cost / n
    averageProfit10A[j][4] += - s4.cost / n

    s5 = onlineSimulation(city, Uber(removeTmaxt = false))
    averageProfit0A[j][5] += - s5.cost / n
    averageProfit5A[j][5] += - s5.cost / n
    averageProfit10A[j][5] += - s5.cost / n
    averageProfit0B[j][5] += - s5.cost / n
    averageProfit5B[j][5] += - s5.cost / n
    averageProfit10B[j][5] += - s5.cost / n

    solver = x -> localDescent(x, 1000)
    s2 = onlineSimulation(p, IterativeOffline(0.0, 60.0, solver, completeMoves = false))
    averageProfit0B[j][2] += - s2.cost / n
    s2 = onlineSimulation(p, IterativeOffline(5.0, 60.0, solver, completeMoves = false))
    averageProfit5B[j][2] += - s2.cost / n
    s2 = onlineSimulation(p, IterativeOffline(10.0, 60.0, solver, completeMoves = false))
    averageProfit10B[j][2] += - s2.cost / n

    s3 = onlineSimulation(p, IterativeOffline(0.0, 60.0, solver, completeMoves = true))
    averageProfit0B[j][3] += - s3.cost / n
    s3 = onlineSimulation(p, IterativeOffline(5.0, 60.0, solver, completeMoves = true))
    averageProfit5B[j][3] += - s3.cost / n
    s3 = onlineSimulation(p, IterativeOffline(10.0, 60.0, solver, completeMoves = true))
    averageProfit10B[j][3] += - s3.cost / n
  end
end

averageProfit = [averageProfit0A, averageProfit5A, averageProfit10A, averageProfit0B, averageProfit5B, averageProfit10B]
names = ["period = 0.0, solver = intervalOpt", "period = 5.0, solver = intervalOpt", "period = 10.0, solver = intervalOpt",
         "period = 0.0, solver = localDescent", "period = 5.0, solver = localDescent", "period = 10.0, solver = localDescent"]

using Plotly
for i in 1:6
  trace1 = [
    "x" => shifts,
    "y" => [averageProfit[13 * (i - 1) + 1:13 * i][j][1] for j in 1:length(shifts)],
    "mode" => "lines+markers",
    "name" => "Offline intervalOpt",
    "type" => "scatter"
  ]

  trace2 = [
    "x" => shifts,
    "y" => [averageProfit[13 * (i - 1) + 1:13 * i][j][2] for j in 1:length(shifts)],
    "mode" => "lines+markers",
    "name" => "IterativeOffline A",
    "type" => "scatter"
  ]

  trace3 = [
    "x" => shifts,
    "y" => [averageProfit[13 * (i - 1) + 1:13 * i][j][3] for j in 1:length(shifts)],
    "mode" => "lines+markers",
    "name" => "IterativeOffline B",
    "type" => "scatter"
  ]

  trace4 = [
    "x" => shifts,
    "y" => [averageProfit[13 * (i - 1) + 1:13 * i][j][4] for j in 1:length(shifts)],
    "mode" => "lines+markers",
    "name" => "Fixed Assignment",
    "type" => "scatter"
  ]

  trace5 = [
    "x" => shifts,
    "y" => [averageProfit[13 * (i - 1) + 1:13 * i][j][5] for j in 1:length(shifts)],
    "mode" => "lines+markers",
    "name" => "Uber",
    "type" => "scatter"
  ]

  data = [trace1, trace2, trace3, trace4, trace5]
  response = Plotly.plot(data, ["filename" => "Profit vs $(numShifts) shifts in tcall, $(names[i])", "fileopt" => "overwrite"])
  plot_url = response["url"]
end
###############################################################################################
# Box plots
x1 = (["Offline intervalOpt" for i in 1:n])
x2 = (["IterativeOffline A" for i in 1:n])
x3 = (["IterativeOffline B" for i in 1:n])
x4 = (["Fixed Assignment" for i in 1:n])
x5 = (["Uber" for i in 1:n])

trace1 = [
  "x" => x1,
  "y" => [profitMetropolis[1][i] for i in 1:n],
  "name" => "Offline intervalOpt",
  "type" => "box"
]

trace2 = [
  "x" => x2,
  "y" => [profitMetropolis[2][i] for i in 1:n],
  "name" => "IterativeOffline A",
  "type" => "box"
]

trace3 = [
  "x" => x3,
  "y" => [profitMetropolis[3][i] for i in 1:n],
  "name" => "IterativeOffline B",
  "type" => "box"
]

trace4 = [
  "x" => x4,
  "y" => [profitMetropolis[4][i] for i in 1:n],
  "name" => "Fixed Assignment",
  "type" => "box"
]

trace5 = [
  "x" => x5,
  "y" => [profitMetropolis[5][i] for i in 1:n],
  "name" => "Uber",
  "type" => "box"
]

data = [trace1, trace2, trace3, trace4, trace5]
layout = [
  "title" => "Metropolis Online Simulation",
  "xaxis" => [
    "title" => "Online Algorithm",
  ],
  "yaxis" => [
    "title" => "Average Profit",
  ]
]
response = Plotly.plot(data, ["filename" => "Default Metropolis", "fileopt" => "overwrite"])
plot_url = response["url"]
