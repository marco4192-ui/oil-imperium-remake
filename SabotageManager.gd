extends Node

# Ergebnis-Struktur für Rückmeldungen
class SabotageResult:
	var success: bool = false
	var detected: bool = false
	var message: String = ""
	var stolen_amount: int = 0
	var damage_cost: int = 0
	var type: String = ""
	var target_name: String = ""
	var attacker_name: String = ""
	var fine_paid: int = 0
	var intel_gathered: String = "" # NEU: Informationen über den Angreifer bei Entdeckung

# Hauptfunktion: Führt Sabotage aus
func execute_sabotage(gm, type: String, target_region: String, is_player_action: bool) -> SabotageResult:
	var result = SabotageResult.new()
	result.type = type
	
	# Wer ist der Angreifer?
	var attacker_identity = gm.player_name if is_player_action else "Unbekannter Konkurrent"
	result.attacker_name = attacker_identity
	
	if not gm.regions.has(target_region):
		result.message = "Fehler: Region existiert nicht."
		return result
	
	# FIX: Prüfen ob Sabotage-Typ existiert, um Absturz zu verhindern!
	if not gm.GameData.SABOTAGE_OPTIONS.has(type):
		result.message = "Fehler: Unbekannter Sabotage-Typ: " + str(type)
		result.success = false
		return result
		
	var data = gm.GameData.SABOTAGE_OPTIONS[type]
	var cost = int(data["cost"] * gm.inflation_rate)
	
	# 1. Kosten & Voraussetzungen prüfen
	if is_player_action:
		if gm.cash < cost:
			result.message = "Operation abgebrochen: Unzureichende Mittel für Bestechung/Ausrüstung."
			return result
		gm.book_transaction("Global", -cost, "Black Ops")
	
	# 2. Erfolgswahrscheinlichkeit
	var success_chance = data["base_success_chance"]
	
	# Modifikatoren (z.B. Sicherheits-Upgrades der Region/Spieler)
	# Hier könnte man später Tech-Level einbeziehen
	
	if randf() < success_chance:
		result.success = true
		_apply_sabotage_effect(gm, type, target_region, result, is_player_action, data)
	else:
		result.success = false
		result.message = "Operation gescheitert. Sicherheitskräfte waren wachsam."
		
	# 3. Entdeckungsrisiko
	var detection_chance = data["detection_chance"]
	if not result.success: detection_chance += 0.2 # Höheres Risiko bei Fehlschlag
	
	if randf() < detection_chance:
		result.detected = true
		if is_player_action:
			_handle_player_detected(gm, result, data)
		else:
			result.message += "\nSPIONAGE-BERICHT: Spuren deuten auf einen Angriff hin."
			result.intel_gathered = "Verdacht auf Fremdeinwirkung."
	
	return result

func _apply_sabotage_effect(gm, type, region, result, is_player_attacker, data):
	match type:
		"arson": _apply_arson(gm, region, result)
		"destroy_tank": _apply_tank_destruction(gm, region, result)
		"theft": _apply_theft(gm, region, result, is_player_attacker, data)
		"strike_incite": _apply_strike(gm, region, result)
		_: 
			result.success = false
			result.message = "Sabotage-Effekt nicht implementiert: " + type

func _handle_player_detected(gm, result, data):
	var fine = int(data["fine_amount"] * gm.inflation_rate)
	gm.cash -= fine
	result.fine_paid = fine
	result.message += "\nAUFGEFLOGEN! Die Behörden haben Beweise gefunden."
	result.message += "\nStrafe gezahlt: -$" + str(fine)
	gm.book_transaction("Global", 0, "Fines") # Buchung nur für Statistik, Cash schon abgezogen

# --- EFFEKTE ---

func _apply_arson(gm, region, result):
	# Brandstiftung: Sperrt Region für kurze Zeit oder beschädigt Rigs
	# Hier: Region Lock
	gm.regions[region]["block_timer"] = 6 # 6 Monate Sperre (simuliert)
	result.message = "ERFOLG: Brandstiftung in " + region + ".\nProduktion gestoppt für 6 Monate."
	result.damage_cost = 500000

func _apply_tank_destruction(gm, region, result):
	var cap = gm.tank_capacity.get(region, 0)
	if cap <= 0:
		result.success = false
		result.message = "Keine Tanks in " + region + " vorhanden."
		return

	var dmg_percent = randf_range(0.2, 0.5)
	var lost_cap = int(cap * dmg_percent)
	var stored = gm.oil_stored.get(region, 0.0)
	
	var new_cap = max(0, cap - lost_cap)
	
	var oil_burned = 0
	if stored > new_cap:
		oil_burned = stored - new_cap
		stored = new_cap
	
	var direct_fire_loss = int(stored * 0.1) # 10% des Restbestands verbrennt
	stored -= direct_fire_loss
	oil_burned += direct_fire_loss
	
	gm.tank_capacity[region] = new_cap
	gm.oil_stored[region] = max(0, stored)
	
	result.message += "DETONATION: Tanklager in " + region + " erschüttert!\n"
	result.message += "Kapazität verloren: -" + str(lost_cap) + " bbl\n"
	result.message += "Vernichtetes Öl: " + str(oil_burned) + " bbl"
	result.damage_cost = int(lost_cap * 4.5) # Höhere Schadensbewertung

func _apply_theft(gm, region, result, is_player_attacker, data):
	var stored = gm.oil_stored.get(region, 0.0)
	if stored < 1000:
		result.success = false
		result.message += "Lagerbestände in " + region + " zu gering für einen lohnenswerten Diebstahl."
		return
		
	var steal_percent = 0.1 # Fallback
	if data.has("steal_percentages") and typeof(data["steal_percentages"]) == TYPE_ARRAY:
		steal_percent = data["steal_percentages"].pick_random()
		
	var stolen = int(stored * steal_percent)
	gm.oil_stored[region] -= stolen
	result.stolen_amount = stolen
	
	var black_market_price = gm.oil_price * 0.6 # Hehlerware ist billiger
	var profit = int(stolen * black_market_price)
	
	if is_player_attacker:
		gm.cash += profit
		gm.book_transaction("Global", profit, "Black Ops")
		result.message = "DIEBSTAHL: " + str(stolen) + " bbl entwendet.\nSchwarzmarkt-Erlös: +$" + str(profit)
	else:
		result.message = "DIEBSTAHL: Unbekannte haben " + str(stolen) + " bbl aus " + region + " entwendet."
		result.damage_cost = int(stolen * gm.oil_price)

func _apply_strike(gm, region, result):
	gm.regions[region]["block_timer"] = 3
	result.message = "STREIK: Gewerkschaften in " + region + " legen Arbeit nieder (3 Monate)."
