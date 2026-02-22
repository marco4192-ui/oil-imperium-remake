extends Node

# --- EVENT POOLS ---
var random_events_pool = [
	# Standard
	{"id": "strike", "type": "fine", "title": "STREIK!", "text": "Arbeiter streiken für höhere Löhne.", "base_cost": 50000, "scale_with_wealth": true},
	{"id": "bonus", "type": "bonus", "title": "INVESTOREN", "text": "Neue Investoren glauben an Ihr Projekt.", "base_amount": 100000},
	{"id": "tech", "type": "buff", "stat": "drill_speed", "title": "NEUE TECHNIK", "text": "Neue Legierungen verbessern die Bohrgeschwindigkeit.", "duration": 12},
	
	# Unfälle
	{"id": "well_collapse", "type": "accident_rig", "title": "BOHRLOCH EINGESTÜRZT", "text": "Kritischer Druckverlust! Ein Bohrloch ist kollabiert. Equipment verloren."},
	{"id": "tank_fire", "type": "accident_tank", "title": "FEUER IN TANKANLAGE", "text": "Blitzschlag hat einen Tank entzündet! Kapazität zerstört und Öl verbrannt."},
	
	# Kriminalität & Politik
	{"id": "corruption", "type": "fine", "title": "KORRUPTION", "text": "Lokale Beamte fordern 'Bearbeitungsgebühren' für Ihre Lizenzen.", "base_cost": 75000, "scale_with_wealth": true},
	{"id": "terror_attack", "type": "terror", "title": "TERROR-ANSCHLAG", "text": "Anschlag auf Pipeline-Infrastruktur! Massive Schäden."},
	{"id": "blackmail", "type": "fine", "title": "ERPRESSUNG", "text": "Ein Warlord fordert Schutzgeld für Ihre Anlagen.", "base_cost": 100000, "scale_with_wealth": false},
	
	# Gebietsverlust
	{"id": "separatists", "type": "region_lock", "title": "SEPARATISTEN", "text": "Rebellen haben die Kontrolle über eine Region übernommen! Zugang gesperrt.", "duration_months": 6},

	# Spätere Jahre
	{"id": "activist_blockade", "type": "fine", "title": "UMWELT-BLOCKADE", "text": "Aktivisten blockieren die Zufahrtswege.", "base_cost": 40000, "min_year": 1980},
	{"id": "activist_sabotage", "type": "accident_tank", "title": "ÖKO-TERRORISMUS", "text": "Radikale Umweltschützer haben einen Tank sabotiert.", "min_year": 1995}
]

var historical_events = [
	{ "year": 1971, "month": 2, "unlock_region": "Nigeria", "title": "NIGERIA OPEC", "text": "Nigeria öffnet Markt." },
	{ "year": 1973, "month": 10, "effect_type": "price_shock", "value": 4.0, "title": "ÖLKRISE", "text": "Der Preis explodiert durch das Embargo!" },
	{ "year": 1974, "month": 5, "unlock_region": "Indonesien", "title": "ASIEN BOOMT", "text": "Indonesien steigert seine Förderung massiv." },
	{ "year": 1979, "month": 2, "effect_type": "price_shock", "value": 2.5, "title": "REVOLUTION IM IRAN", "text": "Unsicherheit treibt den Preis." }
]

var random_event_chance = 0.15

# --- LOGIK ---
func check_historical_events(gm): 
	for e in historical_events: 
		if e["year"] == gm.date["year"] and e["month"] == gm.date["month"]: 
			trigger_event(gm, e)

func check_random_events(gm): 
	if randf() <= random_event_chance: 
		trigger_random_event(gm, random_events_pool.pick_random())

func trigger_event(gm, e):
	gm.unread_news.append({"title":e["title"],"text":e["text"],"date_str":"%02d/%d"%[gm.date["month"],gm.date["year"]]})
	if e.has("unlock_region") and e["unlock_region"] in gm.regions: 
		gm.regions[e["unlock_region"]]["visible"] = true
	if e.has("effect_type"):
		if e["effect_type"]=="price_shock": gm.price_multiplier = e["value"]
		elif e["effect_type"]=="cost_increase_offshore": gm.offshore_cost_multiplier = e["value"]
		elif e["effect_type"]=="cost_increase_global": gm.global_cost_multiplier = e["value"]
	gm.notify_update()

func trigger_random_event(gm, e):
	if e.has("min_year") and gm.date["year"] < e["min_year"]: return
	
	var msg = e["text"]
	
	if e["type"] == "fine":
		var c = e["base_cost"]
		if e.get("scale_with_wealth"): c = max(c, int(gm.cash * 0.02))
		c *= gm.inflation_rate
		gm.cash -= c
		gm.current_month_stats["expenses"] += c
		msg += "\n\nKOSTEN: -$" + str(int(c))
		gm.current_month_breakdown["events"] += c
		
	elif e["type"] == "bonus":
		var b = e["base_amount"] * gm.inflation_rate
		gm.cash += b
		gm.current_month_stats["revenue"] += b
		msg += "\n\nEINNAHME: +$" + str(int(b))
		
	elif e["type"] == "buff" and e["stat"] == "drill_speed":
		gm.global_drill_speed_modifier = 0.8
		msg += "\n(Bohr-Boost aktiv!)"
		
	elif e["type"] == "accident_rig":
		var victims = []
		for r_name in gm.regions:
			for claim in gm.regions[r_name]["claims"]:
				if claim["owned"] and claim["drilled"] and claim["has_oil"]:
					victims.append(claim)
		if victims.is_empty(): return 
		var target = victims.pick_random()
		target["drilled"] = false 
		msg += "\n(Ein aktives Bohrloch ist verloren!)"
		
	elif e["type"] == "accident_tank":
		var valid_regions = []
		for r_name in gm.regions:
			if gm.tank_capacity[r_name] > 0: valid_regions.append(r_name)
		if valid_regions.is_empty(): return 
		var r_name = valid_regions.pick_random()
		var dmg_percent = randf_range(0.1, 0.5) 
		var lost_cap = int(gm.tank_capacity[r_name] * dmg_percent)
		var lost_oil = int(gm.oil_stored[r_name] * dmg_percent)
		gm.tank_capacity[r_name] -= lost_cap
		gm.oil_stored[r_name] -= lost_oil
		var fine = lost_oil * 5.0 * gm.inflation_rate
		gm.cash -= fine
		msg += "\nREGION: " + r_name
		msg += "\nVerlust Kapazität: " + str(lost_cap) + " bbl"
		msg += "\nVerbranntes Öl: " + str(lost_oil) + " bbl"
		msg += "\nUmweltstrafe: -$" + str(int(fine))
		
	elif e["type"] == "theft":
		var valid_regions = []
		for r_name in gm.regions:
			if gm.oil_stored[r_name] > 1000: valid_regions.append(r_name)
		if valid_regions.is_empty(): return
		var r_name = valid_regions.pick_random()
		var stolen = int(gm.oil_stored[r_name] * 0.08) 
		gm.oil_stored[r_name] -= stolen
		msg += "\nREGION: " + r_name
		msg += "\nGestohlen: " + str(stolen) + " bbl"

	elif e["type"] == "terror":
		var valid_regions = []
		for r_name in gm.regions:
			if gm.regions[r_name]["unlocked"]: valid_regions.append(r_name)
		if valid_regions.is_empty(): return
		var r_name = valid_regions.pick_random()
		
		# Schaden: Tank Kapazität
		var dmg_cap = int(gm.tank_capacity[r_name] * 0.3)
		gm.tank_capacity[r_name] -= dmg_cap
		
		var repair_cost = 250000 * gm.inflation_rate
		gm.cash -= repair_cost
		
		msg += "\nREGION: " + r_name
		msg += "\nInfrastruktur schwer beschädigt."
		msg += "\nReparaturkosten: -$" + str(int(repair_cost))
		
	elif e["type"] == "region_lock":
		var valid_regions = []
		for r_name in gm.regions:
			if gm.regions[r_name]["unlocked"]: valid_regions.append(r_name)
		if valid_regions.is_empty(): return
		var r_name = valid_regions.pick_random()
		
		# Region sperren (Timer setzen)
		gm.regions[r_name]["block_timer"] = e["duration_months"] * 30 # Ca. in Tagen
		
		msg += "\nREGION: " + r_name
		msg += "\nStatus: BESETZT / GESPERRT"
		msg += "\nDauer: ca. " + str(e["duration_months"]) + " Monate"

	gm.unread_news.append({"title": "EILMELDUNG: " + e["title"], "text": msg, "date_str": "%02d/%d" % [gm.date["month"], gm.date["year"]]})
	gm.notify_update()
