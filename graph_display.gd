extends Control

# --- EINSTELLUNGEN ---
@export var line_color: Color = Color.GREEN
@export var dot_color: Color = Color.WHITE
@export var show_dots: bool = true
@export var line_width: float = 2.0

var data_points: Array = []
var max_value_override: float = -1.0 # Wenn > 0, nutzen wir das als Maximum für die Y-Achse

func set_data(data: Array, override_max: float = -1.0):
	data_points = data
	max_value_override = override_max
	queue_redraw() # Sagt Godot: "Bitte neu zeichnen!"

func _draw():
	if data_points.size() < 2:
		return # Wir brauchen mindestens 2 Punkte für eine Linie
		
	# 1. Skalierung berechnen
	var min_val = 0.0 # Wir fangen meist bei 0 an
	var max_val = 0.0
	
	if max_value_override > 0:
		max_val = max_value_override
	else:
		# Auto-Scale
		for val in data_points:
			if val > max_val: max_val = val
	
	if max_val == 0: max_val = 100.0 # Division durch Null verhindern
	
	# Padding damit es hübsch aussieht
	var padding_top = 10.0
	var padding_bottom = 10.0
	var available_height = size.y - (padding_top + padding_bottom)
	var step_x = size.x / (data_points.size() - 1)
	
	var prev_pos = Vector2.ZERO
	
	# 2. Punkte zeichnen
	for i in range(data_points.size()):
		var value = data_points[i]
		
		# Y berechnen (Invertiert, da 0 oben ist)
		var normalized_val = (value - min_val) / (max_val - min_val)
		var y_pos = size.y - padding_bottom - (normalized_val * available_height)
		var x_pos = i * step_x
		
		var current_pos = Vector2(x_pos, y_pos)
		
		if i > 0:
			draw_line(prev_pos, current_pos, line_color, line_width, true)
			
		if show_dots:
			draw_circle(current_pos, 3.0, dot_color)
			
		prev_pos = current_pos
