extends Control

@onready var game_timer = $GameTimer
@onready var spawn_timer = $SpawnTimer
@onready var info_label = $Label

var leaks_fixed = 0
var leaks_spawned = 0
var game_over = false

func _ready():
	game_timer.start() # Spiel läuft 5 Sekunden
	info_label.text = "REPARIERE DIE LECKS!"

# Dieser Timer spawnt alle 0.5 Sekunden ein neues Leck
func _on_spawn_timer_timeout():
	if game_over: return
	spawn_leak()

# Wenn die Zeit abgelaufen ist
func _on_game_timer_timeout():
	finish_game()

func spawn_leak():
	leaks_spawned += 1
	
	# Erstelle einen neuen Button per Code
	var btn = Button.new()
	add_child(btn)
	
	# Aussehen und Position
	btn.text = "X"
	btn.modulate = Color(1, 0, 0) # Rot
	btn.size = Vector2(50, 50)
	
	# Zufällige Position auf dem Bildschirm
	var screen_size = get_viewport_rect().size
	var random_x = randf_range(50, screen_size.x - 50)
	var random_y = randf_range(100, screen_size.y - 100)
	btn.position = Vector2(random_x, random_y)
	
	# Signal verbinden: Wenn geklickt wird, rufe _on_leak_clicked auf
	btn.pressed.connect(_on_leak_clicked.bind(btn))

func _on_leak_clicked(btn_ref):
	if game_over: return
	
	leaks_fixed += 1
	btn_ref.queue_free() # Button löschen

func finish_game():
	game_over = true
	spawn_timer.stop()
	
	# Auswertung
	# Wir berechnen, wie viel Prozent wir geflickt haben
	var success_rate = 1.0 # 100%
	if leaks_spawned > 0:
		success_rate = float(leaks_fixed) / float(leaks_spawned)
	
	var original_value = GameManager.pending_sale_value
	var final_payout = 0
	
	# Text anzeigen
	var result_text = ""
	
	if success_rate >= 0.8: # Über 80% geschafft -> Alles gut
		result_text = "GUTE ARBEIT! Pipeline stabil."
		final_payout = original_value
	elif success_rate >= 0.4: # Über 40% -> Mittelmaß
		result_text = "NAJA... Einiges Öl verloren."
		final_payout = original_value * 0.7 # 30% Verlust
	else: # Totalversagen
		result_text = "KATASTROPHE! Pipeline geplatzt."
		final_payout = original_value * 0.1 # 90% Verlust
		
	info_label.text = result_text + "\nEinnahmen: $%d" % final_payout
	
	# Geld gutschreiben
	GameManager.cash += int(final_payout)
	
	# Öl im Lager auf 0 setzen (es ist ja rausgeflossen/verkauft)
	var region = GameManager.pending_sale_region
	GameManager.oil_stored[region] = 0
	
	# Button erstellen zum Zurückkehren
	var back_btn = Button.new()
	back_btn.text = "Zurück ins Büro"
	back_btn.size = Vector2(200, 50)
	back_btn.position = get_viewport_rect().size / 2 - Vector2(100, 0)
	add_child(back_btn)
	back_btn.pressed.connect(_on_back_btn_pressed)

func _on_back_btn_pressed():
	
	get_tree().change_scene_to_file("res://Computer.tscn")
