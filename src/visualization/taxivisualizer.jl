###################################################
## visualization/taxivisualizer.jl
## Visualizes a TaxiSolution Object: use an IntervalTree to know what to draw when
###################################################

visualize(s::TaxiSolution)   = visualize(TaxiVisualizer(s))
visualize(s::OfflineSolution)= visualize(TaxiSolution(s))

"""
	`TaxiEvent` => element that represent a taxi to draw
	- taxi moves from n1 to n2 (or stays)
"""
immutable TaxiEvent
	taxi::Int
	n1::Int
	n2::Int
end

"""
	`CustEvent` => element that represent customer to draw
	- action > 0 => represents taxi
	- action <0 => represent waiting location
	- c < 0 => rejected
"""
immutable CustEvent
	cust::Int
	action::Int
end

"""
    `TaxiVisualizer`: NetworkVisualizer that shows taxis actions
"""
type TaxiVisualizer <: NetworkVisualizer
    # Mandatory attributes
    network::Network
    window::RenderWindow
    nodes::Vector{CircleShape}
    roads::Dict{Tuple{Int,Int},Line}
	nodeRadius::Float64

	"The solution to plot"
	s::TaxiSolution
	"All the taxi events to draw"
	taxiEvents::IntervalMap{Float64,TaxiEvent}
	"All the customer events to draw"
	custEvents::IntervalMap{Float64,CustEvent}
	"Taxi shapes"
	taxiShape::Vector{CircleShape}
	"Waiting customers shapes"
	custWaitShape::Vector{CircleShape}
	"Driving customers shapes"
	custDriveShape::Vector{CircleShape}
	"Current time in simulation"
	simTime::Float64
	"seconds of simulation / seconds of real time"
	simSpeed::Float64
	"true if simulation is paused"
	simPaused::Bool
    function TaxiVisualizer(s::TaxiSolution)
        obj = new()
        obj.network = s.pb.network
		obj.s = s
        return obj
    end
end

function visualInit(v::TaxiVisualizer)
	v.simTime  = 0.
	v.simSpeed = 1.
	v.simPaused = false

    # set up shapes
	v.taxiShape = [CircleShape() for i in eachindex(v.s.pb.taxis)]
	for s in v.taxiShape
		set_fillcolor(s, SFML.Color(255,0,0))
	end
	v.custWaitShape  = [CircleShape() for i in 1:nNodes(v.network)]
	for s in v.custWaitShape
		set_pointcount(s,4) #customers are "squares"
	end
	v.custDriveShape = [CircleShape() for i in eachindex(v.s.pb.taxis)]
	for s in v.custDriveShape
		set_pointcount(s,4)
		set_fillcolor(s, SFML.Color(0,255,0))
	end
	visualScale(v)

	v.taxiEvents, v.custEvents = constructIntervals(v)
end

function visualEvent(v::TaxiVisualizer, event::Event)
	if get_type(event) == EventType.KEY_PRESSED
		k = get_key(event).key_code
        if k == KeyCode.SPACE #pause and play
			v.simPaused = !v.simPaused
		elseif k == KeyCode.R #reverse time
			v.simSpeed = -v.simSpeed
		end
	end
end

function visualUpdate(v::TaxiVisualizer, frameTime::Float64)
	# Accelerate speed
	is_key_pressed(KeyCode.E) && (v.simSpeed *= 4^frameTime)
	# Reduce speed
	is_key_pressed(KeyCode.W) && (v.simSpeed /= 4^frameTime)

	# change time
	!v.simPaused && (v.simTime += frameTime*v.simSpeed)
	minutes, seconds = minutesSeconds(v.simTime)
	set_title(v.window, "Simulation time : $(minutes)m$(seconds)s")

	# Iterate through taxis to plot
	for interval in intersect(v.taxiEvents, (v.simTime,v.simTime))
		t1, t2, e = interval.first, interval.last, interval.value
		if e.n1 == e.n2
			node = v.network.nodes[e.n1]
			pos = Vector2f(node.x,-node.y)
		else
			p1, p2 = get_points(v.roads[e.n1,e.n2])
			l = (v.simTime-t1)/(t2-t1)
			pos = Vector2f((1-l) * p1.x + l * p2.x, (1-l) * p1.y + l * p2.y)
		end
		set_position(v.taxiShape[e.taxi],pos-Vector2f(v.nodeRadius*1.5,v.nodeRadius*1.5))
		draw(v.window,v.taxiShape[e.taxi])
	end
	# Iterate through customers to plot
	for interval in intersect(v.custEvents, (v.simTime,v.simTime))
		t1, t2, e = interval.first, interval.last, interval.value
		if e.action >0 # in taxi
			pos = get_position(v.taxiShape[e.action])
			set_position(v.custDriveShape[e.action], pos + Vector2f(v.nodeRadius*0.3,v.nodeRadius*0.3))
			draw(v.window,v.custDriveShape[e.action])
		else #waiting
			loc = -e.action
			if e.cust < 0 #rejected
				set_fillcolor(v.custWaitShape[loc], SFML.Color(255,255,255))
			else
				set_fillcolor(v.custWaitShape[loc], SFML.Color(0,255,0))
			end
			node = v.network.nodes[loc]
			pos = Vector2f(node.x,-node.y)
			set_position(v.custWaitShape[loc],pos-Vector2f(v.nodeRadius*1.2,v.nodeRadius*1.2))
			draw(v.window,v.custWaitShape[loc])
		end
	end
end

function visualScale(v::TaxiVisualizer)
	for s in v.taxiShape
		set_radius(s, v.nodeRadius*1.5)
	end
	for (i,no) in enumerate(v.nodes)		#Waiting cust
		pos = get_position(no)
		s = v.custWaitShape[i]
		set_radius(s, v.nodeRadius*1.2)
        set_position(s, pos - Vector2f(v.nodeRadius*1.2,v.nodeRadius*1.2))
	end
	for s in v.custDriveShape		#Moving cust
		set_radius(s, v.nodeRadius*1.2)
	end
end


"""
	`constructIntervals`, construct an interval tree to be able to efficiently access
	the situation at any time t
"""
function constructIntervals(v::TaxiVisualizer)
	taxiEvents = IntervalValue{Float64,TaxiEvent}[]
	custEvents = IntervalValue{Float64,CustEvent}[]

	for a in v.s.actions
		# adding all the taxi moves
		k = a.taxiID
		tPrev = v.s.pb.taxis[k].initTime
		lastPos = v.s.pb.taxis[k].initPos
		for i in eachindex(a.times)
			t1, t2 = a.times[i]
			n = a.path[i+1]
			if t1 > tPrev
				push!(taxiEvents, IntervalValue{Float64,TaxiEvent}(tPrev,t1,TaxiEvent(k,lastPos,lastPos)))
			end
			push!(taxiEvents, IntervalValue{Float64,TaxiEvent}(t1,t2,TaxiEvent(k,lastPos,n)))
			tPrev = t2
			lastPos = n
		end
		push!(taxiEvents, IntervalValue{Float64,TaxiEvent}(tPrev,Inf,TaxiEvent(k,lastPos,lastPos)))
		# adding all the customers assignments
		for c in a.custs
			cus = v.s.pb.custs[c.id]
			if cus.tmin < c.timeIn #if wait before pickup
				push!(custEvents, IntervalValue{Float64,CustEvent}(cus.tmin, c.timeIn, CustEvent(c.id, -cus.orig)))
			end
			push!(custEvents, IntervalValue{Float64,CustEvent}(c.timeIn, c.timeOut, CustEvent(c.id, k)))
		end
	end
	# adding rejected customers
	for c in v.s.rejected
		cus = v.s.pb.custs[c]
		push!(custEvents, IntervalValue{Float64,CustEvent}(cus.tmin, cus.tmax, CustEvent(-c, -cus.orig)))
	end
	sort!(taxiEvents)
	sort!(custEvents)
	return IntervalMap{Float64, TaxiEvent}(taxiEvents), IntervalMap{Float64, CustEvent}(custEvents)
end
