extends Node2D

# --- Konfiguration ---
var total_depth = 1000.0
var current_depth = 0.0
var drill_speed = 60.0 

# --- Gameplay Physik ---
var crosshair_pos = Vector2.ZERO  
var velocity = Vector2.ZERO       

# --- Drift-Mechanik ---
var current_drift_dir = Vector2.ZERO 
var drift_strength = 600.0           
var drift_change_timer = 0.0         

# --- Balancing ---
var player_acceleration = 2500.0 
var friction = 0.90                  
var max_speed = 800.0          
var max_radius = 210.0 # Radius des Scopes

# --- Visuals ---
var start_y = 120.0  # Startposition oben
var end_y = 900.0    # Endposition unten

# --- Zonen Timer ---
var time_in_red = 0.0
var time_in_orange = 0.0
var time_in_yellow = 0.0

const LIMIT_RED = 2.0
const LIMIT_ORANGE = 4.0
const LIMIT_YELLOW = 6.0

# --- Offshore Support ---
var is_offshore = false
const LAND_BG = preload("res://assets/DrillingGame/Land_background_nosky.png")
const OFFSHORE_BG = preload("res://assets/DrillingGame/offshore-background.png")

# --- REFERENZEN ---
@onready var drill_assembly = $DrillAssembly
@onready var bit_sprite = $DrillAssembly/BitSprite
@onready var particles_drill = $DrillAssembly/BitSprite/GPUParticles2D
@onready var particles_oil = $OilGeyser
@onready var rig_sprite = $RigSprite # NEU: Referenz zum Bohrturm
@onready var sfx_drill = $SfxDrill
@onready var sfx_oil = $SfxOil
@onready var land_sprite = $Land  # Background sprite

# UI Referenzen
@onready var label = $CanvasLayer/StatusLabel
@onready var scope_control = $CanvasLayer/Scope
@onready var crosshair = $CanvasLayer/Scope/Crosshair

var game_running = true
var is_practice = false

func _ready():
		game_running = true
		if particles_oil: particles_oil.emitting = false
		
		if sfx_drill: sfx_drill.play()
		
		# Startposition initialisieren
		if drill_assembly:
				drill_assembly.position.x = get_viewport_rect().size.x / 2
				drill_assembly.position.y = start_y
		
		if is_instance_valid(GameManager):
				is_practice = GameManager.is_drilling_practice
				
				# FIX: Check if drilling in offshore region
				if not is_practice:
						var region_name = GameManager.active_region_name
						if region_name != "" and GameManager.regions.has(region_name):
								var region = GameManager.regions[region_name]
								if region != null:
										is_offshore = region.get("offshore_ratio", 0.0) > 0.5
		
		# Apply correct background
		_update_background()
		
		if is_practice:
				label.text = "TRAINING: Zurück zur Mitte lenken!"
				label.modulate = Color.CYAN
				total_depth = 1000.0 
		else:
				if is_offshore:
						label.text = "OFFSHORE-BOHRUNG LÄUFT..."
				else:
						label.text = "BOHRUNG LÄUFT..."
				label.modulate = Color.WHITE
				
		pick_new_drift_direction()

func _update_background():
		# Set the appropriate background based on offshore status
		if land_sprite:
				if is_offshore:
						land_sprite.texture = OFFSHORE_BG
				else:
						land_sprite.texture = LAND_BG

func pick_new_drift_direction():
		# Zufälliger Vektor, weg vom Zentrum bevorzugt
		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		current_drift_dir = random_dir
		drift_change_timer = 0.0

func _process(delta):
		if not game_running: 
				if sfx_drill and sfx_drill.volume_db > -80: sfx_drill.volume_db -= delta * 40
				return

		# --- 1. Fortschritt & Optik ---
		current_depth += drill_speed * delta
		
		# Fortschritt berechnen (0.0 bis 1.0)
		var progress = clamp(current_depth / total_depth, 0.0, 1.0)
		
		# Visuelle Bewegung nach unten
		if drill_assembly:
				drill_assembly.position.y = lerp(start_y, end_y, progress)

		# Shake Effekt
		var stress_factor = crosshair_pos.length() / max_radius
		var shake_amount = stress_factor * 15.0 
		var shake_vec = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
		
		if drill_assembly:
				var center_x = get_viewport_rect().size.x / 2
				drill_assembly.position.x = center_x + shake_vec.x

		# --- 2. Physik Simulation ---
		
		drift_change_timer += delta
		if drift_change_timer > 2.5: 
				pick_new_drift_direction()
		
		var drift_force = current_drift_dir * drift_strength * (1.0 + stress_factor)
		
		var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var player_force = input_vector * player_acceleration
		
		velocity += (drift_force + player_force) * delta
		velocity *= friction 
		
		if velocity.length() > max_speed:
				velocity = velocity.normalized() * max_speed
		
		crosshair_pos += velocity * delta
		
		# CLAMPING
		if crosshair_pos.length() > max_radius:
				crosshair_pos = crosshair_pos.normalized() * max_radius
				velocity *= -0.5 
		
		if scope_control and crosshair:
				var center_ui = scope_control.size / 2
				crosshair.position = center_ui + crosshair_pos - (crosshair.size / 2)
		
		# --- 3. Zonen & Fail Logik ---
		var dist = crosshair_pos.length()
		var recovery_speed = 1.5 
		
		if dist > 150: # Rot
				time_in_red += delta
				time_in_orange = max(0, time_in_orange - delta)
				time_in_yellow = max(0, time_in_yellow - delta)
				
				label.modulate = Color(1, 0.2, 0.2)
				label.text = "KRITISCH! %.1fs" % (LIMIT_RED - time_in_red)
				scope_control.modulate = Color(1, 0.5, 0.5) if int(Time.get_ticks_msec() / 100.0) % 2 == 0 else Color.WHITE
				
				if time_in_red > LIMIT_RED: 
						game_over("Bohrkopf geschmolzen (Rot)!")
						
		elif dist > 100: # Orange
				time_in_orange += delta
				time_in_red = max(0, time_in_red - delta * recovery_speed)
				time_in_yellow = max(0, time_in_yellow - delta)
				
				label.modulate = Color(1, 0.6, 0)
				label.text = "Druck steigt! %.1fs" % (LIMIT_ORANGE - time_in_orange)
				scope_control.modulate = Color(1, 0.9, 0.8)
				
				if time_in_orange > LIMIT_ORANGE:
						game_over("Gestänge gebrochen (Orange)!")
						
		elif dist > 50: # Gelb
				time_in_yellow += delta
				time_in_red = max(0, time_in_red - delta * recovery_speed)
				time_in_orange = max(0, time_in_orange - delta * recovery_speed)
				
				label.modulate = Color.YELLOW
				label.text = "Abweichung! %.1fs" % (LIMIT_YELLOW - time_in_yellow)
				scope_control.modulate = Color.WHITE
				
				if time_in_yellow > LIMIT_YELLOW:
						game_over("Bohrloch instabil (Gelb)!")
						
		else: # Grün
				time_in_red = max(0, time_in_red - delta * 3.0)
				time_in_orange = max(0, time_in_orange - delta * 3.0)
				time_in_yellow = max(0, time_in_yellow - delta * 3.0)
				
				label.modulate = Color.GREEN
				label.text = "Status: Stabil - Tiefe: %d m" % int(current_depth)
				scope_control.modulate = Color.WHITE

		if current_depth >= total_depth:
				finish_success()

func game_over(reason):
		game_running = false
		label.text = "FEHLSCHLAG:\n" + reason
		if particles_drill: particles_drill.emitting = false
		
		await get_tree().create_timer(2.0).timeout
		
		if is_instance_valid(GameManager):
				if is_practice:
						FeedbackOverlay.show_msg("Training beendet.")
						get_tree().change_scene_to_file("res://Computer.tscn")
				else:
						FeedbackOverlay.show_msg("Bohrung gescheitert!")
						get_tree().change_scene_to_file("res://RegionDetail.tscn")
		else:
				get_tree().quit()

func finish_success():
		game_running = false
		label.text = "ÖL VORKOMMEN ERREICHT!"
		label.modulate = Color.GREEN
		scope_control.modulate = Color.GREEN
		
		if sfx_drill: sfx_drill.stop()
		if sfx_oil: sfx_oil.play()
		if particles_oil: 
				particles_oil.emitting = true
				# FIX: Öl sprudelt oben am Turm raus (ca. 80px über dem Center des Sprites)
				if rig_sprite:
						particles_oil.global_position = rig_sprite.global_position + Vector2(0, -80)
				else:
						# Fallback, falls Sprite fehlt
						particles_oil.global_position = Vector2(get_viewport_rect().size.x / 2, 100)
		
		await get_tree().create_timer(3.0).timeout
		
		if is_instance_valid(GameManager):
				if is_practice:
						FeedbackOverlay.show_msg("Training erfolgreich!")
						get_tree().change_scene_to_file("res://Computer.tscn")
				else:
						var region_name = GameManager.active_region_name
						var claim_id = GameManager.active_claim_id
						# FIX: Add null checks to prevent crashes
						if region_name != "" and GameManager.regions.has(region_name):
								var region = GameManager.regions[region_name]
								if region != null and region.has("claims"):
										# Suche den richtigen Claim in der Liste
										for c in region["claims"]:
												if c != null and typeof(c) == TYPE_DICTIONARY and c.get("id", -1) == claim_id:
														c["drilled"] = true
														break
						
						FeedbackOverlay.show_msg("ÖLQUELLE ERSCHLOSSEN! HERVORRAGENDE ARBEIT.")
						get_tree().change_scene_to_file("res://RegionDetail.tscn")
		else:
				print("WIN")
