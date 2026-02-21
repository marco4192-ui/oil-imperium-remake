extends Node

# --- IMPORTS ---
const GameData = preload("res://GameData.gd")
const GameEvents = preload("res://GameEvents.gd")
const ContractManager = preload("res://ContractManager.gd")
const SabotageManager = preload("res://SabotageManager.gd")

var events_manager = null
var contracts_manager = null
var sabotage_manager = null

# --- SIGNALE ---
signal data_updated 
signal month_ended(report)
signal tech_researched(tech_id) 
signal tech_activated(tech_id) 
signal contract_signed(type, info)
signal contract_failed(type, penalty)
signal contract_fulfilled(type, reward)
signal phone_ringing_changed(is_ringing) 

# --- KONSTANTEN (WIRTSCHAFT 1970er) ---
const DAYS_PER_MONTH = 30

# Verwaltung & Overhead
const BASE_ADMIN_COST = 350.0         
const OFFICE_BASE_COST = 1200.0       
const LICENSE_ADMIN_COST = 150.0      

# Laufende Kosten Rigs
const RIG_MAINTENANCE_ONSHORE = 450.0 
const RIG_MAINTENANCE_OFFSHORE = 2200.0

# Tanklager Kosten
const TANK_LAND_LEASE_MONTHLY = 1500.0   
const TANK_STAFF_PER_100K = 600.0       
const TANK_MAINTENANCE_RATE = 0.005     
const TANK_BUILD_COST_PER_BBL = 3.20    

# Bohr & Equipment Kosten
const COST_PER_RIG_DAILY = 450.0      
const RESEARCH_CENTER_PRICE = 450000 
const RESEARCH_CENTER_MAINTENANCE = 1200.0 
const DRILL_DURATION_DAYS = 90.0

# Personal & Logistik
const CREW_SIZE_ONSHORE = 12
const CREW_SIZE_OFFSHORE = 40
const COST_FLIGHT_TICKET = 300.0      
const COST_HOTEL_NIGHT = 40.0         
const COST_WAGE_DAILY = 45.0          

# Hardware
const COST_PUMP_JACK = 18500.0        
const COST_OFFSHORE_PLATFORM = 1250000.0 
const COST_DRILL_BIT = 2500.0         
const BITS_NEEDED_PER_KM = 3          
const COST_PIPELINE_KM = 8500.0       
const AVG_PIPELINE_DIST_KM = 5.0      
const RIG_RATE_ONSHORE = 1800.0       
const RIG_RATE_OFFSHORE = 9500.0     
const SURVEY_COST = 8500 
const LOGISTICS_SETUP_FEE = 5000.0 

const SAVE_PATH_BASE = "user://savegame_"

# --- DATEN (SPIELER) ---
var player_name: String = ""
var company_name: String = ""
var company_logo_path: String = ""
var current_office_id: int = 0
var cash: float = 5000000.0 
var date = {"day": 1, "month": 1, "year": 1970}

# AI
var ai_controller_script = preload("res://AIController.gd")
var ai_controller = null

# Status
var is_drilling_practice = false 
var research_center_built = false 
var current_save_slot = "1" 

# Minigame Zwischenspeicher
var pending_sale_region: String = ""
var pending_sale_value: float = 0.0
var pending_sale_amount: float = 0.0 

# Hauptquartier
var hq_city = "Houston"
var available_hqs = [] 
var facilities = {} 

# --- STATISTIK & FINANZEN ---
var history_cash = []
var history_oil_price = []
var history_revenue = []
var history_expenses = []
var history_profit = []

# Struktur: { "Global": { "revenue": {"sales": 0}, "expenses": {"office": 0} }, "Texas": ... }
var current_month_finance = {} 

# Tracker für Spot-Sales
var spot_sales_history = {}

# --- WIRTSCHAFT ---
var oil_price: float = 8.50 
var oil_price_trend = 0.0 
var inflation_rate = 1.0 
var daily_income = 0.0; var daily_expenses = 0.0; var total_daily_production = 0.0

var current_month_stats = { "revenue": 0.0, "expenses": 0.0, "oil_produced": 0.0 }
var current_month_breakdown = { "office": 0.0, "rigs": 0.0, "tanks": 0.0, "construction": 0.0, "events": 0.0, "facilities": 0.0, "research": 0.0, "contracts": 0.0 }

# --- KOMPATIBILITÄT ---
var active_supply_contracts: Array:
	get: return contracts_manager.active_supply_contracts if contracts_manager else []
var active_futures: Array:
	get: return contracts_manager.active_futures if contracts_manager else []
var available_contract_offers: Array:
	get: return contracts_manager.available_contract_offers if contracts_manager else []
var available_future_offers: Array:
	get: return contracts_manager.available_future_offers if contracts_manager else []

# --- SABOTAGE & TELEFON STATUS ---
var phone_ringing = false
var pending_sabotage_reports = [] 

# --- REGIONEN ---
var current_viewing_region = "Texas"
var active_region_name = "" 
var active_claim_id = -1   

var global_cost_multiplier = 1.0; var price_multiplier = 1.0; var offshore_cost_multiplier = 1.0 

var regions = {} 

# EXPLIZITE INITIALISIERUNG
var tank_capacity = {}
var oil_stored = {}
var tank_build_year = {}
var tank_investment = {}

var office_data = {}
var tech_level = 1; var current_era = 0; var global_drill_speed_modifier = 1.0 
var era_upgrade_cost = {}; var era_colors = {}
var researched_techs = []; var unlocked_techs = []   
var tech_bonus_survey_accuracy = 0.0; var tech_bonus_production = 1.0; var tech_bonus_oil_price = 1.0       
var current_research_id = ""; var current_research_days_left = 0
var tech_database = {}

var unread_news = [] 
var news_archive = [] 

func _ready():
	_load_static_data()
	_init_finance_tracker() 
	
	events_manager = GameEvents.new()
	add_child(events_manager)
	contracts_manager = ContractManager.new()
	add_child(contracts_manager)
	sabotage_manager = SabotageManager.new() 
	add_child(sabotage_manager)
	
	record_history()
	generate_claims()
	contracts_manager.generate_new_contract_offers(self)
	
	ai_controller = ai_controller_script.new()
	add_child(ai_controller) 
	ai_controller.game_manager = self
	
func _load_static_data():
	office_data = GameData.OFFICE_DATA
	available_hqs = GameData.AVAILABLE_HQS
	facilities = GameData.FACILITIES_TEMPLATE.duplicate(true)
	tech_database = GameData.TECH_DATABASE
	era_colors = GameData.ERA_COLORS
	era_upgrade_cost = GameData.ERA_UPGRADE_COST
	
	# Initialisiere Regionen VOLLSTÄNDIG
	regions = {
		"Texas": { 
			"visible": true, 
			"unlocked": false, 
			"license_fee": 200000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/texas.png", 
			"grid_pos": Vector2(550, 100), 
			"block_timer": 0,
			"offshore_ratio": 0.0
		},
		"Alaska": { 
			"visible": true, 
			"unlocked": false, 
			"license_fee": 500000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/alaska.png", 
			"grid_pos": Vector2(650, 100), 
			"block_timer": 0,
			"offshore_ratio": 0.2
		},
		"Nordsee": { 
			"visible": true, 
			"unlocked": false, 
			"license_fee": 1500000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/nordsee.png", 
			"grid_pos": Vector2(750, 100), 
			"block_timer": 0,
			"offshore_ratio": 1.0
		},
		"Saudi-Arabien": { 
			"visible": true, 
			"unlocked": false, 
			"license_fee": 3000000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/saudi.png", 
			"grid_pos": Vector2(900, 250), 
			"block_timer": 0,
			"offshore_ratio": 0.1
		},
		"Sibirien": { 
			"visible": true, 
			"unlocked": false, 
			"license_fee": 800000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/sibirien.png", 
			"grid_pos": Vector2(655, 200), 
			"block_timer": 0,
			"offshore_ratio": 0.0
		},
		"Venezuela": { 
			"visible": false, 
			"unlocked": false, 
			"license_fee": 1200000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/Venezuela.png", 
			"grid_pos": Vector2(600, 200), 
			"block_timer": 0,
			"offshore_ratio": 0.4
		},
		"Nigeria": { 
			"visible": false, 
			"unlocked": false, 
			"license_fee": 900000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/nigeria.png", 
			"grid_pos": Vector2(630, 550), 
			"block_timer": 0,
			"offshore_ratio": 0.3
		},
		"Mexiko": { 
			"visible": false, 
			"unlocked": false, 
			"license_fee": 2000000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/mexiko.png", 
			"grid_pos": Vector2(655, 400), 
			"block_timer": 0,
			"offshore_ratio": 0.5
		},
		"Indonesien": { 
			"visible": false, 
			"unlocked": false, 
			"license_fee": 1100000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/indonesien.png", 
			"grid_pos": Vector2(655, 200), 
			"block_timer": 0,
			"offshore_ratio": 0.6
		},
		"Brasilien": { 
			"visible": false, 
			"unlocked": false, 
			"license_fee": 3500000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/brasilien.png", 
			"grid_pos": Vector2(920, 150), 
			"block_timer": 0,
			"offshore_ratio": 0.3
		},
		"Libyen": { 
			"visible": false, 
			"unlocked": false, 
			"license_fee": 1800000, 
			"claims": [], 
			"map_bg": "res://assets/70s_Maps/libyen.png", 
			"grid_pos": Vector2(655, 200), 
			"block_timer": 0,
			"offshore_ratio": 0.0
		}
	}
	
	for r in regions:
		tank_capacity[r] = 0; oil_stored[r] = 0.0; tank_build_year[r] = 0; tank_investment[r] = 0

# --- START NEW GAME ---
func start_new_game(p_name: String, c_name: String, c_logo_path: String, office_idx: int, hq_idx: int):
	player_name = p_name
	company_name = c_name
	company_logo_path = c_logo_path
	current_office_id = office_idx
	
	if hq_idx >= 0 and hq_idx < available_hqs.size():
		hq_city = available_hqs[hq_idx]["name"]
	else:
		hq_city = "Houston"
	
	cash = 5000000.0 
	date = {"day": 1, "month": 1, "year": 1970}
	
	history_cash.clear()
	history_profit.clear()
	history_revenue.clear()
	history_expenses.clear()
	history_oil_price.clear()
	
	spot_sales_history.clear()
	current_month_finance.clear()
	
	oil_price = 8.50
	inflation_rate = 1.0 # Reset Inflation
	
	for r in regions:
		regions[r]["unlocked"] = false
		regions[r]["claims"].clear()
		tank_capacity[r] = 0
		oil_stored[r] = 0.0
	
	generate_claims()
	_init_finance_tracker()
	record_history()
	
	if contracts_manager:
		contracts_manager.generate_new_contract_offers(self)
	
	get_tree().change_scene_to_file("res://Office.tscn")

# --- FINANZ BUCHHALTUNG ---
func _init_finance_tracker():
	current_month_finance.clear()
	spot_sales_history.clear() 
	
	current_month_finance["Global"] = { "revenue": {}, "expenses": {} }
	for r in regions:
		current_month_finance[r] = { "revenue": {}, "expenses": {} }

func book_transaction(region: String, amount: float, category: String):
	cash += amount
	
	var target_region = region
	if target_region == "" or not current_month_finance.has(target_region):
		target_region = "Global"
		
	var bucket = "revenue"
	if amount < 0: 
		bucket = "expenses"
		amount = abs(amount)
	
	var stats = current_month_finance[target_region][bucket]
	if not stats.has(category):
		stats[category] = 0.0
	stats[category] += amount
	
	notify_update()

# --- Simulation & Updates ---
func next_day():
	if current_research_id != "":
		current_research_days_left -= 1
		if current_research_days_left <= 0: finish_research()
			
	if date["month"] == 1 and date["day"] == 1:
		# Jahreswechsel
		var year = date["year"]
		var yearly_rate = 1.04 
		
		if year < 1973: yearly_rate = 1.05 
		elif year < 1982: yearly_rate = 1.09 
		elif year < 1990: yearly_rate = 1.04 
		else: yearly_rate = 1.03 
		
		inflation_rate *= yearly_rate
		
	for r_name in regions:
		if regions[r_name].has("block_timer") and regions[r_name]["block_timer"] > 0:
			regions[r_name]["block_timer"] -= 1
			if regions[r_name]["block_timer"] <= 0:
				unread_news.append({"title": "KONFLIKT BEENDET", "text": "Lage in " + r_name + " normalisiert.", "date_str": "%02d/%d" % [date["month"], date["year"]]})
				
	process_day_simulation()
	date["day"] += 1
	if date["day"] > DAYS_PER_MONTH: finish_month()
	else: notify_update()

func process_day_simulation():
	# 1. Global: Facilities & Office
	var daily_fac_cost = 0.0
	for fac_id in facilities:
		if facilities[fac_id]["built"]:
			daily_fac_cost += facilities[fac_id]["maintenance"]
	if daily_fac_cost > 0:
		book_transaction("Global", -daily_fac_cost * inflation_rate, "Facilities")
	
	var office_cost = OFFICE_BASE_COST * (1.0 + (current_era * 0.5))
	book_transaction("Global", -office_cost * inflation_rate, "Office")
	
	# 2. Global: Admin
	var active_licenses = 0
	for r in regions: if regions[r]["unlocked"]: active_licenses += 1
	var admin_cost = BASE_ADMIN_COST + (active_licenses * LICENSE_ADMIN_COST)
	book_transaction("Global", -admin_cost * inflation_rate, "Admin")
	
	# 3. Regional: Rigs & Produktion
	for r_name in regions:
		# SICHERHEITSCHECK: Existiert die Region?
		if regions[r_name] == null: continue
		if not regions[r_name].get("unlocked", false): continue
		if regions[r_name].has("block_timer") and regions[r_name]["block_timer"] > 0: continue
		
		var region = regions[r_name]
		var active_rigs = 0
		var region_prod = 0.0
		
		# WICHTIG: Überspringe leere Claims
		var claims_list = region.get("claims", [])
		if typeof(claims_list) != TYPE_ARRAY: continue

		for claim in claims_list:
			if claim == null or typeof(claim) != TYPE_DICTIONARY: continue
			if claim.get("is_empty", false): continue
			
			if claim.get("owned", false) and claim.get("drilled", false):
				active_rigs += 1
				claim.get_or_add("days_active", 0)
				claim["days_active"] += 1
				
				if claim.get("has_oil", false) and claim.get("reserves_remaining", 0) > 0:
					var extracted_amount = claim["yield"] * randf_range(0.95, 1.05) * tech_bonus_production
					extracted_amount = min(extracted_amount, claim["reserves_remaining"])
					region_prod += extracted_amount
					claim["reserves_remaining"] -= extracted_amount
		
		# Öl einlagern
		var cap = tank_capacity.get(r_name, 0)
		var stored = oil_stored.get(r_name, 0.0)
		if stored < cap:
			var add = min(region_prod, cap - stored)
			oil_stored[r_name] += add
		
		# Kosten buchen
		var rig_cost = RIG_MAINTENANCE_ONSHORE
		if region.get("offshore_ratio", 0) > 0.5: rig_cost = RIG_MAINTENANCE_OFFSHORE
		var daily_rig_bill = active_rigs * rig_cost * global_cost_multiplier * inflation_rate
		
		if daily_rig_bill > 0:
			book_transaction(r_name, -daily_rig_bill, "Rig Operation")

	# Ölpreis Simulation
	oil_price_trend += randf_range(-0.05, 0.05)
	oil_price_trend = clamp(oil_price_trend, -0.2, 0.2)
	oil_price += oil_price_trend
	var target = oil_price * price_multiplier * tech_bonus_oil_price
	oil_price = lerp(oil_price, target, 0.05)
	oil_price = clamp(oil_price, 5.0, 150.0)
	
func finish_month():
	# Tankkosten abrechnen
	for r_name in regions:
		var cap = tank_capacity.get(r_name, 0)
		if cap > 0:
			var land = TANK_LAND_LEASE_MONTHLY
			var staff = (cap / 100000.0) * TANK_STAFF_PER_100K
			var maint = (cap * TANK_BUILD_COST_PER_BBL) * TANK_MAINTENANCE_RATE
			var total = (land + staff + maint) * inflation_rate
			book_transaction(r_name, -total, "Storage")

	if contracts_manager: contracts_manager.process_contracts_end_of_month(self)
	if contracts_manager: contracts_manager.generate_new_contract_offers(self)
	
	if events_manager:
		events_manager.check_historical_events(self)
		events_manager.check_random_events(self)
	
	if ai_controller: ai_controller.process_ai_turn()
	
	record_history()
	
	date["day"] = 1
	date["month"] += 1
	if date["month"] > 12:
		date["month"] = 1
		date["year"] += 1
		
	_init_finance_tracker()
	save_game(current_save_slot) 
	
	month_ended.emit({}) 
	notify_update()

# --- HELPER FUNCTIONS FÜR EXTERNE SIGNALE (CONTRACTS) ---
func emit_contract_signed(type, info):
	contract_signed.emit(type, info)

func emit_contract_failed(type, penalty):
	contract_failed.emit(type, penalty)

func emit_contract_fulfilled(type, reward):
	contract_fulfilled.emit(type, reward)

# --- INTERAKTIONEN ---

func try_buy_tank(r, size, _dummy):
	if regions[r] == null or not regions[r].get("unlocked", false): return false
	var cost = get_tank_cost(size)
	if cash >= cost:
		tank_capacity[r] += size
		tank_build_year[r] = date["year"]
		book_transaction(r, -cost, "Construction")
		return true
	return false

func try_buy_license(r):
	var f = regions[r]["license_fee"] * inflation_rate
	if cash >= f:
		regions[r]["unlocked"] = true
		book_transaction(r, -f, "License")
		return true
	return false

# VERKAUFS-LOGIK
func commit_sale(r, amount, value, bypass_minigame: bool = false):
	if spot_sales_history.get(r, false):
		if has_node("/root/FeedbackOverlay"):
			get_node("/root/FeedbackOverlay").show_msg("MARKT GESCHLOSSEN: Verkaufslimit für " + r + " erreicht!", Color.RED)
		return

	if not bypass_minigame and amount > 1000.0 and randf() < 0.30:
		start_pipeline_minigame(r, amount, value)
		return

	if oil_stored[r] >= amount:
		oil_stored[r] -= amount
		book_transaction(r, value, "Spot Sales")
		spot_sales_history[r] = true
		if has_node("/root/FeedbackOverlay"):
			get_node("/root/FeedbackOverlay").show_msg("VERKAUF ERFOLGREICH: +$" + str(int(value)), Color.GREEN)

func start_pipeline_minigame(r, amount, value):
	pending_sale_region = r
	pending_sale_value = value
	pending_sale_amount = amount
	
	if has_node("/root/FeedbackOverlay"):
		get_node("/root/FeedbackOverlay").show_msg("ACHTUNG: PIPELINE PROBLEME! MANUELLE KONTROLLE NÖTIG!", Color.ORANGE)
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://PipelineClassic.tscn")

func finalize_sale_success():
	var r = pending_sale_region
	var amt = pending_sale_amount
	var val = pending_sale_value
	
	if oil_stored.get(r, 0.0) >= amt:
		oil_stored[r] -= amt
		book_transaction(r, val, "Spot Sales")
		spot_sales_history[r] = true 
		
	pending_sale_region = ""
	pending_sale_value = 0.0
	pending_sale_amount = 0.0

func finalize_sale_fail():
	var r = pending_sale_region
	if has_node("/root/FeedbackOverlay"):
		get_node("/root/FeedbackOverlay").show_msg("VERKAUF ABGEBROCHEN! LEITUNG DEFEKT. Versuche es nächsten Monat.", Color.RED)
	spot_sales_history[r] = true 
	pending_sale_region = ""
	pending_sale_value = 0.0
	pending_sale_amount = 0.0

func sell_tanks(r):
	var val = get_tank_sell_value(r)
	if val > 0:
		tank_capacity[r] = 0
		oil_stored[r] = 0
		book_transaction(r, val, "Liquidation")
		return true
	return false

func build_facility(fid):
	if not facilities.has(fid): return
	var cost = facilities[fid]["cost"] * inflation_rate
	if cash >= cost:
		facilities[fid]["built"] = true
		book_transaction("Global", -cost, "Construction")
		notify_update()

func start_research(tid):
	var tech = tech_database[tid]
	var cost = tech["research_cost"] * inflation_rate
	if cash >= cost:
		current_research_id = tid
		current_research_days_left = tech["research_time"]
		book_transaction("Global", -cost, "R&D")
		notify_update()

func buy_tech_hardware(tid):
	var tech = tech_database[tid]
	var cost = tech["hardware_cost"] * inflation_rate
	if cash >= cost:
		unlocked_techs.append(tid)
		apply_tech_effect(tech["effect"])
		tech_activated.emit(tid)
		book_transaction("Global", -cost, "Upgrades")
		notify_update()

# --- SABOTAGE ---
func player_order_sabotage(type, region):
	if sabotage_manager:
		var res = sabotage_manager.execute_sabotage(self, type, region, true)
		trigger_phone_ring(res)
		return res

func ai_perform_sabotage(type, region):
	if sabotage_manager:
		var res = sabotage_manager.execute_sabotage(self, type, region, false)
		if res.success or res.detected: trigger_phone_ring(res)

func trigger_phone_ring(rep):
	pending_sabotage_reports.append(rep)
	phone_ringing = true
	phone_ringing_changed.emit(true)

func answer_phone():
	if pending_sabotage_reports.is_empty(): 
		phone_ringing = false; phone_ringing_changed.emit(false); return null
	var rep = pending_sabotage_reports.pop_front()
	if pending_sabotage_reports.is_empty(): phone_ringing = false; phone_ringing_changed.emit(false)
	return rep

# --- Helper ---
func record_history():
	history_cash.append(cash)
	history_oil_price.append(oil_price)
	history_profit.append(0) 
	
func finish_research():
	researched_techs.append(current_research_id)
	current_research_id = ""
	tech_researched.emit(current_research_id)
	notify_update()

# --- SPEICHERSYSTEM ---
func save_game(slot_name: String = "1"):
	var path = SAVE_PATH_BASE + slot_name + ".save"
	current_save_slot = slot_name
	
	var contracts_data = []
	var futures_data = []
	if contracts_manager:
		contracts_data = contracts_manager.active_supply_contracts
		futures_data = contracts_manager.active_futures
	
	var save_data = {
		"player": {
			"name": player_name,
			"company": company_name,
			"cash": cash,
			"logo": company_logo_path,
			"office_id": current_office_id,
			"hq": hq_city
		},
		"date": date,
		"regions": regions, 
		"tanks": {
			"capacity": tank_capacity,
			"stored": oil_stored,
			"build_year": tank_build_year,
			"investment": tank_investment
		},
		"tech": {
			"level": tech_level,
			"era": current_era,
			"researched": researched_techs,
			"unlocked": unlocked_techs,
			"current_research": current_research_id,
			"days_left": current_research_days_left
		},
		"facilities": facilities,
		"economy": {
			"oil_price": oil_price,
			"inflation": inflation_rate,
			"contracts": contracts_data,
			"futures": futures_data,
			"spot_sales_history": spot_sales_history 
		},
		"stats": {
			"history_cash": history_cash,
			"history_profit": history_profit
		}
	}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		if has_node("/root/FeedbackOverlay"): get_node("/root/FeedbackOverlay").show_msg("SPIEL GESPEICHERT (SLOT " + slot_name + ")")
	else:
		print("Fehler beim Speichern!")

func load_game(slot_name: String = "1"):
	var path = SAVE_PATH_BASE + slot_name + ".save"
	if not FileAccess.file_exists(path):
		print("Kein Savegame in Slot " + slot_name)
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return false
	
	var data = file.get_var()
	current_save_slot = slot_name
	
	if data.has("player"):
		player_name = data.player.name
		company_name = data.player.company
		cash = data.player.cash
		company_logo_path = data.player.logo
		current_office_id = data.player.office_id
		hq_city = data.player.hq
		
	if data.has("date"): date = data.date
	
	if data.has("regions"): 
		var loaded_regions = data.regions
		for r_name in regions:
			if loaded_regions.has(r_name):
				regions[r_name] = loaded_regions[r_name]
				if not regions[r_name].has("block_timer"):
					regions[r_name]["block_timer"] = 0
	
	if data.has("tanks"):
		tank_capacity = data.tanks.capacity
		oil_stored = data.tanks.stored
		tank_build_year = data.tanks.build_year
		tank_investment = data.tanks.investment
		
	if data.has("tech"):
		tech_level = data.tech.level
		current_era = data.tech.era
		researched_techs = data.tech.researched
		unlocked_techs = data.tech.unlocked
		current_research_id = data.tech.current_research
		current_research_days_left = data.tech.days_left
		
	if data.has("facilities"): facilities = data.facilities
	
	if data.has("economy"):
		oil_price = data.economy.oil_price
		inflation_rate = data.economy.inflation
		if contracts_manager:
			contracts_manager.active_supply_contracts = data.economy.contracts
			contracts_manager.active_futures = data.economy.futures
		if data.economy.has("spot_sales_history"):
			spot_sales_history = data.economy.spot_sales_history
		else:
			spot_sales_history.clear()
		
	if data.has("stats"):
		history_cash = data.stats.history_cash
		history_profit = data.stats.history_profit
	
	notify_update()
	return true

func get_existing_saves() -> Array:
	var list = []
	for i in range(1, 4):
		var s = str(i)
		if FileAccess.file_exists(SAVE_PATH_BASE + s + ".save"):
			list.append(s)
	return list

func notify_update(): data_updated.emit()
func advance_time(days): for i in range(days): next_day()

# --- DELEGATION ---
func generate_new_contract_offers():
	if contracts_manager: contracts_manager.generate_new_contract_offers(self)

func sign_supply_contract(offer_index):
	if contracts_manager: contracts_manager.sign_supply_contract(self, offer_index)

func sign_future_contract(offer_index):
	if contracts_manager: contracts_manager.sign_future_contract(self, offer_index)

func process_contracts_end_of_month():
	if contracts_manager: contracts_manager.process_contracts_end_of_month(self)

func apply_tech_effect(effect_name):
	match effect_name:
		"survey_accuracy_small": tech_bonus_survey_accuracy = 0.2
		"survey_accuracy_medium": tech_bonus_survey_accuracy = 0.4
		"survey_accuracy_high": tech_bonus_survey_accuracy = 0.8
		"drill_speed_small": global_drill_speed_modifier *= 0.8
		"drill_speed_medium": global_drill_speed_modifier *= 0.8
		"production_boost_small": tech_bonus_production = 1.10
		"production_boost_medium": tech_bonus_production = 1.25
		"production_boost_high": tech_bonus_production = 1.50
		"safety_boost": pass 

# --- CALCS ---
func get_region_daily_production(region_name: String) -> float:
	if not regions.has(region_name): return 0.0
	var region = regions[region_name]
	if region == null: return 0.0
	if region.has("block_timer") and region["block_timer"] > 0: return 0.0
		
	var total = 0.0
	for claim in region["claims"]:
		if claim.get("is_empty", false): continue
		if claim.get("owned", false) and claim.get("drilled", false) and claim.get("has_oil", false) and claim.get("reserves_remaining", 0) > 0:
			total += claim["yield"]
	return total

func calculate_drilling_costs(region_name: String, is_self: bool) -> Dictionary:
	if not regions.has(region_name) or regions[region_name] == null: 
		return {"total":0, "logistics":0, "rental":0, "crew":0, "duration":0}
	var region = regions[region_name]
	var is_offshore = (region.get("offshore_ratio", 0.0) > 0.0)
	return calculate_drilling_costs_internal(region_name, is_self, is_offshore)

func calculate_drilling_costs_internal(_region_name: String, is_self: bool, is_claim_offshore: bool) -> Dictionary:
	var duration = DRILL_DURATION_DAYS
	if not is_self: duration = 30.0 
	
	var crew_size = CREW_SIZE_ONSHORE
	if is_claim_offshore: crew_size = CREW_SIZE_OFFSHORE
	
	var cost_flights = crew_size * COST_FLIGHT_TICKET * inflation_rate
	var cost_hotel = crew_size * duration * COST_HOTEL_NIGHT * inflation_rate
	var cost_wages = crew_size * duration * COST_WAGE_DAILY * inflation_rate
	
	var pump_cost = 0.0
	if is_claim_offshore: pump_cost = COST_OFFSHORE_PLATFORM * inflation_rate
	else: pump_cost = COST_PUMP_JACK * inflation_rate
	
	var depth_km = 2.0
	var bits_cost = (depth_km * BITS_NEEDED_PER_KM) * COST_DRILL_BIT * inflation_rate
	var pipe_cost = AVG_PIPELINE_DIST_KM * COST_PIPELINE_KM * inflation_rate
	
	var daily_rate = RIG_RATE_ONSHORE
	if is_claim_offshore: daily_rate = RIG_RATE_OFFSHORE
	var rig_total = daily_rate * duration * inflation_rate
	
	var expert_fee = 0.0
	if not is_self: expert_fee = 350000.0 * inflation_rate
	
	var logistics_total = cost_flights + cost_hotel + pipe_cost + LOGISTICS_SETUP_FEE + pump_cost + expert_fee
	var rental_total = rig_total + bits_cost
	var crew_total = cost_wages
	
	var total_sum = logistics_total + rental_total + crew_total
	
	return {
		"total": int(total_sum),
		"logistics": int(logistics_total), 
		"rental": int(rental_total),
		"crew": int(crew_total),
		"duration": int(duration)
	}

func get_survey_cost(region_name: String, is_offshore: bool) -> int:
	var calc = calculate_drilling_costs_internal(region_name, true, is_offshore)
	return int(calc["total"] * 0.15) 

func get_tank_cost(size_capacity: int) -> int:
	return int(size_capacity * TANK_BUILD_COST_PER_BBL * inflation_rate)

func get_tank_sell_value(r):
	var c = tank_capacity.get(r, 0)
	if c <= 0: return 0
	
	var investment = tank_investment.get(r, 0)
	if investment == 0: investment = int(c * TANK_BUILD_COST_PER_BBL) 
	
	var age = date["year"] - tank_build_year.get(r, date["year"])
	if age < 0: age = 0
	
	var depreciation_per_year = 0.05
	var start_value_percent = 0.80
	var p = start_value_percent - (float(age) * depreciation_per_year)
	if p > 0.80: p = 0.80
	if p < 0.10: p = 0.10
	
	return int(investment * p)

func check_tech_availability():
	if current_era==0 and date["year"]>=1982: return true
	if current_era==1 and date["year"]>=1995: return true
	return false

func upgrade_era():
	var n=current_era+1; if era_upgrade_cost.has(n):
		var c=era_upgrade_cost[n]*inflation_rate
		if cash>=c: cash-=c; current_era=n; current_month_breakdown["construction"]+=c; notify_update(); return true
	return false

func generate_claims():
	for r in regions:
		if regions[r] == null:
			regions[r] = { "claims": [] }
			
		if not regions[r].has("claims"):
			regions[r]["claims"] = []
			
		if regions[r]["claims"].size() > 0: continue
		
		if GameData.REGION_LAYOUTS.has(r): 
			var id = 0
			for row in GameData.REGION_LAYOUTS[r]:
				for cell_char in row:
					
					# Wir erstellen IMMER einen Eintrag, auch für leere Felder (Platzhalter)
					if cell_char == "_" or cell_char == "0":
						regions[r]["claims"].append({ "is_empty": true, "id": -1 })
					else:
						# Echter Claim
						var w = (cell_char == "W")
						var d = {
							"id": id,
							"is_empty": false, 
							"owned": false,
							"drilled": false,
							"has_oil": false,
							"yield": 0.0,
							"reserves_max": 0.0,
							"reserves_remaining": 0.0,
							"surveyed": false,
							"survey_yield": 0.0,
							"survey_reserves": 0.0,
							"is_offshore": w,
							"days_active": 0 
						}
						
						var bp = 250000 if not w else 1200000 
						d["price"] = randi_range(int(bp * 0.8), int(bp * 1.2))
						
						if randf() < 0.7: 
							d["has_oil"] = true 
							d["yield"] = randf_range(500.0, 4000.0) 
							var lt = randi_range(365 * 3, 365 * 8)
							d["reserves_max"] = d["yield"] * lt
							d["reserves_remaining"] = d["reserves_max"]
						
						regions[r]["claims"].append(d)
						id += 1 # ID nur für echte Felder erhöhen

func get_survey_result(region_name, claim):
	if claim == null or typeof(claim) != TYPE_DICTIONARY: return {"yield":0, "reserves":0}
	
	var r=randf()*100.0; var dev=0.0
	if r<5.0: dev=2.0; if randf()<0.5: dev=-0.9
	elif r<15.0: dev=0.5
	elif r<35.0: dev=0.3
	elif r<65.0: dev=0.2
	else: dev=0.1
	if randf()<0.5: dev*=-1.0
	dev = dev * (1.0 - tech_bonus_survey_accuracy)
	
	var ry = claim.get("yield", 0.0)
	var rr = claim.get("reserves_remaining", 0.0)
	if not claim.get("has_oil", false): ry=20.0; rr=50000.0
	
	var ey=max(0, ry*(1.0+dev)); var er=max(0, rr*(1.0+dev))
	claim["surveyed"]=true; claim["survey_yield"]=ey; claim["survey_reserves"]=er
	var cost = get_survey_cost(region_name, claim.get("is_offshore", false))
	book_transaction("Global", -cost, "Services") 
	return {"yield":ey, "reserves":er}

# --- FIX: ROBUSTE CLAIM SUCHE & VERKAUF ---

func _get_claim_by_id(region_name, claim_id):
	# 1. Existiert die Region überhaupt in unserem Dictionary?
	if not regions.has(region_name): return null
	
	# 2. Ist der Eintrag NULL? (Das ist der häufigste Fehler bei "base of type null")
	var region_data = regions[region_name]
	if region_data == null: return null
	
	# 3. Hat die Region Claims?
	if not region_data.has("claims"): return null
	var list = region_data["claims"]
	
	# 4. Ist die Liste selbst valide?
	if list == null or typeof(list) != TYPE_ARRAY: return null
	
	for c in list:
		if c == null or typeof(c) != TYPE_DICTIONARY: continue
		if c.get("is_empty", false): continue
		
		# Sicherer Zugriff auf ID
		if int(c.get("id", -999)) == int(claim_id):
			return c
			
	return null

func get_claim_sell_value(region_name, claim_id):
	var claim = _get_claim_by_id(region_name, claim_id)
	
	if claim == null: return 0
	
	# Verwende .get() um sicherzustellen, dass es keinen Crash gibt, 
	# selbst wenn ein Key fehlt.
	if not claim.get("owned", false): return 0
	
	# Preis holen (mit default)
	var price = claim.get("price", 0)
	
	# Fall 1: Noch nicht gebohrt
	if not claim.get("drilled", false):
		# Wenn gescannt und Ergebnis schlecht (weniger als 100 bbl/Tag Prognose),
		# fällt der Marktwert massiv, weil keiner "leeres Land" will.
		if claim.get("surveyed", false) and claim.get("survey_yield", 0) < 100:
			return int(price * 0.10) # Nur 10% statt 75%
			
		return int(price * 0.75)
		
	# Fall 2: Gebohrt aber kein Öl (Trocken)
	if not claim.get("has_oil", false): 
		return 2500 # Schrottwert für die Rohre (war 15000)
	
	# Fall 3: Gebohrt und Öl (Aktive Quelle)
	var days = claim.get("days_active", 0)
	var depreciation = 0.002 * days 
	var calculated_val = float(price) * (1.0 - depreciation)
	
	return int(max(10000, calculated_val))

func sell_claim(region_name, claim_id):
	# Zuerst prüfen, ob Region valide ist
	if not regions.has(region_name) or regions[region_name] == null: return
	
	# Wir suchen den Claim manuell aus der Liste, um ganz sicher zu gehen
	# dass wir die korrekte Referenz haben
	var claims_list = regions[region_name].get("claims", [])
	if typeof(claims_list) != TYPE_ARRAY: return
	
	var target_claim = null
	
	for c in claims_list:
		if c == null or typeof(c) != TYPE_DICTIONARY: continue
		if c.get("is_empty", false): continue
		if int(c.get("id", -999)) == int(claim_id):
			target_claim = c
			break
	
	# Jetzt prüfen wir die Referenz
	if target_claim == null: return
	
	# Sicherheitshalber nochmal owned checken
	if not target_claim.get("owned", false): return
	
	# Wert berechnen (auch hier nutzen wir die ID, das ist sicher)
	var sp = get_claim_sell_value(region_name, claim_id)
	
	# Transaktion buchen
	book_transaction("Global", sp, "Liquidation")
	
	# Direkt schreiben (wir wissen, dass target_claim != null ist, weil wir es gerade gefunden haben)
	target_claim["owned"] = false
	target_claim["drilled"] = false
	target_claim["days_active"] = 0 
	
	notify_update()

func try_buy_tank_wrapper(r,s): return try_buy_tank(r,s,0)
