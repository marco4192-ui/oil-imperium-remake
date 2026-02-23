extends Panel

@onready var logo_rect = $HBoxContainer/Logo
@onready var name_label = $HBoxContainer/NameLabel
@onready var company_label = $HBoxContainer/CompanyLabel
@onready var money_label = $HBoxContainer/MoneyLabel

# Era display variables
var era_label: Label = null

func _ready():
        # Statische Daten laden
        name_label.text = GameManager.player_name
        company_label.text = GameManager.company_name
        if GameManager.company_logo_path != "":
                logo_rect.texture = load(GameManager.company_logo_path)
        
        # Create era label dynamically
        era_label = Label.new()
        era_label.name = "EraLabel"
        era_label.add_theme_font_size_override("font_size", 16)
        var hbox = get_node_or_null("HBoxContainer")
        if hbox:
                hbox.add_child(era_label)
        
        # Signal verbinden
        GameManager.data_updated.connect(update_display)
        
        # Einmal sofort ausführen
        update_display()

func update_display():
        # Geld anzeigen (formatiert mit Tausendertrennpunkten)
        money_label.text = "$ " + GameManager.format_cash(GameManager.cash, true)
        
        # Era anzeigen
        if era_label:
                var era_names = {
                        0: "[ 1970s - Pionier-Ära ]",
                        1: "[ 1980s - Computer-Revolution ]",
                        2: "[ 1990s+ - Moderne Ära ]"
                }
                var era_colors = {
                        0: Color(0.2, 1.0, 0.2),   # Green for 70s
                        1: Color(0.4, 0.8, 1.0),   # Blue for 80s
                        2: Color(1, 1, 1)          # White for 90s+
                }
                era_label.text = era_names.get(GameManager.current_era, "[ Unbekannte Ära ]")
                era_label.modulate = era_colors.get(GameManager.current_era, Color.WHITE)
