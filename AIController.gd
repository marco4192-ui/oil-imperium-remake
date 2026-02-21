extends Node

const GameData = preload("res://GameData.gd")

var game_manager = null 

# --- KI KONFIGURATION ---
var competitors = [
	{
		"name": "KI_1", 
		"color": Color.RED, 
		"cash": 25000000.0, # Mehr Startkapital (war 10M)
		"aggressiveness": 0.9, # Aggressiver (war 0.8)
		"sabotage_tendency": 0.4, 
		"focus_regions": ["Texas", "Mexiko", "Venezuela"],
		"inventory": [] 
	},
	{
		"name": "KI_2", 
		"color": Color.YELLOW, 
		"cash": 30000000.0, # Mehr Startkapital
		"aggressiveness": 0.7, # (war 0.5)
		"sabotage_tendency": 0.2, 
		"focus_regions": ["Nordsee", "Nigeria", "Indonesien"],
		"inventory": []
	},
	{
		"name": "KI_3", 
		"color": Color.GREEN, 
		"cash": 20000000.0, 
		"aggressiveness": 0.8, # (war 0.6)
		"sabotage_tendency": 0.3,
		"focus_regions": ["Saudi-Arabien", "Libyen", "Alaska"],
		"inventory": []
	}
]

func _ready():
	# Warten bis GameManager bereit ist (kleiner Delay)
	await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(game_manager) and is_instance_valid(game_manager.GameData):
		var company_names = []
		# Namen aus GameData holen
		for c in game_manager.GameData.COMPANIES:
			company_names.append(c["name"])
		
		company_names.shuffle()
		
		# Namen zuweisen
		for i in range(competitors.size()):
			if i < company_names.size():
				competitors[i]["name"] = company_names[i]
				print("KI Spieler initialisiert: " + competitors[i]["name"] + " (Cash: $" + str(competitors[i]["cash"]) + ")")

func process_ai_turn():
	if game_manager == null: return
	
	print("\n--- KI ZUG BEGINNT ---")
	
	for bot in competitors:
		# 1. Einkommen simulieren
		_process_bot_income(bot)
		
		# 2. Expansion (Land kaufen)
		if randf() < bot["aggressiveness"]:
			_try_buy_claim(bot)
			
		# 3. Sabotage gegen Spieler
		if randf() < bot["sabotage_tendency"]:
			_try_sabotage(bot)

func _process_bot_income(bot):
	var daily_income = 0
	# Einkommen pro Feld simulieren
	for claim in bot["inventory"]:
		daily_income += randi_range(2000, 8000) # Höheres Einkommen pro Feld
	
	# Passives Grundeinkommen (Investoren)
	daily_income += 5000 
	
	bot["cash"] += daily_income * 30
	# print(bot["name"] + " verdient $" + str(daily_income * 30))

func _try_buy_claim(bot):
	var target_region = ""
	
	# Entscheide Region: Fokus oder Zufall?
	if randf() < 0.8: # 80% Wahrscheinlichkeit für Fokus-Region
		target_region = bot["focus_regions"].pick_random()
	else:
		if game_manager.regions.keys().is_empty(): return
		target_region = game_manager.regions.keys().pick_random()
	
	if not game_manager.regions.has(target_region): return
	var region_data = game_manager.regions[target_region]
	
	if region_data == null or not region_data.has("claims"): return
	
	# Nur sichtbare Regionen
	if not region_data.get("visible", false): return
	
	# Freie Claims finden
	var available_claims = []
	for claim in region_data["claims"]:
		if claim == null or typeof(claim) != TYPE_DICTIONARY: continue
		if claim.get("is_empty", false): continue
		
		# Prüfen ob frei
		if not claim.get("owned", false) and not claim.has("ai_owner"):
			available_claims.append(claim)
			
	if available_claims.is_empty(): 
		# print(bot["name"] + ": Keine freien Felder in " + target_region)
		return
		
	var claim = available_claims.pick_random()
	
	# Preis prüfen
	var price = claim.get("price", 999999999)
	if bot["cash"] >= price:
		bot["cash"] -= price
		claim["ai_owner"] = bot["name"]
		bot["inventory"].append(claim)
		
		print(">>> " + bot["name"] + " KAUFT LAND in " + target_region + " für $" + str(price))
	else:
		pass
		# print(bot["name"] + ": Zu wenig Geld für " + target_region)

func _try_sabotage(bot):
	var target_region = bot["focus_regions"].pick_random()
	if not game_manager.regions.has(target_region): return
	
	# Prüfen ob Spieler dort aktiv ist
	var player_active = false
	if game_manager.tank_capacity.get(target_region, 0) > 0:
		player_active = true
		
	if player_active:
		var sabotage_types = GameData.SABOTAGE_OPTIONS.keys()
		if sabotage_types.is_empty(): return
		var type = sabotage_types.pick_random()
		
		print(">>> " + bot["name"] + " versucht SABOTAGE in " + target_region)
		game_manager.ai_perform_sabotage(type, target_region)
