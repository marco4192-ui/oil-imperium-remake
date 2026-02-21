extends Node
# Statische Datenbank für Spielinhalte und Konfigurationen.
# ENTHÄLT: Regionen, Büros, Tech, Firmen (KI), Sabotage-Optionen

const REGION_LAYOUTS = {
	"Texas": ["__LL__","__LL__","__LLLL","_LLLLL","_LLLLL","___LL_","___LL_"],
	"Alaska": ["_WLLW","_L___","_L___","WWL__","WLLLL","_WLWW","_WL__"],
	"Nordsee": ["__WW_","__WW_","_WWWW","_WWWW","_WWWW","WWWWW","_WWWW"],
	"Saudi-Arabien": ["__LLW","_LLLW","_LLLL","__LLL","__LLL"],
	"Sibirien": ["__LLL_","_LLLLL","LLL_LL","LLL___"],
	"Nigeria": ["LLLLLL","LLLLLL","WWLLWW","WWLLWW"],
	"Venezuela": ["__WWWWW_","WWL____L","WWL__LL","______LL","___LLLLL"],
	"Indonesien": ["___WWW","LWWLLW","LWLLLW","LW__WL","LWL_WL","LLWWWL"],
	"Brasilien": ["__LWW","___WW","__LWW","__LWW","__LWW","_WWWWW","WWWWWW"],
	"Libyen": ["_LLLL_","_LLLL_","LLLLLL","LLLLLL"],
	"Mexiko": ["__LWWW__","___LWWW_","W___LLL_","WWWL____"]
}

const OFFICE_DATA = {
	0: { "name": "Büro Alternativ", "bg_path": "res://assets/offices/BüroAlternative.png", "computer_pos": Vector2(803, 438), "computer_size": Vector2(185, 130), "map_pos": Vector2(61, 195), "map_size": Vector2(504, 305), "calendar_pos": Vector2(1675, 238), "calendar_size": Vector2(183, 86), "newspaper_pos": Vector2(1510, 530), "newspaper_size": Vector2(125, 88), "briefcase_pos": Vector2(1354, 449), "briefcase_size": Vector2(143, 101), "drawer_pos": Vector2(1047, 624), "drawer_size": Vector2(185, 253), "phone_pos": Vector2(1172, 527), "phone_size": Vector2(126, 75), "endmonth_pos": Vector2(20, 17), "endmonth_size": Vector2(237, 66) },
	1: { "name": "Büro klassisch", "bg_path": "res://assets/offices/BüroClassic.png", "computer_pos": Vector2(797, 303), "computer_size": Vector2(275, 239), "map_pos": Vector2(29, 69), "map_size": Vector2(708, 329), "calendar_pos": Vector2(1671, 139), "calendar_size": Vector2(151, 206), "newspaper_pos": Vector2(1519, 599), "newspaper_size": Vector2(243, 88), "briefcase_pos": Vector2(1727, 470), "briefcase_size": Vector2(190, 159), "drawer_pos": Vector2(488, 753), "drawer_size": Vector2(236, 206), "phone_pos": Vector2(360, 583), "phone_size": Vector2(165, 126), "endmonth_pos": Vector2(20, 17), "endmonth_size": Vector2(237, 66) },
	2: { "name": "Büro Hightech", "bg_path": "res://assets/offices/BüroHightech.png", "computer_pos": Vector2(1196, 477), "computer_size": Vector2(361, 130), "map_pos": Vector2(20, 84), "map_size": Vector2(897, 359), "calendar_pos": Vector2(1643, 240), "calendar_size": Vector2(239, 105), "newspaper_pos": Vector2(582, 610), "newspaper_size": Vector2(168, 39), "briefcase_pos": Vector2(488, 496), "briefcase_size": Vector2(154, 103), "drawer_pos": Vector2(116, 657), "drawer_size": Vector2(238, 160), "phone_pos": Vector2(1087, 544), "phone_size": Vector2(102, 59), "endmonth_pos": Vector2(20, 17), "endmonth_size": Vector2(237, 66) },
	3: { "name": "Büro Hippie", "bg_path": "res://assets/offices/BüroHippie.png", "computer_pos": Vector2(278, 434), "computer_size": Vector2(169, 138), "map_pos": Vector2(1630, 152), "map_size": Vector2(279, 239), "calendar_pos": Vector2(881, 244), "calendar_size": Vector2(161, 95), "newspaper_pos": Vector2(1311, 518), "newspaper_size": Vector2(191, 68), "briefcase_pos": Vector2(1453, 712), "briefcase_size": Vector2(117, 160), "drawer_pos": Vector2(420, 571), "drawer_size": Vector2(219, 145), "phone_pos": Vector2(975, 476), "phone_size": Vector2(86, 53), "endmonth_pos": Vector2(20, 17), "endmonth_size": Vector2(237, 66) }
}

const AVAILABLE_HQS = [
	{ "name": "Houston (USA)", "home_region": "Texas", "skyline_path": "res://assets/skylines/hq_houston.png" },
	{ "name": "Riad (SAU)", "home_region": "Saudi-Arabien", "skyline_path": "res://assets/skylines/hq_riad.png" },
	{ "name": "Aberdeen (UK)", "home_region": "Nordsee", "skyline_path": "res://assets/skylines/hq_aberdeen.png" },
	{ "name": "Caracas (VEN)", "home_region": "Venezuela", "skyline_path": "res://assets/skylines/hq_caracas.png" },
	{ "name": "Lagos (NGA)", "home_region": "Nigeria", "skyline_path": "res://assets/skylines/hq_lagos.png" },
	{ "name": "Jakarta (IDN)", "home_region": "Indonesien", "skyline_path": "res://assets/skylines/hq_jakarta.png" },
	{ "name": "Rio de Janeiro (BRA)", "home_region": "Brasilien", "skyline_path": "res://assets/skylines/hq_rio.png" },
	{ "name": "Tripolis (LBY)", "home_region": "Libyen", "skyline_path": "res://assets/skylines/hq_tripolis.png" },
	{ "name": "Anchorage (USA)", "home_region": "Alaska", "skyline_path": "res://assets/skylines/hq_anchorage.png" },
	{ "name": "Tjumen (RUS)", "home_region": "Sibirien", "skyline_path": "res://assets/skylines/hq_tjumen.png" },
	{ "name": "Veracruz (MEX)", "home_region": "Mexiko", "skyline_path": "res://assets/skylines/hq_veracruz.png" }
]

const FACILITIES_TEMPLATE = {
	"lab": { "name": "Forschungslabor", "desc": "Grundlagenforschung.", "cost": 500000, "maintenance": 100.0, "built": false },
	"drill_ground": { "name": "Bohr-Testgelände", "desc": "Crew-Training & Bohrköpfe.", "cost": 800000, "maintenance": 150.0, "built": false },
	"workshop": { "name": "Ingenieurs-Werkstatt", "desc": "Pumpen & Sicherheit.", "cost": 600000, "maintenance": 120.0, "built": false },
	"test_site": { "name": "Belastungs-Testgelände", "desc": "Extreme Umweltbedingungen.", "cost": 1200000, "maintenance": 300.0, "built": false }
}

const TECH_DATABASE = {
	"tech_seismic_2d": { "name": "2D Seismik", "desc": "Bodenscans.", "research_cost": 50000, "hardware_cost": 100000, "research_time": 30, "year": 1972, "facility_req": "lab", "effect": "survey_accuracy_small", "req_tech": [] },
	"tech_seismic_3d": { "name": "3D Seismik", "desc": "3D Modelle.", "research_cost": 250000, "hardware_cost": 500000, "research_time": 90, "year": 1980, "facility_req": "lab", "effect": "survey_accuracy_medium", "req_tech": ["tech_seismic_2d"] },
	"tech_satellite": { "name": "Satelliten-Scan", "desc": "Hightech Scan.", "research_cost": 1500000, "hardware_cost": 3000000, "research_time": 180, "year": 1990, "facility_req": "lab", "effect": "survey_accuracy_high", "req_tech": ["tech_seismic_3d"] },
	"tech_diamond_bits": { "name": "Diamant-Bohrkronen", "desc": "Schneller bohren.", "research_cost": 40000, "hardware_cost": 60000, "research_time": 45, "year": 1973, "facility_req": "drill_ground", "effect": "drill_speed_small", "req_tech": [] },
	"tech_top_drive": { "name": "Top-Drive", "desc": "Effizienter Antrieb.", "research_cost": 150000, "hardware_cost": 300000, "research_time": 60, "year": 1982, "facility_req": "drill_ground", "effect": "drill_speed_medium", "req_tech": ["tech_diamond_bits"] },
	"tech_gas_lift": { "name": "Gas-Lift", "desc": "+10% Förderung.", "research_cost": 80000, "hardware_cost": 150000, "research_time": 60, "year": 1976, "facility_req": "workshop", "effect": "production_boost_small", "req_tech": [] },
	"tech_blowout_preventer": { "name": "Blowout Preventer", "desc": "Mehr Sicherheit.", "research_cost": 120000, "hardware_cost": 200000, "research_time": 50, "year": 1975, "facility_req": "workshop", "effect": "safety_boost", "req_tech": [] },
	"tech_esp_pumps": { "name": "ESP Pumpen", "desc": "+25% Förderung.", "research_cost": 500000, "hardware_cost": 800000, "research_time": 120, "year": 1982, "facility_req": "workshop", "effect": "production_boost_medium", "req_tech": ["tech_gas_lift"] },
	"tech_fracking": { "name": "Fracking", "desc": "Massiver Boost.", "research_cost": 5000000, "hardware_cost": 10000000, "research_time": 360, "year": 1998, "facility_req": "workshop", "effect": "production_boost_high", "req_tech": ["tech_esp_pumps"] },
	"tech_winterization": { "name": "Kälteschutz", "desc": "Erlaubt Eis-Regionen.", "research_cost": 300000, "hardware_cost": 100000, "research_time": 120, "year": 1975, "facility_req": "test_site", "effect": "unlock_biome_ice", "req_tech": [] },
	"tech_deepwater": { "name": "Tiefsee-Technik", "desc": "Erlaubt Tiefsee.", "research_cost": 1000000, "hardware_cost": 2000000, "research_time": 180, "year": 1985, "facility_req": "test_site", "effect": "unlock_biome_deepsea", "req_tech": [] }
}

const ERA_COLORS = { 
	0: { "bg": Color(0, 0, 0), "text": Color("33ff00"), "button": Color(0.1, 0.1, 0.1) }, 
	1: { "bg": Color(0, 0, 0.6), "text": Color(1, 1, 1), "button": Color(0.4, 0.4, 0.8) }, 
	2: { "bg": Color(0.8, 0.8, 0.8), "text": Color(0, 0, 0), "button": Color(0.7, 0.7, 0.7) } 
}

const ERA_UPGRADE_COST = { 1: 5000000, 2: 15000000 }

# --- NEU: FIRMEN POOL (für KI Gegner) ---
const COMPANIES = [
	{ "name": "Apex Drilling", "logo": "res://assets/logos/ApexDrilling.png" },
	{ "name": "AquaTerra Oil", "logo": "res://assets/logos/AquaTerraOil.png" },
	{ "name": "Aurora Petroleum", "logo": "res://assets/logos/AuroraPetroleum.png" },
	{ "name": "Core Energy", "logo": "res://assets/logos/CoreEnergy.png" },
	{ "name": "Fortress Drilling", "logo": "res://assets/logos/FortressDrilling.png" },
	{ "name": "GeoCore Drilling", "logo": "res://assets/logos/GeoCoreDrilling.png" },
	{ "name": "GeoSource Energy", "logo": "res://assets/logos/GeoSourceEnergy.png" },
	{ "name": "Helix Energy", "logo": "res://assets/logos/HelixEnergy.png" },
	{ "name": "Horizon Petroleum", "logo": "res://assets/logos/HorizonPetroleum.png" },
	{ "name": "Inferno Drilling", "logo": "res://assets/logos/InfernoDrilling.png" },
	{ "name": "Neptune Oil", "logo": "res://assets/logos/NeptuneOil.png" },
	{ "name": "Oceanic Energy", "logo": "res://assets/logos/OceanicEnergy.png" },
	{ "name": "Orion Fuels", "logo": "res://assets/logos/OrionFuels.png" },
	{ "name": "Phoenix Petrol", "logo": "res://assets/logos/PhoenixPetrol.png" },
	{ "name": "Solaris Fuels", "logo": "res://assets/logos/SolarisFuels.png" },
	{ "name": "Stellar Petroleum", "logo": "res://assets/logos/StellarPetroleum.png" },
	{ "name": "Summit Resources", "logo": "res://assets/logos/SummitResources.png" },
	{ "name": "TerraFlow Energy", "logo": "res://assets/logos/TerraFlowEnergy.png" },
	{ "name": "Titan Fuels", "logo": "res://assets/logos/TitanFuels.png" },
	{ "name": "Vulcan Oil", "logo": "res://assets/logos/VulcanOil.png" }
]

# --- SABOTAGE DATEN & KONSEQUENZEN ---
# Preise wurden massiv erhöht (Faktor 4-5), damit Sabotage ein echtes Luxus-Risiko ist.
const SABOTAGE_OPTIONS = {
	"arson": { 
		"name": "Brandstiftung", 
		"desc": "Setzt ein aktives Rig in Brand. Lege den Betrieb lahm.",
		"cost": 2500000, 
		"base_success_chance": 0.60,
		"detection_chance": 0.45,
		"fine_amount": 3500000, 
		"lock_duration_months": 6 
	},
	"destroy_tank": { 
		"name": "Tank-Sprengung", 
		"desc": "Zerstört Lagerkapazität und verbrennt Reserven.",
		"cost": 1200000, 
		"base_success_chance": 0.50,
		"detection_chance": 0.55,
		"fine_amount": 2000000, 
		"damage_factor": 0.3 
	},
	"theft": { 
		"name": "Öl-Diebstahl", 
		"desc": "Leitet Öl aus Tanks um. Profitabel aber riskant.",
		"cost": 400000, 
		"base_success_chance": 0.70,
		"detection_chance": 0.25,
		"fine_amount": 800000, 
		"steal_percentages": [0.05, 0.10, 0.15] 
	},
	"strike_incite": { 
		"name": "Streik anstiften", 
		"desc": "Besticht Gewerkschafter für Arbeitsniederlegung.",
		"cost": 750000, 
		"base_success_chance": 0.80, 
		"detection_chance": 0.15, 
		"fine_amount": 1000000, 
		"lock_duration_months": 3 
	}
}
