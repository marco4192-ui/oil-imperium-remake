extends Node

# --- DATEN ---
var active_supply_contracts = []
var active_futures = []
var available_contract_offers = []
var available_future_offers = []

# --- GENERIERUNG ---
func generate_new_contract_offers(gm):
	available_contract_offers.clear()
	available_future_offers.clear()
	
	var unlocked_regions = []
	for r in gm.regions:
		if gm.regions[r]["unlocked"]: unlocked_regions.append(r)
		
	if unlocked_regions.is_empty(): return

	# 1. LIEFERVERTRÄGE (STABILITÄT)
	for i in range(randi_range(3, 5)):
		var reg = unlocked_regions.pick_random()
		var duration = [3, 6, 9, 12].pick_random()
		
		var prod_capacity = gm.get_region_daily_production(reg) * 30.0 
		if prod_capacity == 0: prod_capacity = 1000.0 
		
		var volume = int(randf_range(0.5, 1.2) * prod_capacity)
		volume = int(volume / 100.0) * 100 
		if volume < 500: volume = 500
		
		var base_price = gm.oil_price * gm.tech_bonus_oil_price
		
		var price_offer = base_price * randf_range(0.90, 1.10) 
		var penalty = int(volume * price_offer * 1.5) 
		
		available_contract_offers.append({
			"id": randi(),
			"region": reg,
			"months_total": duration,
			"volume_monthly": volume,
			"price_per_bbl": snapped(price_offer, 0.01),
			"penalty": penalty
		})

	# 2. TERMINGESCHÄFTE (FUTURES - SPEKULATION)
	if randf() < 0.7: 
		var reg = unlocked_regions.pick_random()
		var months_ahead = randi_range(2, 4)
		var volume = int(gm.tank_capacity.get(reg, 0) * 0.5)
		if volume < 2000: volume = 2000
		
		var base_price = gm.oil_price * gm.tech_bonus_oil_price
		
		var price_offer = base_price * randf_range(0.80, 1.40) 
		var penalty = int(volume * price_offer * 2.0) 
		
		var due_month = gm.date["month"] + months_ahead
		var due_year = gm.date["year"]
		while due_month > 12:
			due_month -= 12
			due_year += 1
			
		available_future_offers.append({
			"id": randi(),
			"region": reg,
			"volume": volume,
			"price_per_bbl": snapped(price_offer, 0.01),
			"due_month": due_month,
			"due_year": due_year,
			"penalty": penalty,
			"months_wait": months_ahead
		})

# --- INTERAKTION ---
func sign_supply_contract(gm, index):
	if index < 0 or index >= available_contract_offers.size(): return
	var offer = available_contract_offers[index]
	active_supply_contracts.append({
		"region": offer["region"],
		"volume_monthly": offer["volume_monthly"],
		"price_per_bbl": offer["price_per_bbl"],
		"months_left": offer["months_total"],
		"penalty": offer["penalty"]
	})
	available_contract_offers.remove_at(index)
	# FIX: Nutzung der Helper-Funktion
	gm.emit_contract_signed("supply", offer)
	gm.notify_update()

func sign_future_contract(gm, index):
	if index < 0 or index >= available_future_offers.size(): return
	var offer = available_future_offers[index]
	active_futures.append(offer) 
	available_future_offers.remove_at(index)
	# FIX: Nutzung der Helper-Funktion
	gm.emit_contract_signed("future", offer)
	gm.notify_update()

# --- VERARBEITUNG AM MONATSENDE ---
func process_contracts_end_of_month(gm):
	# 1. LIEFERVERTRÄGE
	for i in range(active_supply_contracts.size() - 1, -1, -1):
		var contract = active_supply_contracts[i]
		var reg = contract["region"]
		var stored = gm.oil_stored.get(reg, 0.0)
		
		if stored >= contract["volume_monthly"]:
			gm.oil_stored[reg] -= contract["volume_monthly"]
			var revenue = contract["volume_monthly"] * contract["price_per_bbl"]
			# Buchung über neuen Finanz-Tracker
			gm.book_transaction(reg, revenue, "Contracts")
			# FIX: Helper-Funktion
			gm.emit_contract_fulfilled("supply", revenue)
		else:
			gm.oil_stored[reg] = 0 
			var penalty = contract["penalty"] * gm.inflation_rate
			# Buchung Strafe
			gm.book_transaction(reg, -penalty, "Penalties")
			# FIX: Helper-Funktion
			gm.emit_contract_failed("supply", penalty)
			
		contract["months_left"] -= 1
		if contract["months_left"] <= 0:
			active_supply_contracts.remove_at(i)
			
	# 2. TERMINGESCHÄFTE
	for i in range(active_futures.size() - 1, -1, -1):
		var future = active_futures[i]
		if future["due_month"] == gm.date["month"] and future["due_year"] == gm.date["year"]:
			var reg = future["region"]
			var stored = gm.oil_stored.get(reg, 0.0)
			
			if stored >= future["volume"]:
				gm.oil_stored[reg] -= future["volume"]
				var revenue = future["volume"] * future["price_per_bbl"]
				gm.book_transaction(reg, revenue, "Futures")
				# FIX: Helper-Funktion
				gm.emit_contract_fulfilled("future", revenue)
				if gm.has_node("/root/FeedbackOverlay"): 
					gm.get_node("/root/FeedbackOverlay").show_msg("FUTURE FÄLLIG: Erfolgreich geliefert.")
			else:
				var missing = future["volume"] - stored
				gm.oil_stored[reg] = 0 
				
				# Berechnung Short-Selling Verlust
				var revenue_part = stored * future["price_per_bbl"]
				var buy_price = gm.oil_price * 1.05
				var buy_cost = missing * buy_price
				var revenue_total = revenue_part + (missing * future["price_per_bbl"])
				
				var net_result = revenue_total - buy_cost
				gm.book_transaction(reg, net_result, "Futures (Failed)")
				
				if gm.has_node("/root/FeedbackOverlay"): 
					var msg = "FUTURE FÄLLIG: Tank war leer!\n"
					msg += "Zukauf nötig: %d bbl @ $%.2f\n" % [missing, buy_price]
					msg += "Ergebnis: %s$%.2f" % ["+" if net_result >=0 else "", net_result]
					gm.get_node("/root/FeedbackOverlay").show_msg(msg, Color.ORANGE if net_result < 0 else Color.WHITE)
			
			active_futures.remove_at(i)
