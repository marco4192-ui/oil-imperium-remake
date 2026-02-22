extends Control

# --- TEXTUREN LADEN ---
const TEX_H = preload("res://assets/pipes/pipe_horizontal.png")
const TEX_V = preload("res://assets/pipes/pipe_vertical.png")
const TEX_NE = preload("res://assets/pipes/pipe_ne.png")
const TEX_SE = preload("res://assets/pipes/pipe_se.png")
const TEX_SW = preload("res://assets/pipes/pipe_sw.png")
const TEX_NW = preload("res://assets/pipes/pipe_nw.png")
const TEX_START = preload("res://assets/pipes/pipe_start.png")
const TEX_END = preload("res://assets/pipes/pipe_end.png")

# --- THEMEN ---
const THEMES = [
        {
                "bg": preload("res://assets/textures/tex_sandhq.png"),
                "obstacles": [
                        preload("res://assets/textures/obst_sand1.png"),
                        preload("res://assets/textures/obst_sand2.png"),
                        preload("res://assets/textures/obst_sand3.png")
                ]
        },
        {
                "bg": preload("res://assets/textures/tex_stonehq.png"),
                "obstacles": [
                        preload("res://assets/textures/obst_stone1.png"),
                        preload("res://assets/textures/obst_stone2.png"),
                        preload("res://assets/textures/obst_stone3.png")
                ]
        },
        {
                "bg": preload("res://assets/textures/tex_terrahq.png"),
                "obstacles": [
                        preload("res://assets/textures/obst_terra1.png"),
                        preload("res://assets/textures/obst_terra2.png"),
                        preload("res://assets/textures/obst_terra3.png")
                ]
        }
]

# --- KONFIGURATION START & ENDE ---
# WICHTIG: Prüfe, ob das mit deinen Bildern übereinstimmt!
# Wenn dein Start-Pfeil nur nach RECHTS zeigt, setze nur den Index 1 auf true.
const START_OPENINGS = [false, true, true, false]  # [OBEN, RECHTS, UNTEN, LINKS]
const END_OPENINGS =   [true, false, false, true]  # [OBEN, RECHTS, UNTEN, LINKS]

# --- EINSTELLUNGEN ---
var grid_width = 8
var grid_height = 6
var cell_size = 120
var num_obstacles = 8 

# --- ROHR DEFINITIONEN ---
const PIECES = {
        "horizontal":   {"con": [false, true, false, true], "rot": 0, "texture": TEX_H},
        "vertical":     {"con": [true, false, true, false], "rot": 0, "texture": TEX_V},
        "ne":                   {"con": [true, true, false, false], "rot": 0, "texture": TEX_NE}, 
        "se":                   {"con": [false, true, true, false], "rot": 0, "texture": TEX_SE}, 
        "sw":                   {"con": [false, false, true, true], "rot": 0, "texture": TEX_SW}, 
        "nw":                   {"con": [true, false, false, true], "rot": 0, "texture": TEX_NW}  
}

# --- VARIABLEN ---
var grid_data = [] 
var current_tool = "horizontal" 
var start_pos = Vector2(0, 0)
var end_pos = Vector2(7, 5)
var game_active = true
var current_theme = {} 

# --- NODES ---
@onready var background_rect = $Background 
@onready var grid_container = $GameArea/GridContainer
@onready var sidebar = $HBoxContainer/Sidebar
@onready var time_label = $TimerDisplay/TimeText
@onready var timer = $Timer # <-- TIMER NODE MUSS EXISTIEREN!

func _ready():
        grid_container.columns = grid_width
        grid_container.add_theme_constant_override("h_separation", 0)
        grid_container.add_theme_constant_override("v_separation", 0)
        
        # Timer Signal verbinden (falls nicht im Editor passiert)
        if timer.timeout.is_connected(_on_timer_timeout) == false:
                timer.timeout.connect(_on_timer_timeout)
        
        setup_sidebar()
        start_game()

func _process(_delta):
        # Timer Update im neuen Label anzeigen
        if game_active and !timer.is_stopped():
                # Nur die Zahl anzeigen (z.B. "59")
                time_label.text = str(int(timer.time_left)) + "s"

                # Wir hängen die Zeit einfach an den Text an oder nutzen ein zweites Label
                # Hier einfachheitshalber quick & dirty in das Status Label, wenn kein Fehler da steht
                if !time_label.text.begins_with("ROHR") and !time_label.text.begins_with("ZIEL"):
                        time_label.text = "Zeit: " + str(int(timer.time_left)) + "s"

func setup_sidebar():
        var types = ["horizontal", "vertical", "ne", "se", "sw", "nw"]
        
        # Hole alle Kinder, aber filtere nur die Buttons heraus!
        var all_children = sidebar.get_children()
        var buttons = []
        
        for child in all_children:
                if child is Button:
                        buttons.append(child)
        
        # Jetzt iterieren wir nur über die gefundenen Buttons
        for i in range(min(buttons.size(), types.size())):
                var btn = buttons[i]
                var type = types[i]
                var info = PIECES[type]
                
                # Ab hier ist 'btn' garantiert ein Button, der expand_icon hat
                btn.custom_minimum_size = Vector2(120, 120)
                btn.pivot_offset = Vector2(30, 30)
                btn.expand_icon = true # Hier passierte der Fehler vorher
                btn.icon = info["texture"]
                btn.rotation = 0
                
                if btn.is_connected("pressed", _on_tool_selected):
                        btn.disconnect("pressed", _on_tool_selected)
                btn.pressed.connect(_on_tool_selected.bind(type, btn))

        # Standardauswahl auf den ersten Button setzen
        if buttons.size() > 0:
                _on_tool_selected("horizontal", buttons[0])

func _on_tool_selected(type, btn_ref):
        current_tool = type
        for b in sidebar.get_children():
                b.modulate = Color(0.5, 0.5, 0.5)
        btn_ref.modulate = Color(1, 1, 1)

func start_game():
        game_active = true
        timer.start(15)
        FeedbackOverlay.show_msg("Baue eine Leitung vom START zum ZIEL!", Color.WHITE)
        
        if THEMES.size() > 0:
                current_theme = THEMES.pick_random()
                if background_rect: background_rect.texture = current_theme["bg"]
        
        # --- LEVEL GENERIERUNG MIT RETRY-LOGIK ---
        var valid_level_found = false
        var attempts = 0
        
        # Wir versuchen bis zu 100 Mal, ein lösbares Level zu bauen
        while not valid_level_found and attempts < 100:
                attempts += 1
                
                # 1. Daten zurücksetzen (nur im Speicher)
                grid_data.clear()
                for i in range(grid_width * grid_height):
                        grid_data.append({"type": "empty", "button": null}) # Button kommt später
                
                # Start und Ende setzen (Daten)
                var start_idx = int(start_pos.y * grid_width + start_pos.x)
                var end_idx = int(end_pos.y * grid_width + end_pos.x)
                grid_data[start_idx]["type"] = "start"
                grid_data[end_idx]["type"] = "end"
                
                # 2. Hindernisse platzieren (Mit Sicherheitsabstand!)
                var obstacles_placed = 0
                var safety_tries = 0
                
                while obstacles_placed < num_obstacles and safety_tries < 1000:
                        safety_tries += 1
                        var rnd_idx = randi() % grid_data.size()
                        var y = floor(float(rnd_idx) / grid_width)
                        var x = rnd_idx % grid_width
                        var pos = Vector2(x, y)
                        
                        # Check 1: Nicht auf Start/Ende oder schon belegtes Feld
                        if grid_data[rnd_idx]["type"] != "empty":
                                continue
                                
                        # Check 2 (LÖSUNG PROBLEM 1): Sicherheitsabstand!
                        # distance_to 1.0 bedeutet: direktes Nachbarfeld (oben, unten, rechts, links)
                        # Wir wollen NICHT direkt neben Start oder Ende bauen.
                        if pos.distance_to(start_pos) <= 1.0 or pos.distance_to(end_pos) <= 1.0:
                                continue
                        
                        # Wenn alles okay ist: Hindernis setzen
                        grid_data[rnd_idx]["type"] = "obstacle"
                        obstacles_placed += 1
                
                # 3. Lösbarkeit prüfen (LÖSUNG PROBLEM 2)
                if is_level_solvable():
                        valid_level_found = true
                        print ("Gültiges Level gefunden nach " + str(attempts) + " Versuchen.")
        
        if not valid_level_found:
                print ("WARNUNG: Kein lösbares Level gefunden! Starte trotzdem (Notfall).")

        # --- LEVEL ANZEIGEN (Buttons erstellen) ---
        # Erst jetzt, wo wir sicher sind, löschen wir die alten Buttons und bauen neue
        for child in grid_container.get_children():
                child.queue_free()
                
        for i in range(grid_data.size()):
                var btn = Button.new()
                btn.custom_minimum_size = Vector2(cell_size, cell_size)
                btn.flat = true 
                btn.expand_icon = true
                btn.pivot_offset = Vector2(cell_size/2.0, cell_size/2.0)
                btn.modulate = Color(1, 1, 1, 1) 
                
                var type = grid_data[i]["type"]
                
                if type == "start":
                        btn.icon = TEX_START
                        btn.modulate = Color(1, 1, 1)
                elif type == "end":
                        btn.icon = TEX_END
                        btn.modulate = Color(1, 1, 1)
                elif type == "obstacle":
                        if current_theme.has("obstacles") and current_theme["obstacles"].size() > 0:
                                btn.icon = current_theme["obstacles"].pick_random()
                        else:
                                btn.text = "X"
                        btn.disabled = true
                        btn.mouse_filter = Control.MOUSE_FILTER_IGNORE 
                else:
                        # Leer
                        btn.modulate = Color(1, 1, 1, 0.1) 
                        btn.pressed.connect(_on_grid_clicked.bind(i))
                
                grid_data[i]["button"] = btn
                grid_container.add_child(btn)

# --- NEUE HILFSFUNKTION FÜR PFADFINDUNG ---
func is_level_solvable() -> bool:
        # Wir nutzen Godots extrem schnellen AStarGrid2D
        var astar = AStarGrid2D.new()
        astar.region = Rect2i(0, 0, grid_width, grid_height)
        astar.cell_size = Vector2i(1, 1)
        astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER # Rohre gehen nicht diagonal
        astar.update()
        
        # Hindernisse im AStar markieren
        for i in range(grid_data.size()):
                if grid_data[i]["type"] == "obstacle":
                        var x = i % grid_width
                        var y = floor(float(i) / grid_width)
                        astar.set_point_solid(Vector2i(x, y), true)
                        
        # Prüfen ob ein Pfad existiert
        var start_p = Vector2i(start_pos.x, start_pos.y)
        var end_p = Vector2i(end_pos.x, end_pos.y)
        
        var path = astar.get_id_path(start_p, end_p)
        
        # Wenn path.size() > 0 ist, gibt es einen Weg!
        return path.size() > 0

func _on_grid_clicked(index):
        if not game_active: return
        
        var cell = grid_data[index]
        
        # --- NEU: Verhindern, dass man Rohre überschreibt ---
        if cell["type"] != "empty":
                FeedbackOverlay.show_msg("Feld ist schon belegt!")
                return
        # ----------------------------------------------------
        
        cell["type"] = current_tool
        
        var info = PIECES[current_tool]
        var btn = cell["button"]
        
        btn.icon = info["texture"]
        btn.rotation = 0 
        btn.modulate = Color(1, 1, 1, 1)
        
        check_flow()

func check_flow():
        var current = start_pos
        var flow_dir = Vector2.ZERO
        var next_step_found = false
        
        # Oben (0, -1), Rechts (1, 0), Unten (0, 1), Links (-1, 0)
        var directions = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
        
        # --- 1. START-LOGIK ---
        for i in range(4):
                if START_OPENINGS[i]:
                        var check_dir = directions[i]
                        var neighbor_pos = start_pos + check_dir
                        
                        if is_in_grid(neighbor_pos):
                                var idx = int(neighbor_pos.y * grid_width + neighbor_pos.x)
                                var type = grid_data[idx]["type"]
                                
                                # FIX: Obstacles BLOCK the flow, they don't allow passage!
                                if type == "obstacle":
                                        continue  # Skip this direction, try another
                                elif type == "end":
                                        current = neighbor_pos; flow_dir = check_dir; next_step_found = true
                                        break
                                elif PIECES.has(type):
                                        var info = PIECES[type]
                                        var openings = info["con"]
                                        var opposite_side = (i + 2) % 4
                                        
                                        if openings[opposite_side]:
                                                current = neighbor_pos; flow_dir = check_dir; next_step_found = true
                                                break 
        
        if not next_step_found:
                # Noch keine Verbindung -> Einfach still abbrechen (Spieler baut noch)
                return 

        # --- 2. PFAD VERFOLGEN ---
        var steps = 0
        var max_steps = grid_width * grid_height
        
        while steps < max_steps:
                var idx = int(current.y * grid_width + current.x)
                var type_name = grid_data[idx]["type"]
                
                # --- HIER WIRD ES ERNST (Nur hier feuern wir Nachrichten) ---
                
                # 1. Hindernis
                if type_name == "obstacle": 
                        game_over("ROHR PLATZT! HINDERNIS GETROFFEN!")
                        return

                # 2. Leeres Feld
                if type_name == "empty": 
                        # Wasser fließt ins Leere -> Noch kein Game Over, Spieler baut noch.
                        return 

                # 3. Ziel
                if type_name == "end":
                        var entry_side = -1
                        if flow_dir == Vector2(0, 1): entry_side = 0
                        if flow_dir == Vector2(-1, 0): entry_side = 1
                        if flow_dir == Vector2(0, -1): entry_side = 2
                        if flow_dir == Vector2(1, 0): entry_side = 3
                        
                        if END_OPENINGS[entry_side]:
                                game_win()
                        else:
                                game_over("ZIEL VERFEHLT! FALSCHER EINGANG!")
                        return

                # 4. Rohr-Logik
                if not PIECES.has(type_name): return

                var info = PIECES[type_name]
                var openings = info["con"] 
                
                var entry_valid = false
                if flow_dir == Vector2(1, 0) and openings[3]: entry_valid = true 
                elif flow_dir == Vector2(-1, 0) and openings[1]: entry_valid = true 
                elif flow_dir == Vector2(0, 1) and openings[0]: entry_valid = true 
                elif flow_dir == Vector2(0, -1) and openings[2]: entry_valid = true 
                
                if not entry_valid: 
                        game_over("UNDICHT! ROHR PASST NICHT!")
                        return
                        
                var next_dir = Vector2.ZERO
                var possible_exits = []
                if openings[0]: possible_exits.append(Vector2(0, -1))
                if openings[1]: possible_exits.append(Vector2(1, 0))
                if openings[2]: possible_exits.append(Vector2(0, 1))
                if openings[3]: possible_exits.append(Vector2(-1, 0))
                
                for exit in possible_exits:
                        if exit != -flow_dir:
                                next_dir = exit; break
                
                if next_dir == Vector2.ZERO: 
                        game_over("SACKGASSE!")
                        return
                        
                current += next_dir
                flow_dir = next_dir
                steps += 1
                
                if !is_in_grid(current): 
                        game_over("ÖL LÄUFT AUS!")
                        return

func is_in_grid(pos):
        return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func _on_timer_timeout():
        game_over("ZEIT ABGELAUFEN!")

func game_over(reason):
        game_active = false
        timer.stop() # Timer anhalten
        FeedbackOverlay.show_msg(reason)
        time_label.modulate = Color(1, 0, 0)
        await get_tree().create_timer(3).timeout
        if has_node("/root/GameManager"): get_tree().change_scene_to_file("res://Office.tscn")
        else: start_game()

func game_win():
        game_active = false
        timer.stop() # Timer anhalten
        FeedbackOverlay.show_msg("GESCHAFFT! GELD VERDIENT!")
        time_label.modulate = Color(0, 1, 0)
        if has_node("/root/GameManager"):
                var val = GameManager.pending_sale_value
                GameManager.cash += val
                GameManager.oil_stored[GameManager.pending_sale_region] = 0
                await get_tree().create_timer(3).timeout
                get_tree().change_scene_to_file("res://Office.tscn")
        else:
                await get_tree().create_timer(3).timeout; start_game()
