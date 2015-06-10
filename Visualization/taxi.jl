using SFML

window = RenderWindow("Taxi", 1200, 1200)
set_framerate_limit(window, 60)

event = Event()

view = View(Vector2f(600, 600), Vector2f(1200, 1200))

# # Create a line from p1 to p2
# p1 = Vector2f(640, 360)
# p2 = Vector2f(0, 0)
# line = Line(p1, p2, 1)
# set_fillcolor(line, SFML.black)

# # Make a circle 
# circle = CircleShape()
# set_radius(circle, 40)
# set_position(circle, Vector2f(500, 200))
# set_fillcolor(circle, SFML.red)

# # Make a square
# square = RectangleShape()
# set_size(square, Vector2f(60, 60))
# set_position(square, Vector2f(200, 400))
# set_fillcolor(square, SFML.yellow)

nodeX = [300, 500, 700, 900, 300, 500, 700, 900, 300, 500, 700, 900, 300, 500, 700, 900]
nodeY = [300, 300, 300, 300, 500, 500, 500, 500, 700, 700, 700, 700, 900, 900, 900, 900]

circles = CircleShape[]
for i = 1:16
	circle = CircleShape()
	set_radius(circle, 25)
	set_fillcolor(circle, SFML.black)
	set_position(circle, Vector2f(nodeX[i] - 25, nodeY[i] - 25))
	push!(circles, circle)
end

horizontalLines = Line[]
for i = 1:3
	for j = 0:3
		point = i + 4 * j
		p1 = Vector2f(nodeX[point], nodeY[point])
		p2 = Vector2f(nodeX[point + 1], nodeY[point + 1])
		line = Line(p1, p2, 1)
		set_fillcolor(line, SFML.black)
		push!(horizontalLines, line)
	end
end

verticalLines = Line[]
for i = 0:2
	for j = 1:4
		point = j + 4 * i
		p1 = Vector2f(nodeX[point], nodeY[point])
		p2 = Vector2f(nodeX[point + 4], nodeY[point + 4])
		line = Line(p1, p2, 1)
		set_fillcolor(line, SFML.black)
		push!(verticalLines, line)
	end
end

while isopen(window)
	while pollevent(window, event)
		if get_type(event) == EventType.CLOSED
			close(window)
		end
	end

	# Check keypresses
	if is_key_pressed(KeyCode.LEFT)
		# Move left
		move(view, Vector2f(-0.5, 0))
	end
	if is_key_pressed(KeyCode.RIGHT)
		# Move right
		move(view, Vector2f(0.5, 0))
	end
	if is_key_pressed(KeyCode.UP)
		# Move up
		move(view, Vector2f(0, -0.5))
	end
	if is_key_pressed(KeyCode.DOWN)
		# Move down
		move(view, Vector2f(0, 0.5))
	end
	# Zoom out
	if is_key_pressed(KeyCode.Z)
		zoom(view, 0.5)
		set_size(view, Vector2f(1600, 1200))
	end
	# Zoom in
	if is_key_pressed(KeyCode.X)
		zoom(view, 1.5)
		set_size(view, Vector2f(400, 300))
	end

	set_view(window, view)
	
	

	clear(window, SFML.white)
	for i = 1:length(circles)
		draw(window, circles[i])
	end
	for i = 1:length(horizontalLines)
		draw(window, horizontalLines[i])
	end
	# for i = 1:length(verticalLines)
	# 	draw(window, verticalLines)
	# end
	
	# circle_position = get_position(circle)
	# circle_position.x += 1
	# set_position(circle, circle_position)
	# draw(window, line)
	# draw(window, square)
	# draw(window, circle)
	display(window)
end
