extends Control

# --- IMPORTS ---
const GameData = preload("res://GameData.gd")
# WICHTIG: Hier laden wir deinen Shader
const RETRO_SHADER = preload("res://regiondetail.gdshader")

# --- UI REFERENZEN ---
@onready var title = $Title
@onready var info_panel = $InfoPanel
@onready var info_label = $InfoPanel/InfoLabel
@onready var action_btn = $InfoPanel/BtnAction
@onready var btn_secondary = $InfoPanel/BtnSecondary
@onready var reserves_bar = $InfoPanel/ReservesBar
@onready var background_map = $BackgroundMap
@onready var money_label = get_node_or_null("MoneyLabel")

# --- DRILL MENU REFERENZEN ---
@onready var drill_menu = $DrillMenu
@onready var lbl_cost_list = $DrillMenu/HBoxContainer/VBoxContainer/CostListSelf
@onready var lbl_total_self = $DrillMenu/HBoxContainer/VBoxContainer/TotalSelf
@onready var lbl_time_self = $DrillMenu/HBoxContainer/VBoxContainer/TimeSelf 
@onready var lbl_total_expert = $DrillMenu/HBoxContainer/VBoxContainer2/TotalExpert
@onready var lbl_time_expert = $DrillMenu/HBoxContainer/VBoxContainer2/TimeExpert 

# --- LOGIK ---
var selected_claim_id = -1
var region_data : Dictionary = {}
var region_locked = false 
var cost_self = 0; var cost_expert = 0
var duration_self = 0; var duration_expert = 0

# --- DYNAMISCHER CONTAINER ---
var map_pins_container: Control = null
var claim_buttons = []

# --- SHADER REFERENZEN ---
var crt_layer: CanvasLayer = null

func _ready():
	# 1. Shader initialisieren
	_init_retro_shader()

	# UI aufräumen
	if is_instance_valid(drill_menu): drill_menu.visible = false
	if is_instance_valid(reserves_bar): reserves_bar.visible = false
	if is_instance_valid(btn_secondary): btn_secondary.visible = false
	if has_node("Grid"): get_node("Grid").visible = false
		
	# Container erstellen
	if map_pins_container == null:
		map_pins_container = Control.new()
		map_pins_container.name = "MapPins"
		map_pins_container.size = Vector2(1280, 720) 
		map_pins_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(map_pins_container)
		
		# Z-Order: Über Map, unter UI
		if is_instance_valid(background_map):
			move_child(map_pins_container, background_map.get_index() + 1)
		else:
			move_child(map_pins_container, 1)

	if GameManager.current_viewing_region == "" or not GameManager.regions.has(GameManager.current_viewing_region):
		GameManager.current_viewing_region = "Texas" 
		
	update_money_display()
	
	if not GameManager.data_updated.is_connected(update_money_display):
		GameManager.data_updated.connect(update_money_display)
	
	# Starten
	call_deferred("update_view")

# --- NEU: SHADER SETUP ---
func _init_retro_shader():
	# Wir erstellen einen CanvasLayer, damit der Shader ÜBER allem liegt (auch über Popups)
	crt_layer = CanvasLayer.new()
	crt_layer.layer = 100 # Hoher Layer-Index
	add_child(crt_layer)
	
	# BackBufferCopy ist wichtig für Screen-Reading Shader in Godot, 
	# damit das Bild korrekt kopiert wird, bevor der Shader es verändert.
	var bbc = BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	bbc.rect = Rect2(0, 0, 1920, 1080) # Volle Größe
	crt_layer.add_child(bbc)
	
	# Das ColorRect, auf dem der Shader läuft
	var crt_rect = ColorRect.new()
	crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# WICHTIG: Mouse Filter auf IGNORE, sonst kann man keine Buttons mehr klicken!
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	crt_layer.add_child(crt_rect)
	
	# Material erstellen und Shader zuweisen
	if RETRO_SHADER:
		var mat = ShaderMaterial.new()
		mat.shader = RETRO_SHADER
		# Hier kannst du Parameter tweaken, falls nötig (Werte aus deinem Shader-File)
		mat.set_shader_parameter("scanline_count", 180.0)
		mat.set_shader_parameter("scanline_opacity", 0.2)
		mat.set_shader_parameter("vignette_intensity", 0.3)
		
		crt_rect.material = mat
	else:
		print("WARNUNG: regiondetail.gdshader nicht gefunden!")

func update_money_display():
	if is_instance_valid(money_label):
		money_label.text = "$ " + ("%.2f" % GameManager.cash)

func update_view():
	var region_name = GameManager.current_viewing_region
	var raw_data = GameManager.regions.get(region_name)
	
	if raw_data == null or typeof(raw_data) != TYPE_DICTIONARY:
		title.text = "FEHLER: DATEN NICHT GEFUNDEN"
		return
	
	region_data = raw_data
	
	if region_data.has("map_bg") and region_data["map_bg"] != "":
		background_map.texture = load(region_data["map_bg"])
	
	var grid_pos = region_data.get("grid_pos", Vector2(50, 150))
	map_pins_container.position = grid_pos
		
	region_locked = not region_data.get("unlocked", false)
	
	var text = "ÖLFELD: " + region_name.to_upper()
	action_btn.disabled = true
	action_btn.text = "-"
	info_label.text = "Bitte Parzelle wählen..."
	
	if region_locked:
		text += " [GESPERRT]"
		info_label.text = "KEINE FÖRDERLIZENZ VORHANDEN."
		var fee = region_data.get("license_fee", 0)
		var cost_k = int((fee * GameManager.inflation_rate) / 1000)
		action_btn.text = "LIZENZ KAUFEN ($" + str(cost_k) + "k)"
		action_btn.disabled = false
		selected_claim_id = -99 
	else:
		text += " [AKTIV]"
		selected_claim_id = -1
			
	title.text = text
	render_claims_grid(region_name)

func render_claims_grid(region_name):
	for child in map_pins_container.get_children():
		child.queue_free()
	claim_buttons.clear()
		
	# Layout holen
	var layout_strings = []
	if GameData.REGION_LAYOUTS.has(region_name):
		layout_strings = GameData.REGION_LAYOUTS[region_name]
	else:
		layout_strings = region_data.get("grid_array", [])
		
	if layout_strings.is_empty(): return

	var claims_list = region_data.get("claims", [])
	if typeof(claims_list) != TYPE_ARRAY: return
	
	var claim_index = 0
	var cell_w = 160
	var cell_h = 120
	var gap = 10
	
	var max_cols = 0
	for row_str in layout_strings:
		if str(row_str).length() > max_cols: max_cols = str(row_str).length()
	
	var total_grid_width = max_cols * (cell_w + gap)
	
	for row_idx in range(layout_strings.size()):
		var row_string = str(layout_strings[row_idx])
		var current_row_width = row_string.length() * (cell_w + gap)
		var x_start_offset = (total_grid_width - current_row_width) / 2.0
		
		for col_idx in range(row_string.length()):
			var char_code = row_string[col_idx]
			
			if claim_index >= claims_list.size():
				break
				
			var claim_data = claims_list[claim_index]
			claim_index += 1 
			
			if char_code == "_" or char_code == "0": 
				continue
				
			if claim_data != null and typeof(claim_data) == TYPE_DICTIONARY:
				if claim_data.get("is_empty", false): continue
					
				var btn = create_claim_button(claim_data)
				map_pins_container.add_child(btn)
				claim_buttons.append(btn)
				
				var pos_x = x_start_offset + col_idx * (cell_w + gap)
				var pos_y = row_idx * (cell_h + gap)
				btn.position = Vector2(pos_x, pos_y)

func create_claim_button(claim: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(160, 120)
	btn.size = Vector2(160, 120)
	# Button selbst soll klickbar sein
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var c_id = int(claim.get("id", -1))
	btn.set_meta("claim_id", c_id)
	
	btn.tooltip_text = "Parzelle #" + str(c_id)
	
	var is_owned = claim.get("owned", false)
	var is_drilled = claim.get("drilled", false)
	var has_oil = claim.get("has_oil", false)
	var ai_owner = claim.get("ai_owner", null)
	var surveyed = claim.get("surveyed", false)
	var is_offshore = claim.get("is_offshore", false)
	
	# SPIELER BESITZ
	if is_owned:
		if GameManager.company_logo_path != "":
			var tex = load(GameManager.company_logo_path)
			if tex:
				btn.icon = tex
				btn.expand_icon = true
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				# WICHTIG: Icon soll Klick nicht blockieren
		
		if is_drilled:
			btn.modulate = Color(0.3, 0.3, 0.3, 0.9)
			if has_oil: btn.modulate = Color(0.8, 0.7, 0.2, 0.9)
		else: 
			btn.modulate = Color(0.0, 1.0, 0.0, 0.7)
			
	# KI BESITZ
	elif ai_owner != null:
		# KI Logo laden (wenn vorhanden)
		var logo_found = false
		
		if GameData.COMPANIES:
			for comp in GameData.COMPANIES:
				if comp["name"] == ai_owner:
					var ki_logo = load(comp["logo"])
					if ki_logo:
						btn.icon = ki_logo
						btn.expand_icon = true
						btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
						btn.modulate = Color(1.0, 0.5, 0.5, 0.9) # Leicht rötlich
						logo_found = true
					break
		
		if not logo_found:
			btn.text = str(ai_owner)
			btn.modulate = Color(1.0, 0.2, 0.2, 0.8)
			
	# NIEMANDES LAND
	else:
		if surveyed: 
			btn.text = "?"
			btn.add_theme_font_size_override("font_size", 40)
			btn.add_theme_color_override("font_color", Color(1, 1, 0, 0.8))
		if is_offshore: 
			btn.modulate = Color(0.024, 0.62, 1.0, 0.706)
		else: 
			btn.modulate = Color(0.6, 0.6, 0.6, 0.706)
	
	btn.pressed.connect(_on_claim_clicked.bind(c_id))
	return btn

func get_claim_by_id(id):
	var claims = region_data.get("claims", [])
	if typeof(claims) != TYPE_ARRAY: return null
	
	for c in claims:
		if typeof(c) == TYPE_DICTIONARY:
			if c.get("is_empty", false): continue
			if int(c.get("id")) == int(id):
				return c
	return null

func _on_claim_clicked(id):
	if id == -1: return
	
	var raw_claim = get_claim_by_id(id)
	if raw_claim == null or typeof(raw_claim) != TYPE_DICTIONARY: return
	var claim: Dictionary = raw_claim
	
	selected_claim_id = id
	update_highlight() 
	update_info_panel(claim)

func update_highlight():
	for btn in claim_buttons:
		if btn.has_meta("claim_id") and int(btn.get_meta("claim_id")) == int(selected_claim_id):
			btn.self_modulate = Color(1.5, 1.5, 1.5, 1) 
		else:
			btn.self_modulate = Color(1, 1, 1, 1) 

func update_info_panel(claim: Dictionary):
	var info = ">> PARZELLE #" + str(claim.get("id")) + "\n"
	action_btn.disabled = false
	if is_instance_valid(btn_secondary): btn_secondary.visible = false 
	if is_instance_valid(reserves_bar): reserves_bar.visible = false
	
	var price = claim.get("price", 0)
	var ai_owner = claim.get("ai_owner", null)
	var owned = claim.get("owned", false)
	var drilled = claim.get("drilled", false)
	
	if region_locked:
		info += "STATUS: GESPERRT\nPREIS: $" + str(price)
		action_btn.text = "LIZENZ KAUFEN"
	else:
		if ai_owner != null:
			info += "BESITZER: " + str(ai_owner).to_upper() + "\n"
			action_btn.text = "-"
			action_btn.disabled = true
		elif not owned:
			info += "STATUS: VERFÜGBAR\nPREIS: $" + str(price) + "\n"
			action_btn.text = "KAUFEN"
			if not claim.get("surveyed", false):
				if is_instance_valid(btn_secondary):
					btn_secondary.visible = true
					var s_cost = GameManager.get_survey_cost(GameManager.current_viewing_region, claim.get("is_offshore", false))
					btn_secondary.text = "EXPERTISE ($" + str(s_cost) + ")"
				info += "DATEN: UNBEKANNT"
			else:
				var yield_val = int(claim.get("survey_yield", 0))
				var res_val = int(claim.get("survey_reserves", 0) / 1000)
				info += "\n[ BERICHT ]\nPROGNOSE: " + str(yield_val) + " BBL/TAG\nVOLUMEN:  ~" + str(res_val) + "k BBL"
		elif not drilled:
			info += "STATUS: IM BESITZ\nBEREIT ZUR ERSCHLIESSUNG.\n"
			if claim.get("surveyed", false): 
				info += "(Prognose: " + str(int(claim.get("survey_yield", 0))) + " BBL/Tag)"
			action_btn.text = "BOHRUNG STARTEN"
			
			var s_val = GameManager.get_claim_sell_value(GameManager.current_viewing_region, claim.get("id"))
			if is_instance_valid(btn_secondary): 
				btn_secondary.visible = true
				btn_secondary.text = "VERKAUFEN ($" + str(s_val) + ")"
		else:
			info += "STATUS: AKTIV / GEBOHRT\n"
			if claim.get("has_oil", false):
				info += "OUTPUT: " + "%.1f" % claim.get("yield", 0) + " BBL/TAG\n"
				if claim.get("surveyed", false):
					if is_instance_valid(reserves_bar):
						reserves_bar.visible = true
						reserves_bar.max_value = claim.get("reserves_max", 100)
						reserves_bar.value = claim.get("reserves_remaining", 0)
					info += "RESERVEN: " + str(int(claim.get("reserves_remaining", 0))) + " BBL"
			else: 
				info += "ERGEBNIS: TROCKEN\n"
			action_btn.text = "-"
			action_btn.disabled = true
			
			var s_val = GameManager.get_claim_sell_value(GameManager.current_viewing_region, claim.get("id"))
			if is_instance_valid(btn_secondary): 
				btn_secondary.visible = true
				btn_secondary.text = "VERKAUFEN ($" + str(s_val) + ")"
				
	info_label.text = info

func _on_btn_action_pressed():
	if region_locked: 
		if GameManager.try_buy_license(GameManager.current_viewing_region): 
			FeedbackOverlay.show_msg("Lizenz erworben!")
			update_view()
		else: 
			FeedbackOverlay.show_msg("Zu wenig Geld!")
		return

	if selected_claim_id < 0: return
	
	var raw_claim = get_claim_by_id(selected_claim_id)
	if raw_claim == null or typeof(raw_claim) != TYPE_DICTIONARY: return
	var claim: Dictionary = raw_claim
	
	if not claim.get("owned", false):
		var price = claim.get("price", 0)
		if GameManager.cash >= price:
			GameManager.cash -= price
			claim["owned"] = true
			GameManager.notify_update()
			render_claims_grid(GameManager.current_viewing_region)
			_on_claim_clicked(selected_claim_id) 
			FeedbackOverlay.show_msg("Land erfolgreich erworben!")
		else: 
			FeedbackOverlay.show_msg("Nicht genug Kapital!")
	elif not claim.get("drilled", false): 
		start_drilling_process()

func _on_btn_secondary_pressed():
	if selected_claim_id < 0: return
	var raw_claim = get_claim_by_id(selected_claim_id)
	if raw_claim == null or typeof(raw_claim) != TYPE_DICTIONARY: return
	var claim: Dictionary = raw_claim
	
	if not claim.get("owned", false):
		if not claim.get("surveyed", false):
			var cost = GameManager.get_survey_cost(GameManager.current_viewing_region, claim.get("is_offshore", false))
			if GameManager.cash >= cost:
				GameManager.get_survey_result(GameManager.current_viewing_region, claim)
				FeedbackOverlay.show_msg("Bericht erhalten.")
				_on_claim_clicked(selected_claim_id)
			else: 
				FeedbackOverlay.show_msg("Zu wenig Geld!")
	else:
		GameManager.sell_claim(GameManager.current_viewing_region, selected_claim_id)
		FeedbackOverlay.show_msg("Landstück verkauft.")
		selected_claim_id = -1
		info_label.text = "Bitte Parzelle wählen..."
		action_btn.disabled = true
		if is_instance_valid(btn_secondary): btn_secondary.visible = false
		render_claims_grid(GameManager.current_viewing_region)

func start_drilling_process():
	if not is_instance_valid(drill_menu): return
	drill_menu.visible = true
	var region_name = GameManager.current_viewing_region
	var calc_self = GameManager.calculate_drilling_costs(region_name, true)
	var calc_expert = GameManager.calculate_drilling_costs(region_name, false)
	
	if calc_self == null or typeof(calc_self) != TYPE_DICTIONARY: calc_self = {"total":0, "duration":0, "logistics":0, "rental":0, "crew":0}
	if calc_expert == null or typeof(calc_expert) != TYPE_DICTIONARY: calc_expert = {"total":0, "duration":0}
		
	cost_self = int(calc_self.get("total", 0))
	duration_self = int(calc_self.get("duration", 0))
	cost_expert = int(calc_expert.get("total", 0))
	duration_expert = int(calc_expert.get("duration", 0))
	
	lbl_total_self.text = "SUMME: $" + str(cost_self)
	if is_instance_valid(lbl_time_self): lbl_time_self.text = "Dauer: " + str(duration_self) + " Tage"
	lbl_total_expert.text = "SUMME: $" + str(cost_expert)
	if is_instance_valid(lbl_time_expert): lbl_time_expert.text = "Dauer: " + str(duration_expert) + " Tage"
	
	var c_log = calc_self.get("logistics", 0)
	var c_rent = calc_self.get("rental", 0)
	var c_crew = calc_self.get("crew", 0)
	lbl_cost_list.text = "Logistik: $" + str(c_log) + "\nMiete: $" + str(c_rent) + "\nCrew: $" + str(c_crew)

func _on_btn_cancel_pressed(): 
	if is_instance_valid(drill_menu): drill_menu.visible = false

func _on_btn_back_pressed(): 
	get_tree().change_scene_to_file("res://Computer.tscn")

func _on_btn_self_pressed():
	if GameManager.cash >= cost_self:
		GameManager.cash -= cost_self
		GameManager.notify_update()
		GameManager.active_claim_id = selected_claim_id
		GameManager.active_region_name = GameManager.current_viewing_region
		GameManager.advance_time(duration_self)
		GameManager.is_drilling_practice = false 
		get_tree().change_scene_to_file("res://DrillingMiniGame.tscn")
	else: 
		FeedbackOverlay.show_msg("Nicht genug Geld!")

func _on_btn_expert_pressed():
	if GameManager.cash >= cost_expert:
		GameManager.cash -= cost_expert
		GameManager.notify_update()
		GameManager.advance_time(duration_expert)
		finish_drilling_instant()
	else: 
		FeedbackOverlay.show_msg("Nicht genug Geld!")

func finish_drilling_instant():
	var raw_claim = get_claim_by_id(selected_claim_id)
	if raw_claim == null or typeof(raw_claim) != TYPE_DICTIONARY: return
	var claim: Dictionary = raw_claim
	claim["drilled"] = true
	if claim.get("has_oil", false):
		FeedbackOverlay.show_msg("Erfolg! Ölquelle erschlossen.")
	else:
		FeedbackOverlay.show_msg("Bohrloch trocken.")
	if is_instance_valid(drill_menu): drill_menu.visible = false
	render_claims_grid(GameManager.current_viewing_region)
	_on_claim_clicked(selected_claim_id)
