extends CanvasLayer

@onready var panel = $MsgPanel
@onready var label = $MsgPanel/MsgLabel

# Referenz zur Szene für fliegende Zahlen laden
const FloatingTextScene = preload("res://FloatingText.tscn")

func _ready():
        # Startzustand: Panel ist komplett unsichtbar
        panel.modulate = Color(1, 1, 1, 0) 
        panel.visible = true

func show_msg(text: String, color: Color = Color.WHITE):
        # 1. Text und Einstellungen setzen
        label.text = text
        
        # FIX: Limit text width to prevent overflow
        label.autowrap_mode = TextServer.AUTOWRAP_WORD
        label.custom_minimum_size.x = 0
        label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        
        # Set panel size to constrain label width (80% of screen width)
        var max_width = get_viewport().get_visible_rect().size.x * 0.8
        panel.custom_minimum_size.x = max_width
        
        if label.label_settings == null:
                label.label_settings = LabelSettings.new()
        
        # Einstellungen erzwingen
        label.label_settings.font_size = 32
        label.label_settings.font_color = color       # Hier kommt dein Rot/Grün/Weiß rein
        label.label_settings.outline_color = Color.BLACK
        label.label_settings.outline_size = 6
        
        # WICHTIG: Das Label selbst muss "neutral" sein
        label.modulate = Color(1, 1, 1, 1) 
        
        # 2. Animation
        # Alte Animationen stoppen
        if panel.get_tree():
                var tween = create_tween()
                
                # Wir starten bei unsichtbarem Weiß
                panel.modulate = Color(1, 1, 1, 0)
                
                # Wir blenden ein zu SICHTBAREM WEISS (Color(1, 1, 1, 1))
                tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.5)
                tween.tween_interval(4.0) # Kurz warten (doubled from 2.0)
                tween.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.5)

# NEUE FUNKTION FÜR FLIEGENDE ZAHLEN
func spawn_floating_money(amount: int, spawn_position: Vector2 = Vector2.ZERO):
        if amount == 0: return
        
        var float_txt = FloatingTextScene.instantiate()
        add_child(float_txt)
        
        # Wert setzen (Farbe wird im Skript automatisch bestimmt)
        float_txt.set_amount(amount)
        
        # Position bestimmen
        if spawn_position == Vector2.ZERO:
                # Wenn keine Position angegeben, mittig spawnen (leicht versetzt)
                var vp_size = get_viewport().get_visible_rect().size
                float_txt.position = (vp_size / 2) + Vector2(0, -100)
        else:
                float_txt.position = spawn_position
