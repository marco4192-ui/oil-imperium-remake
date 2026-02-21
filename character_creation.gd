extends Control

# --- UI REFERENZEN ---
@onready var logo_display = $MainContainer/SelctorsBox/LeftColumn/LogoHorizontal/LogoVertrical/LogoDisplay
@onready var company_label = $MainContainer/SelctorsBox/LeftColumn/LogoControls/CompanyNameLabel

@onready var office_display = $MainContainer/SelctorsBox/RightColumn/OfficeDisplay
@onready var office_label = $MainContainer/SelctorsBox/RightColumn/OfficeControls/OfficeNameLabel

@onready var hq_label = $MainContainer/SelctorsBox/RightColumn2/HQControls/HQNameLabel
@onready var hq_display = $MainContainer/SelctorsBox/RightColumn2/HQDisplay 
@onready var name_input = $MainContainer/InputBox/NameInput

@onready var btn_load = $BtnLoad 

# Load Menu
var load_popup: PopupMenu

# --- DATEN ---
var logos = [] # Wird aus GameData geladen
var current_logo_idx = 0
var current_office_idx = 0
var current_hq_idx = 0

func _ready():
	# Daten aus GameData holen
	if GameManager and GameManager.GameData:
		logos = GameManager.GameData.COMPANIES
	
	create_load_popup()
	update_ui()

func create_load_popup():
	load_popup = PopupMenu.new()
	load_popup.name = "LoadMenu"
	add_child(load_popup)
	
	# Existierende Saves prüfen
	var saves = GameManager.get_existing_saves()
	if saves.is_empty():
		load_popup.add_item("Keine Spielstände", -1)
		load_popup.set_item_disabled(0, true)
	else:
		for s in saves:
			load_popup.add_item("Slot " + s, int(s))
			
	load_popup.id_pressed.connect(_on_load_item_pressed)

func _on_btn_load_pressed():
	# Popup an Position des Buttons öffnen
	var rect = btn_load.get_global_rect()
	load_popup.position = Vector2(rect.position.x, rect.end.y)
	load_popup.show()

func _on_load_item_pressed(id):
	if id == -1: return
	GameManager.load_game(str(id))
	get_tree().change_scene_to_file("res://Office.tscn")

func update_ui():
	# 1. Logo & Company
	if logos.size() > 0:
		var company = logos[current_logo_idx]
		company_label.text = company["name"]
		# Fallback für Bild
		if ResourceLoader.exists(company["logo"]):
			logo_display.texture = load(company["logo"])
	
	# 2. Office
	if GameManager.office_data.has(current_office_idx):
		var off = GameManager.office_data[current_office_idx]
		office_label.text = off["name"]
		if ResourceLoader.exists(off["bg_path"]):
			office_display.texture = load(off["bg_path"])
		
	# 3. HQ
	if GameManager.available_hqs.size() > 0:
		var hq = GameManager.available_hqs[current_hq_idx]
		hq_label.text = hq["name"]
		
		# FIX: Bild korrekt laden
		var path = hq.get("skyline_path", "")
		if path != "" and ResourceLoader.exists(path):
			hq_display.texture = load(path)
		else:
			hq_display.texture = null # Leeren, falls kein Bild da ist

# LOGO STEUERUNG
func _on_btn_logo_left_pressed():
	if logos.is_empty(): return
	current_logo_idx = (current_logo_idx - 1 + logos.size()) % logos.size()
	update_ui()

func _on_btn_logo_right_pressed():
	if logos.is_empty(): return
	current_logo_idx = (current_logo_idx + 1) % logos.size()
	update_ui()

# BÜRO STEUERUNG
func _on_btn_office_left_pressed():
	var office_count = GameManager.office_data.size()
	current_office_idx = (current_office_idx - 1 + office_count) % office_count
	update_ui()

func _on_btn_office_right_pressed():
	var office_count = GameManager.office_data.size()
	current_office_idx = (current_office_idx + 1) % office_count
	update_ui()

# HQ STEUERUNG
func _on_btn_hq_left_pressed():
	var hq_count = GameManager.available_hqs.size()
	if hq_count == 0: return
	current_hq_idx = (current_hq_idx - 1 + hq_count) % hq_count
	update_ui()

func _on_btn_hq_right_pressed():
	var hq_count = GameManager.available_hqs.size()
	if hq_count == 0: return
	current_hq_idx = (current_hq_idx + 1) % hq_count
	update_ui()

# SPIEL STARTEN
func _on_start_button_pressed():
	var entered_name = name_input.text.strip_edges()
	
	if entered_name == "":
		name_input.placeholder_text = "Bitte Namen eingeben!"
		return
		
	# Daten sammeln
	var company_name = "Unbekannt"
	var logo_path = ""
	
	if logos.size() > 0:
		var selected_company = logos[current_logo_idx]
		company_name = selected_company["name"]
		logo_path = selected_company["logo"]
	
	# Aufruf mit ALLEN 5 Parametern
	GameManager.start_new_game(
		entered_name, 
		company_name, 
		logo_path, 
		current_office_idx, 
		current_hq_idx
	)
