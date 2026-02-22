extends Panel

@onready var logo_rect = $HBoxContainer/Logo
@onready var name_label = $HBoxContainer/NameLabel
@onready var company_label = $HBoxContainer/CompanyLabel
@onready var money_label = $HBoxContainer/MoneyLabel

func _ready():
	# Statische Daten laden
	name_label.text = GameManager.player_name
	company_label.text = GameManager.company_name
	if GameManager.company_logo_path != "":
		logo_rect.texture = load(GameManager.company_logo_path)
	
	# Signal verbinden
	GameManager.data_updated.connect(update_display)
	
	# Einmal sofort ausführen
	update_display()

func update_display():
	# Geld anzeigen (formatiert auf 2 Nachkommastellen)
	money_label.text = "$ " + ("%.2f" % GameManager.cash)
