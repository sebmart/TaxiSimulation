###################################################
## visualization/taxivisualizer.jl
## Visualizes a TaxiSolution Object
###################################################

visualize(s::TaxiSolution) = visualize(TaxiVisualizer(s))
"""
    `TaxiVisualizer`: NetworkVisualizer that shows taxis actions
"""
type TaxiVisualizer <: NetworkVisualizer
    # Mandatory attributes
    network::Network
    window::RenderWindow
    nodes::Vector{CircleShape}
    roads::Dict{Tuple{Int,Int},Line}

	"The solution to plot"
	s::TaxiSolution
	"Taxi shapes"
	taxiShape::Vector{CircleShape}
	"Customer shapes"
	custShape::Vector{CircleShape}
	"Current customers, that need to be drawn"
	drawnCust::IntSet
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
    # set up taxis
end

function visualEvent(v::TaxiVisualizer, event::Event)
	if get_type(event) == EventType.KEY_PRESSED
		k = get_key(event).key_code
        if k == KeyCode.SPACE #pause and play
			v.simPaused = !v.simPaused
		elseif k == KeyCode.E #reverse time
			v.simSpeed = -v.simSpeed
		end
	end
end

function visualUpdate(v::TaxiVisualizer,frameTime::Float64)
	# Accelerate speed
	is_key_pressed(KeyCode.Q) && (v.simSpeed *= 2^frameTime)
	# Reduce speed
	is_key_pressed(KeyCode.W) && (v.simSpeed /= 2^frameTime)

	# change time
	!v.simPaused && (v.simTime += frameTime*v.simSpeed)


	#plot all taxis and current customers
	for s in v.taxiShape
		draw(v.window,s)
	end
	for cId in v.drawnCust
		draw(v.window, custShape[cId])
	end
end
