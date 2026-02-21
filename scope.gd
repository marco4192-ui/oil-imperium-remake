extends Control

# Wir machen das Scope größer für mehr Spielraum
const BASE_RADIUS = 200.0 

func _draw():
	# Mittelpunkt berechnen
	var center = size / 2
	
	# Wir malen 4 Kreise übereinander (von außen nach innen)
	
	# 1. Rot (Hintergrund / Tod)
	draw_circle(center, BASE_RADIUS, Color(0.8, 0, 0, 0.5)) 
	
	# 2. Orange (Gefahr) - 75% Radius (150px)
	draw_circle(center, BASE_RADIUS * 0.75, Color(1, 0.5, 0, 0.5))
	
	# 3. Gelb (Warnung) - 50% Radius (100px)
	draw_circle(center, BASE_RADIUS * 0.5, Color(1, 1, 0, 0.5))
	
	# 4. Grün (Sicher) - 25% Radius (50px)
	draw_circle(center, BASE_RADIUS * 0.25, Color(0, 0.8, 0, 0.5))
	
	# Fadenkreuz-Linien (Deko)
	draw_line(center - Vector2(BASE_RADIUS, 0), center + Vector2(BASE_RADIUS, 0), Color(0,0,0, 0.5), 2.0)
	draw_line(center - Vector2(0, BASE_RADIUS), center + Vector2(0, BASE_RADIUS), Color(0,0,0, 0.5), 2.0)
