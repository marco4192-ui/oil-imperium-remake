extends Control

@onready var label_cash = $MoneyLabel
@onready var btn_texas = $BtnTexas

func _ready():
	update_ui()

func update_ui():
	# Geld anzeigen (formatiert auf 2 Nachkommastellen)
	label_cash.text = "Geld: $" + ("%.2f" % GameManager.cash)
	
	# Wir prüfen, ob uns Texas gehört
	if GameManager.regions["Texas"]["owned"] == true:
		btn_texas.text = "Texas (BOHREN!)" 
		btn_texas.disabled = false 
	else:
		btn_texas.text = "Texas ($400k)"
		btn_texas.disabled = false

func _on_btn_texas_pressed():
	# Entscheidung: Kaufen oder Bohren?
	if GameManager.regions["Texas"]["owned"] == true:
		# Fall A: Es gehört uns schon -> Ab zum Minispiel
		FeedbackOverlay.show_msg("Starte Bohrung...")
		get_tree().change_scene_to_file("res://DrillingGame.tscn")
	else:
		# Fall B: Es gehört uns noch nicht -> Kaufen
		var success = GameManager.buy_region("Texas")
		if success:
			update_ui() 

func _on_btn_back_pressed():
	get_tree().change_scene_to_file("res://Office.tscn")
