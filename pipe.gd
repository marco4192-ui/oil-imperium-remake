extends Control

# Wir merken uns, wie oft gedreht wurde (0, 1, 2, 3)
# 0 = Oben/Rechts, 1 = Rechts/Unten, 2 = Unten/Links, 3 = Links/Oben
var rotation_id = 0

func _ready():
	# Zufällige Drehung beim Start
	rotation_id = randi() % 4
	update_visuals()

func _on_click_area_pressed():
	# BeFeedbackOverlay.show_msg("Klick auf Rohr!")
	rotation_id += 1
	if rotation_id > 3:
		rotation_id = 0
	update_visuals()
	
	# Dem Spiel sagen: "Hey, ich habe mich gedreht, prüf mal ob wir gewonnen haben!"
	get_parent().get_parent().check_connection()

func update_visuals():
	# Wir nutzen die normale Rotation von Godot (in Grad)
	rotation_degrees = rotation_id * 90
	# Da sich Controls um die Ecke oben-links drehen, müssen wir das Pivot anpassen
	pivot_offset = Vector2(50, 50)
