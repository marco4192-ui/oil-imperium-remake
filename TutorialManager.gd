extends Node

# --- TUTORIAL SYSTEM ---
# Optional help system for new players. Can be enabled/disabled at any time.

signal tutorial_step_shown(step_id: String)
signal tutorial_completed

var tutorial_enabled: bool = false
var current_step: String = ""
var completed_steps: Array = []

# --- TUTORIAL POPUP ---
var popup_panel: PanelContainer = null
var popup_title: Label = null
var popup_text: Label = null
var popup_button: Button = null
var popup_visible: bool = false

# --- TUTORIAL STEPS ---
const TUTORIAL_STEPS = {
	"welcome": {
		"title": "Willkommen bei Oil Imperium!",
		"text": "Sie sind nun Besitzer einer Oelfirma! Ihr Ziel ist es, ein Oelimperium aufzubauen.\n\nDieses Tutorial fuehrt Sie durch die Grundlagen. Sie koennen es jederzeit im Buero deaktivieren.",
		"trigger": "game_start",
		"next": "office_intro"
	},
	"office_intro": {
		"title": "Ihr Buero",
		"text": "Dies ist Ihr Hauptquartier. Von hier aus steuern Sie alles:\n\n- COMPUTER: Finanzberichte, Tanks, Vertraege\n- KARTE: Weltkarte und Bohrgebiete\n- KALENDER: Zeit voranschreiten lassen\n- AKTENKOFFER: Spiel speichern\n- TELEFON: Notrufe empfangen",
		"trigger": "office_enter",
		"next": "first_region"
	},
	"first_region": {
		"title": "Texas - Ihr erstes Oelfeld",
		"text": "Texas ist Ihr Startgebiet. Klicken Sie auf die KARTE, um zu den Bohrgebieten zu gelangen.\n\nDort koennen Sie:\n- Lizenzen fuer Regionen kaufen\n- Landparzellen erwerben\n- Bohrungen starten",
		"trigger": "map_enter",
		"next": "buy_license"
	},
	"buy_license": {
		"title": "Lizenz kaufen",
		"text": "Bevor Sie bohren koennen, benoetigen Sie eine Foerderlizenz.\n\nKlicken Sie auf eine Region und kaufen Sie die Lizenz. Die Kosten variieren je nach Region.\n\nTexas ist am guenstigsten und ein guter Startpunkt.",
		"trigger": "region_locked",
		"next": "buy_claim"
	},
	"buy_claim": {
		"title": "Land erwerben",
		"text": "Nach dem Lizenzkauf koennen Sie Parzellen (Claims) erwerben.\n\n- Graue Felder sind verfuegbar\n- Klicken Sie auf ein Feld fuer Details\n- Der Preis haengt von Lage und Groesse ab",
		"trigger": "license_bought",
		"next": "expertise"
	},
	"expertise": {
		"title": "Expertise durchfuehren",
		"text": "Sie koennen eine Expertise (geologische Untersuchung) durchfuehren lassen.\n\nWICHTIG: Expertisen sind nie 100% genau! Die Qualitaet der Schaetzung wird angezeigt.\n\nManchmal zeigen sie Oel an, wo keines ist - und umgekehrt!",
		"trigger": "claim_selected",
		"next": "drilling"
	},
	"drilling": {
		"title": "Bohrung starten",
		"text": "Wenn Sie bereit sind, starten Sie eine Bohrung!\n\n- EIGENE BOHRUNG: Guenstiger, aber Sie muessen das Minispiel spielen\n- EXPERTEN-BOHRUNG: Teurer, aber sofortiges Ergebnis\n\nDas Bohr-Minispiel erfordert Geschick: Halten Sie den Bohrer in der Mitte!",
		"trigger": "claim_owned",
		"next": "oil_production"
	},
	"oil_production": {
		"title": "Oelproduktion",
		"text": "Glueckwunsch! Wenn Sie Oel gefunden haben, beginnt die Produktion.\n\n- Das Oel wird automatisch gefoerdert und gelagert\n- Sie brauchen Tanks, um das Oel zu speichern\n- Verkaufen Sie das Oel ueber den COMPUTER > Oel-Verkauf",
		"trigger": "drilling_complete",
		"next": "contracts"
	},
	"contracts": {
		"title": "Vertraege abschliessen",
		"text": "Ueber den COMPUTER koennen Sie Liefervertraege abschliessen.\n\n- SUPPLY VERTRAEGE: Regelmaessige Lieferungen gegen feste Bezahlung\n- FUTURES: Wette auf zukuenftige Preise\n\nVertraege bringen stabiles Einkommen, aber Strafen bei Nichterfuellung!",
		"trigger": "first_oil_sale",
		"next": "economy"
	},
	"economy": {
		"title": "Wirtschaft & Markt",
		"text": "Der Oelpreis schwankt! Beachten Sie:\n\n- Historische Ereignisse beeinflussen den Preis (Oelkrise 1973!)\n- Inflation erhoeht Ihre Kosten ueber die Jahre\n- Forschung kann Ihre Effizienz verbessern\n\nPassen Sie Ihre Strategie an die Marktbedingungen an!",
		"trigger": "month_end",
		"next": "sabotage"
	},
	"sabotage": {
		"title": "Wettbewerb & Sabotage",
		"text": "Sie sind nicht allein! KI-Gegner konkurrieren mit Ihnen.\n\nUeber die SCHUBLADE (im Buero) koennen Sie Sabotageaktionen planen.\n\nACHTUNG: Sabotage ist teuer und riskant. Wenn Sie erwischt werden, zahlen Sie hohe Strafen!",
		"trigger": "competitor_action",
		"next": "tutorial_end"
	},
	"tutorial_end": {
		"title": "Tutorial abgeschlossen!",
		"text": "Sie kennen nun die Grundlagen!\n\nTipps fuer den Erfolg:\n- Diversifizieren Sie Ihre Foerdergebiete\n- Behalten Sie Ihre Finanzen im Auge\n- Investieren Sie in Forschung\n- Passen Sie sich an Marktveraenderungen an\n\nViel Erfolg beim Aufbau Ihres Oelimperiums!",
		"trigger": "tutorial_complete",
		"next": ""
	}
}

# --- REFERENCE TO GAME MANAGER ---
var game_manager = null

func _ready():
	# Try to find GameManager
	await get_tree().create_timer(0.5).timeout
	if has_node("/root/GameManager"):
		game_manager = get_node("/root/GameManager")

func enable_tutorial():
	tutorial_enabled = true
	completed_steps.clear()
	save_tutorial_state()
	print("Tutorial aktiviert")

func disable_tutorial():
	tutorial_enabled = false
	print("Tutorial deaktiviert")

func toggle_tutorial():
	if tutorial_enabled:
		disable_tutorial()
	else:
		enable_tutorial()

func check_trigger(trigger_name: String, _context: Dictionary = {}):
	if not tutorial_enabled:
		return
	
	# Find the step for this trigger
	for step_id in TUTORIAL_STEPS:
		if TUTORIAL_STEPS[step_id]["trigger"] == trigger_name:
			# Skip if already completed
			if step_id in completed_steps:
				continue
			
			# Check if this step's previous is completed (or it's the first)
			if should_show_step(step_id):
				show_step(step_id)
				break

func should_show_step(step_id: String) -> bool:
	# First step is always showable
	if step_id == "welcome":
		return true
	
	# Check if previous step was completed
	var _step = TUTORIAL_STEPS[step_id]
	for prev_id in TUTORIAL_STEPS:
		if TUTORIAL_STEPS[prev_id]["next"] == step_id:
			return prev_id in completed_steps
	
	return false

func show_step(step_id: String):
	if not TUTORIAL_STEPS.has(step_id):
		return
	
	current_step = step_id
	var step = TUTORIAL_STEPS[step_id]
	
	# Emit signal for UI to handle
	tutorial_step_shown.emit(step_id)
	
	# Create and show popup dialog
	_create_popup(step["title"], step["text"])
	
	print("[TUTORIAL] " + step["title"])

func _create_popup(title: String, text: String):
	# Remove existing popup if any
	_close_popup()
	
	# Get viewport for adding popup
	var viewport = get_tree().root
	if not viewport:
		return
	
	# Create CanvasLayer to ensure popup is ALWAYS on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "TutorialCanvasLayer"
	canvas_layer.layer = 1000  # Very high layer to be on top of everything
	viewport.add_child(canvas_layer)
	
	# Create background overlay (semi-transparent) - blocks all clicks
	var overlay = ColorRect.new()
	overlay.name = "TutorialOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block all mouse input behind it
	canvas_layer.add_child(overlay)
	
	# Create main panel - centered
	popup_panel = PanelContainer.new()
	popup_panel.name = "TutorialPopup"
	popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	popup_panel.custom_minimum_size = Vector2(600, 350)
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure it catches clicks
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.2)
	style.border_color = Color(0.0, 0.8, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	popup_panel.add_theme_stylebox_override("panel", style)
	
	# Create content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	popup_panel.add_child(vbox)
	
	# Title label
	popup_title = Label.new()
	popup_title.text = title
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_title.add_theme_font_size_override("font_size", 28)
	popup_title.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0))
	popup_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	popup_title.add_theme_constant_override("outline_size", 3)
	vbox.add_child(popup_title)
	
	# Separator
	var separator = HSeparator.new()
	separator.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	vbox.add_child(separator)
	
	# Text label
	popup_text = Label.new()
	popup_text.text = text
	popup_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_text.add_theme_font_size_override("font_size", 18)
	popup_text.add_theme_color_override("font_color", Color.WHITE)
	popup_text.custom_minimum_size.y = 200
	popup_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(popup_text)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)
	
	# Close button - IMPORTANT: ensure it's clickable
	popup_button = Button.new()
	popup_button.text = "VERSTANDEN"
	popup_button.custom_minimum_size = Vector2(200, 50)
	popup_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	popup_button.add_theme_font_size_override("font_size", 20)
	popup_button.add_theme_color_override("font_color", Color.WHITE)
	popup_button.add_theme_color_override("font_hover_color", Color(0.0, 1.0, 1.0))
	popup_button.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure clickability
	
	# Style the button - NORMAL state
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.3, 0.4)
	btn_style.border_color = Color(0.0, 0.8, 1.0)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(5)
	popup_button.add_theme_stylebox_override("normal", btn_style)
	
	# Style the button - HOVER state
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.3, 0.5, 0.6)
	btn_hover.border_color = Color(0.0, 1.0, 1.0)
	btn_hover.set_border_width_all(3)
	btn_hover.set_corner_radius_all(5)
	popup_button.add_theme_stylebox_override("hover", btn_hover)
	
	# Style the button - PRESSED state
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.1, 0.2, 0.3)
	btn_pressed.border_color = Color(0.0, 0.6, 0.8)
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(5)
	popup_button.add_theme_stylebox_override("pressed", btn_pressed)
	
	popup_button.pressed.connect(_on_popup_button_pressed)
	vbox.add_child(popup_button)
	
	# Add panel to overlay (which is in CanvasLayer)
	overlay.add_child(popup_panel)
	
	popup_visible = true
	
	# Animation - fade in (animate the overlay, not the CanvasLayer)
	overlay.modulate.a = 0.0
	var tween = get_tree().create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	
	# Ensure button has focus for keyboard interaction
	await get_tree().create_timer(0.1).timeout
	if popup_button and is_instance_valid(popup_button):
		popup_button.grab_focus()

func _close_popup():
	var viewport = get_tree().root
	if not viewport:
		return
	
	# Find and free the CanvasLayer (which contains the overlay)
	var canvas_layer = viewport.get_node_or_null("TutorialCanvasLayer")
	if canvas_layer:
		canvas_layer.queue_free()
	
	popup_panel = null
	popup_button = null
	popup_visible = false

func _on_popup_button_pressed():
	_close_popup()
	complete_current_step()

func complete_current_step():
	if current_step == "" or current_step in completed_steps:
		return
	
	completed_steps.append(current_step)
	save_tutorial_state()
	
	# Check if this was the last step
	if current_step == "tutorial_end":
		tutorial_completed.emit()
		tutorial_enabled = false
		print("Tutorial vollstaendig abgeschlossen!")
	
	current_step = ""

func skip_to_next():
	complete_current_step()
	
	# Show next step if available
	if current_step != "" and TUTORIAL_STEPS.has(current_step):
		var next_id = TUTORIAL_STEPS[current_step].get("next", "")
		if next_id != "" and TUTORIAL_STEPS.has(next_id):
			show_step(next_id)

# --- PERSISTENCE ---
func save_tutorial_state():
	if game_manager:
		# Could save to game_manager's save system
		pass

func load_tutorial_state():
	if game_manager:
		# Could load from game_manager's save system
		pass

# --- HELPER FOR UI ---
func get_current_step_data() -> Dictionary:
	if current_step == "" or not TUTORIAL_STEPS.has(current_step):
		return {}
	return TUTORIAL_STEPS[current_step]

func get_progress() -> Dictionary:
	return {
		"enabled": tutorial_enabled,
		"completed_count": completed_steps.size(),
		"total_steps": TUTORIAL_STEPS.size(),
		"current_step": current_step
	}

func reset_tutorial():
	completed_steps.clear()
	current_step = ""
	tutorial_enabled = true
	print("Tutorial zurueckgesetzt")
