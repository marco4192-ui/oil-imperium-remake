extends Control

# Referenzen
@onready var background = $Background
@onready var btn_computer = $BtnComputer
@onready var btn_map = $BtnMap
@onready var btn_calendar = $BtnCalendar
@onready var lbl_cal_day = $BtnCalendar/LabelDay
@onready var lbl_cal_month = $BtnCalendar/LabelMonth
@onready var btn_newspaper = $BtnNewspaper
@onready var btn_briefcase = $BtnBriefcase
@onready var btn_drawer = $BtnDrawer
@onready var btn_phone = $BtnPhone
@onready var btn_endmonth = $BtnEndMonth
@onready var btn_upgrade = $BtnUpgrade 

# Save-Menu UI
var save_popup: PopupMenu

# --- NEUES SABOTAGE UI (CANVAS LAYER) ---
var sabotage_layer: CanvasLayer
var sabotage_panel: Panel
var opt_target: OptionButton
var opt_type: OptionButton
var opt_region: OptionButton
var lbl_cost: Label
var btn_execute: Button

# Zwischenspeicher für Logik
var selected_competitor_data = {} 

# Tooltip UI Variablen
var tooltip_panel: PanelContainer
var tooltip_label: Label

func _ready():
	load_office_style()
	create_save_popup()
	create_sabotage_ui() 
	setup_tooltips()
	
	if not GameManager.data_updated.is_connected(update_ui):
		GameManager.data_updated.connect(update_ui)
	
	if not GameManager.month_ended.is_connected(_on_month_ended_report):
		GameManager.month_ended.connect(_on_month_ended_report)
	
	if not GameManager.data_updated.is_connected(check_newspaper_status):
		GameManager.data_updated.connect(check_newspaper_status)
		
	if not GameManager.tech_activated.is_connected(check_upgrade_status):
		GameManager.tech_activated.connect(check_upgrade_status)
		
	# Initial Update
	update_ui()

func load_office_style():
	var office_id = GameManager.current_office_id
	
	# Sicherheitscheck: Daten vorhanden?
	if not GameManager.office_data.has(office_id): return
		
	var data = GameManager.office_data[office_id]
	
	# 1. Hintergrund setzen
	if data.has("bg_path") and data["bg_path"] != "":
		background.texture = load(data["bg_path"])
	
	# 2. Buttons positionieren (Vector2 Daten aus GameData nutzen)
	_apply_transform(btn_computer, data, "computer")
	_apply_transform(btn_map, data, "map")
	_apply_transform(btn_calendar, data, "calendar")
	_apply_transform(btn_newspaper, data, "newspaper")
	_apply_transform(btn_briefcase, data, "briefcase")
	_apply_transform(btn_drawer, data, "drawer")
	_apply_transform(btn_phone, data, "phone")
	_apply_transform(btn_endmonth, data, "endmonth")

# Hilfsfunktion, um Position und Größe sicher zu setzen
func _apply_transform(node: Control, data: Dictionary, key_prefix: String):
	if node == null: return
	
	var pos_key = key_prefix + "_pos"
	var size_key = key_prefix + "_size"
	
	if data.has(pos_key):
		node.position = data[pos_key]
		
	if data.has(size_key):
		node.size = data[size_key]

func update_ui():
	var d = GameManager.date["day"]
	var m = GameManager.date["month"] - 1 # Array index 0-11
	
	if lbl_cal_day:
		lbl_cal_day.text = str(d)
	
	var month_names = ["JAN", "FEB", "MÄR", "APR", "MAI", "JUN", "JUL", "AUG", "SEP", "OKT", "NOV", "DEZ"]
	if lbl_cal_month:
		lbl_cal_month.text = month_names[m]
	
	check_newspaper_status()
	check_upgrade_status()

func _on_btn_calendar_pressed():
	GameManager.next_day()

func _on_btn_end_month_pressed() -> void:
	var current_day = GameManager.date["day"]
	var days_left = GameManager.DAYS_PER_MONTH - current_day + 1
	
	FeedbackOverlay.show_msg("Simuliere Monatsende (" + str(days_left) + " Tage)...")
	
	await get_tree().create_timer(0.5).timeout
	GameManager.advance_time(days_left)

func _on_month_ended_report(report):
	var profit = report.get("revenue", 0) - report.get("expenses", 0)
	var sign_str = "+" if profit >= 0 else ""
	var col = Color.GREEN if profit >= 0 else Color.RED
	
	var msg = "--- MONATSABSCHLUSS ---\n\n"
	msg += "ERGEBNIS: " + sign_str + "$" + _fmt(profit) + "\n"
	msg += "Siehe Statistik für Details."
	FeedbackOverlay.show_msg(msg, col)

func _fmt(value):
	var string = str(int(value))
	var mod = string.length() % 3
	var res = ""
	for i in range(0, string.length()):
		if i != 0 && i % 3 == mod:
			res += "."
		res += string[i]
	return res

func _on_btn_computer_pressed():
	get_tree().change_scene_to_file("res://Computer.tscn")

func _on_btn_map_pressed():
	if GameManager.current_viewing_region == "":
		GameManager.current_viewing_region = "Texas"
	get_tree().change_scene_to_file("res://RegionDetail.tscn")

# --- SPEICHERN ---
func create_save_popup():
	save_popup = PopupMenu.new()
	save_popup.name = "SaveMenu"
	add_child(save_popup)
	
	save_popup.add_item("Neuer Spielstand (Slot 1)", 1)
	save_popup.add_item("Neuer Spielstand (Slot 2)", 2)
	save_popup.add_item("Neuer Spielstand (Slot 3)", 3)
	
	if not save_popup.id_pressed.is_connected(_on_save_slot_selected):
		save_popup.id_pressed.connect(_on_save_slot_selected)

func _on_save_slot_selected(id):
	GameManager.save_game(id)
	FeedbackOverlay.show_msg("Spiel in Slot " + str(id) + " gespeichert!", Color.GREEN)

func _on_save_item_pressed(id):
	GameManager.save_game(str(id))

# --- BUTTON EVENT HANDLERS ---

# 1. SCHUBLADE -> SABOTAGE
func _on_btn_drawer_pressed(): 
	open_sabotage_menu()

# 2. KOFFER -> SPEICHERN
func _on_btn_briefcase_pressed():
	# Speichermenü an der Mausposition öffnen
	save_popup.position = Vector2(get_viewport().get_mouse_position())
	save_popup.popup()

# 3. TELEFON -> NOTRUFE (Placeholder)
func _on_btn_phone_pressed(): 
	FeedbackOverlay.show_msg("Leitung tot. Keine aktiven Notrufe.", Color.WHITE)

# --- ZEITUNG ---
func check_newspaper_status():
	if btn_newspaper:
		if GameManager.unread_news.size() > 0:
			btn_newspaper.modulate = Color(1, 0.5, 0.5) 
		else:
			btn_newspaper.modulate = Color(1, 1, 1)

func _on_btn_newspaper_pressed():
	if GameManager.unread_news.is_empty():
		FeedbackOverlay.show_msg("Keine neuen Nachrichten.")
	else:
		var news = GameManager.unread_news.pop_front()
		var txt = "[ " + news.get("title", "INFO") + " ]\n\n" + news.get("text", "")
		FeedbackOverlay.show_msg(txt, Color.WHITE)
		GameManager.news_archive.append(news)
		check_newspaper_status()

# --- UPGRADES ---
func check_upgrade_status():
	if btn_upgrade:
		if GameManager.check_tech_availability():
			btn_upgrade.visible = true
			btn_upgrade.modulate = Color(0, 1, 0) # Leuchtet grün
		else:
			btn_upgrade.visible = false

func _on_btn_upgrade_pressed():
	if GameManager.upgrade_era():
		FeedbackOverlay.show_msg("Büro & Technik aufgerüstet!", Color.GREEN)
		load_office_style()
	else:
		FeedbackOverlay.show_msg("Nicht genug Geld oder Jahr noch nicht erreicht.")

# ==============================================================================
# --- SABOTAGE SYSTEM (WIZARD, NEUTRAL START, BIG FONT) ---
# ==============================================================================

func create_sabotage_ui():
	# Aufräumen falls nötig
	if sabotage_layer: sabotage_layer.queue_free()
	
	# CanvasLayer sorgt dafür, dass es ÜBERALLEM liegt (Z-Index 110)
	sabotage_layer = CanvasLayer.new()
	sabotage_layer.layer = 110 
	sabotage_layer.visible = false
	add_child(sabotage_layer)
	
	# Dimmer (Hintergrund abdunkeln)
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.85) # Dunkler Hintergrund
	sabotage_layer.add_child(dimmer)
	
	# Haupt-Panel (Kompakter & Weiter oben)
	sabotage_panel = Panel.new()
	sabotage_panel.custom_minimum_size = Vector2(900, 650)
	sabotage_panel.set_anchors_preset(Control.PRESET_CENTER)
	
	# Manuelles Zentrieren, aber nach OBEN verschoben
	sabotage_panel.anchor_left = 0.5; sabotage_panel.anchor_top = 0.5
	sabotage_panel.anchor_right = 0.5; sabotage_panel.anchor_bottom = 0.5
	
	# Wir schieben es 50 Pixel nach oben (-375 statt -325)
	sabotage_panel.offset_left = -450; sabotage_panel.offset_top = -375 
	sabotage_panel.offset_right = 450; sabotage_panel.offset_bottom = 275
	sabotage_layer.add_child(sabotage_panel)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	sabotage_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	margin.add_child(vbox)
	
	# Header
	var title = Label.new()
	title.text = "SCHATTEN-DOSSIER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3)) # Rot
	vbox.add_child(title)
	
	# --- SCHRITT 1: GEGNER ---
	var lbl1 = Label.new()
	lbl1.text = "1. ZIELPERSON:"
	lbl1.add_theme_font_size_override("font_size", 24)
	vbox.add_child(lbl1)
	
	opt_target = OptionButton.new()
	opt_target.custom_minimum_size.y = 50 
	# Große Schrift für Button UND Popup
	opt_target.add_theme_font_size_override("font_size", 35) 
	opt_target.get_popup().add_theme_font_size_override("font_size", 35)
	opt_target.item_selected.connect(_on_target_selected)
	vbox.add_child(opt_target)
	
	# --- SCHRITT 2: METHODE ---
	var lbl2 = Label.new()
	lbl2.text = "2. METHODE:"
	lbl2.add_theme_font_size_override("font_size", 24)
	vbox.add_child(lbl2)
	
	opt_type = OptionButton.new()
	opt_type.custom_minimum_size.y = 50
	opt_type.add_theme_font_size_override("font_size", 35)
	opt_type.get_popup().add_theme_font_size_override("font_size", 35)
	opt_type.disabled = true 
	opt_type.item_selected.connect(_on_type_selected)
	vbox.add_child(opt_type)
	
	# --- SCHRITT 3: REGION ---
	var lbl3 = Label.new()
	lbl3.text = "3. ZIELGEBIET:"
	lbl3.add_theme_font_size_override("font_size", 24)
	vbox.add_child(lbl3)
	
	opt_region = OptionButton.new()
	opt_region.custom_minimum_size.y = 50
	opt_region.add_theme_font_size_override("font_size", 35)
	opt_region.get_popup().add_theme_font_size_override("font_size", 35)
	opt_region.disabled = true 
	opt_region.item_selected.connect(_on_region_selected)
	vbox.add_child(opt_region)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# --- INFO & KOSTEN ---
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	lbl_cost = Label.new()
	lbl_cost.text = "Gesamtkosten: ---"
	lbl_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_cost.add_theme_font_size_override("font_size", 36)
	lbl_cost.add_theme_color_override("font_color", Color(1, 0.8, 0.2)) # Gold
	vbox.add_child(lbl_cost)
	
	# --- BUTTONS ---
	var hbox_btns = HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_END
	hbox_btns.add_theme_constant_override("separation", 30)
	vbox.add_child(hbox_btns)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "ABBRECHEN"
	btn_cancel.add_theme_font_size_override("font_size", 24)
	btn_cancel.custom_minimum_size = Vector2(200, 60)
	btn_cancel.pressed.connect(func(): sabotage_layer.visible = false)
	hbox_btns.add_child(btn_cancel)
	
	btn_execute = Button.new()
	btn_execute.text = "AUSFÜHREN"
	btn_execute.add_theme_font_size_override("font_size", 24)
	btn_execute.custom_minimum_size = Vector2(250, 60)
	btn_execute.disabled = true
	btn_execute.modulate = Color(1, 0.4, 0.4)
	btn_execute.pressed.connect(_on_execute_sabotage_pressed)
	hbox_btns.add_child(btn_execute)

func open_sabotage_menu():
	sabotage_layer.visible = true
	selected_competitor_data = {}
	
	opt_target.clear()
	opt_type.clear()
	opt_region.clear()
	
	opt_target.disabled = false
	opt_type.disabled = true
	opt_region.disabled = true
	btn_execute.disabled = true
	lbl_cost.text = "Kosten: ---"
	
	# START: Platzhalter als erstes Item (Neutral)
	opt_target.add_item("- BITTE WÄHLEN -", 999)
	
	if GameManager.ai_controller and GameManager.ai_controller.competitors:
		var idx = 0
		for comp in GameManager.ai_controller.competitors:
			opt_target.add_item(comp["name"], idx)
			idx += 1
			
	opt_target.select(0)
	
	# Dummy-Items für gesperrte Felder
	opt_type.add_item("- WARTET -", 999); opt_type.select(0)
	opt_region.add_item("- WARTET -", 999); opt_region.select(0)

func _on_target_selected(index):
	var id = opt_target.get_item_id(index)
	
	# Wenn Platzhalter (999) gewählt -> RESET ALLES DARUNTER
	if id == 999:
		selected_competitor_data = {}
		opt_type.clear(); opt_type.add_item("- WARTET -", 999); opt_type.select(0); opt_type.disabled = true
		opt_region.clear(); opt_region.add_item("- WARTET -", 999); opt_region.select(0); opt_region.disabled = true
		lbl_cost.text = "Kosten: ---"
		btn_execute.disabled = true
		return
	
	selected_competitor_data = GameManager.ai_controller.competitors[id]
	
	# Methode aktivieren
	opt_type.disabled = false
	opt_type.clear()
	
	# Neutraler Start für Methode
	opt_type.add_item("- METHODE WÄHLEN -", 999)
	
	var sab_ops = GameManager.GameData.SABOTAGE_OPTIONS
	var op_idx = 0
	for key in sab_ops:
		var op = sab_ops[key]
		opt_type.add_item(op["name"], op_idx)
		opt_type.set_item_metadata(op_idx + 1, key) 
		op_idx += 1
	
	opt_type.select(0)
		
	# Region Reset
	opt_region.clear(); opt_region.add_item("- WARTET -", 999); opt_region.select(0); opt_region.disabled = true
	lbl_cost.text = "Kosten: ---"
	btn_execute.disabled = true

func _on_type_selected(index):
	var id = opt_type.get_item_id(index)
	
	if id == 999:
		opt_region.clear(); opt_region.add_item("- WARTET -", 999); opt_region.select(0); opt_region.disabled = true
		lbl_cost.text = "Kosten: ---"
		btn_execute.disabled = true
		return
	
	opt_region.disabled = false
	opt_region.clear()
	opt_region.add_item("- ZIELGEBIET WÄHLEN -", 999)
	
	var target_name = selected_competitor_data["name"]
	var found_any = false
	
	for r_name in GameManager.regions:
		if GameManager.regions[r_name] == null: continue
		var region_data = GameManager.regions[r_name]
		
		# NUR SICHTBARE REGIONEN ANZEIGEN
		if not region_data.get("visible", false): continue
		
		var is_active = false
		if region_data.has("claims"):
			for c in region_data["claims"]:
				if c == null or typeof(c) != TYPE_DICTIONARY: continue
				if c.get("is_empty", false): continue
				if c.get("ai_owner") == target_name:
					is_active = true
					break
		if is_active:
			opt_region.add_item(r_name)
			opt_region.set_item_metadata(opt_region.item_count - 1, r_name)
			found_any = true
			
	if not found_any:
		opt_region.clear(); opt_region.add_item("KEINE ZIELE GEFUNDEN", 999); opt_region.disabled = true
	
	opt_region.select(0)
	lbl_cost.text = "Kosten: ---"
	btn_execute.disabled = true

func _on_region_selected(index):
	var id = opt_region.get_item_id(index)
	if id == 999: 
		lbl_cost.text = "Kosten: ---"
		btn_execute.disabled = true
		return
	
	var type_key = opt_type.get_selected_metadata()
	var base_cost = GameManager.GameData.SABOTAGE_OPTIONS[type_key]["cost"]
	var real_cost = int(base_cost * GameManager.inflation_rate)
	lbl_cost.text = "KOSTEN: $" + _fmt(real_cost)
	btn_execute.disabled = false

func _on_execute_sabotage_pressed():
	var type_key = opt_type.get_selected_metadata()
	var region_name = opt_region.get_selected_metadata()
	var result = GameManager.player_order_sabotage(type_key, region_name)
	sabotage_layer.visible = false
	if result.success: FeedbackOverlay.show_msg("AUFTRAG ERTEILT: Operation läuft...", Color.GREEN)
	else: FeedbackOverlay.show_msg(result.message, Color.RED)

# --- TOOLTIPS ---
func setup_tooltips():
	tooltip_panel = PanelContainer.new()
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 100
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_color = Color.WHITE
	style.border_width_bottom=1; style.border_width_top=1; style.border_width_left=1; style.border_width_right=1
	tooltip_panel.add_theme_stylebox_override("panel", style)
	tooltip_label = Label.new()
	tooltip_panel.add_child(tooltip_label)
	add_child(tooltip_panel)
	
	_connect_tooltip(btn_computer, "Öl-Terminal")
	_connect_tooltip(btn_map, "Weltkarte / Claims")
	_connect_tooltip(btn_calendar, "Nächster Tag")
	_connect_tooltip(btn_endmonth, "Monat beenden")
	_connect_tooltip(btn_phone, "Notfall-Leitung")
	_connect_tooltip(btn_briefcase, "Speichern")
	_connect_tooltip(btn_drawer, "Sabotage Dossier")
	_connect_tooltip(btn_newspaper, "Archiv")
	_connect_tooltip(btn_upgrade, "Upgrade")

func _connect_tooltip(node, text):
	node.mouse_entered.connect(func(): _show_tooltip(text, node))
	node.mouse_exited.connect(func(): tooltip_panel.visible = false)

func _show_tooltip(text, node):
	tooltip_label.text = text
	tooltip_panel.visible = true
	var target_pos = node.global_position
	var target_size = node.size
	tooltip_panel.position = Vector2(target_pos.x + target_size.x/2 - tooltip_panel.size.x/2, target_pos.y - 50)
