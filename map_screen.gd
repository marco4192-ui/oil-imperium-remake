extends Control

@onready var label_cash = $MoneyLabel
@onready var btn_texas = $BtnTexas

func _ready():
        update_ui()

func update_ui():
        # Geld anzeigen (formatiert auf 2 Nachkommastellen)
        label_cash.text = "Geld: $" + ("%.2f" % GameManager.cash)
        
        # FIX: Use 'unlocked' instead of 'owned' for the new data structure
        if GameManager.regions.has("Texas") and GameManager.regions["Texas"].get("unlocked", false):
                btn_texas.text = "Texas (BOHREN!)" 
                btn_texas.disabled = false 
        else:
                btn_texas.text = "Texas ($400k)"
                btn_texas.disabled = false

func _on_btn_texas_pressed():
        # Entscheidung: Kaufen oder Bohren?
        # FIX: Use 'unlocked' instead of 'owned'
        if GameManager.regions.has("Texas") and GameManager.regions["Texas"].get("unlocked", false):
                # Fall A: Es gehört uns schon -> Ab zum Minispiel
                FeedbackOverlay.show_msg("Starte Bohrung...")
                # Navigate to region detail instead of drilling game directly
                GameManager.current_viewing_region = "Texas"
                get_tree().change_scene_to_file("res://RegionDetail.tscn")
        else:
                # Fall B: Es gehört uns noch nicht -> Kaufen
                var success = GameManager.buy_region("Texas")
                if success:
                        update_ui() 

func _on_btn_back_pressed():
        get_tree().change_scene_to_file("res://Office.tscn")
