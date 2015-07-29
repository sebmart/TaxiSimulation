using TaxiSimulation
n = 10
wTime = 120

# profit = [zeros(n) for i in 1:5]
# time = [zeros(n) for i in 1:5]
# problem = loadTaxiPb("manhattan")
# date = DateTime(2013,01,10,12,00)
# generateProblem!(problem, 100, date, date+Dates.Minute(30), demand = 0.1)

shifts = [10 * i for i in 0:12]
shifts = [5 * i for i in 0:24]
numShifts = length(shifts)
averageProfit = [zeros(5) for i in 1:length(shifts)]

for i in 1:n
  city = Metropolis()
  problem = generateProblem!(city, 15, 0.25, waitTime = wTime)
  
  for j in 1:length(shifts)
    p = copy(problem)
    shiftedCustomers = Customer[]
    for c in p.custs
      newC = Customer(c.id, c.orig, c.dest, min(c.tcall + shifts[j], c.tmin), c.tmin, c.tmaxt, c.price)
      push!(shiftedCustomers, newC)
    end
    p.custs = shiftedCustomers

    if i == 1
      s1 = TaxiSolution(p, intervalOpt(p, timeLimit = 1800))
      averageProfit[j][1] += - s1.cost 
    end

    s2 = onlineSimulation(p, IterativeOffline(5.0, 60.0, completeMoves = false, warmStart = true))
    averageProfit[j][2] += - s2.cost / n

    s3 = onlineSimulation(p, IterativeOffline(5.0, 60.0, completeMoves = true, warmStart = true))
    averageProfit[j][3] += - s3.cost / n

    s4 = onlineSimulation(p, FixedAssignment())
    averageProfit[j][4] += - s4.cost / n

    s5 = onlineSimulation(p, Uber(removeTmaxt = false))
    averageProfit[j][5] += - s5.cost / n
  end
end

profitMetropolis = copy(averageProfit)

using Plotly

trace1 = [
  "x" => shifts,
  "y" => [averageProfit[j][1] for j in 1:length(shifts)],
  "mode" => "lines+markers",
  "name" => "Offline intervalOpt",
  "type" => "scatter"
]

trace2 = [
  "x" => shifts,
  "y" => [averageProfit[j][2] for j in 1:length(shifts)],
  "mode" => "lines+markers",
  "name" => "IterativeOffline A",
  "type" => "scatter"
]

trace3 = [
  "x" => shifts,
  "y" => [averageProfit[j][3] for j in 1:length(shifts)],
  "mode" => "lines+markers",
  "name" => "IterativeOffline B",
  "type" => "scatter"
]

trace4 = [
  "x" => shifts,
  "y" => [averageProfit[j][4] for j in 1:length(shifts)],
  "mode" => "lines+markers",
  "name" => "Fixed Assignment",
  "type" => "scatter"
]

trace5 = [
  "x" => shifts,
  "y" => [averageProfit[j][5] for j in 1:length(shifts)],
  "mode" => "lines+markers",
  "name" => "Uber",
  "type" => "scatter"
]

data = [trace1, trace2, trace3, trace4, trace5]
response = Plotly.plot(data, ["filename" => "Profit vs $(numShifts) shifts in tcall", "fileopt" => "overwrite"])
plot_url = response["url"]

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
response = Plotly.plot(data, ["filename" => "Metropolis tCall += $(shift)", "fileopt" => "overwrite"])
plot_url = response["url"]