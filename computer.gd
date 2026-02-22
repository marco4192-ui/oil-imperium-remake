extends Control

# --- IMPORTS ---
const GameData = preload("res://GameData.gd")

# --- HAUPTMENÜS ---
@onready var oil_field_menu = $ControlPanel/OilFieldMenu
@onready var tank_menu = $ControlPanel/TankMenu
@onready var sales_menu = $ControlPanel/SalesMenu
@onready var stats_menu = $ControlPanel/StatsMenu 
@onready var research_menu = $ControlPanel/ResearchMenu

@onready var lbl_money = $MoneyLabel if has_node("MoneyLabel") else null

# --- STATISTIK UI (FIX: Verknüpfung mit existierenden Nodes) ---
var stats_region_idx = 0
var stats_region_keys = ["Global"] 

# Diese Nodes existieren bereits in der Szene, wir müssen sie referenzieren!
@onready var lbl_stats_region = $ControlPanel/StatsMenu/ReportContainer/lbl_stats_region
@onready var box_income = $ControlPanel/StatsMenu/ReportContainer/box_income
@onready var box_expense = $ControlPanel/StatsMenu/ReportContainer/box_expense
@onready var lbl_total_profit = $ControlPanel/StatsMenu/ReportContainer/lbl_total_profit

# Navigations-Buttons für Regionen (Die < und > Buttons im ReportContainer)
@onready var btn_stats_prev = $"ControlPanel/StatsMenu/ReportContainer/<"
@onready var btn_stats_next = $"ControlPanel/StatsMenu/ReportContainer/>"

# --- STATISTIK UI REFERENZEN ---
@onready var report_container = $ControlPanel/StatsMenu/ReportContainer
@onready var graph_container = $ControlPanel/StatsMenu/GraphContainer
@onready var graph_render_area = $ControlPanel/StatsMenu/GraphContainer/GraphRenderArea

# Mode Buttons
@onready var btn_show_current = $ControlPanel/StatsMenu/TopBar/BtnShowCurrent
@onready var btn_show_history = $ControlPanel/StatsMenu/TopBar/BtnShowHistory

# Graph Toggles
@onready var check_revenue = $ControlPanel/StatsMenu/GraphContainer/Toggles/CheckRevenue
@onready var check_expenses = $ControlPanel/StatsMenu/GraphContainer/Toggles/CheckExpenses
@onready var check_profit = $ControlPanel/StatsMenu/GraphContainer/Toggles/CheckProfit
@onready var check_cash = $ControlPanel/StatsMenu/GraphContainer/Toggles/CheckCash

# Preload für den Graph
const GraphDisplayScene = preload("res://graph_display.gd") 
var GraphScript = preload("res://graph_display.gd")

# TERMINAL COLORS (70s Style)
const COL_TERM_MAIN = Color(0.2, 1.0, 0.2) # Helles Phosphor-Grün
const COL_TERM_DIM = Color(0.15, 0.7, 0.15) # Etwas dunkleres Grün für Details

# --- CAMPUS / RESEARCH UI ---
@onready var campus_overview = $ControlPanel/ResearchMenu/CampusOverview
@onready var facility_details = $ControlPanel/ResearchMenu/FacilityDetails
@onready var btn_lab = $ControlPanel/ResearchMenu/CampusOverview/BtnLab
@onready var btn_drill_ground = $ControlPanel/ResearchMenu/CampusOverview/BtnDrillGround
@onready var btn_workshop = $ControlPanel/ResearchMenu/CampusOverview/BtnWorkshop
@onready var btn_test_site = $ControlPanel/ResearchMenu/CampusOverview/BtnTestSite

@onready var facility_title = $ControlPanel/ResearchMenu/FacilityDetails/FacilityTitle
@onready var btn_back_campus = $ControlPanel/ResearchMenu/FacilityDetails/BtnBackToCampus
@onready var buy_container = $ControlPanel/ResearchMenu/FacilityDetails/BuyContainer
@onready var cost_label = $ControlPanel/ResearchMenu/FacilityDetails/BuyContainer/CostLabel
@onready var btn_build_facility = $ControlPanel/ResearchMenu/FacilityDetails/BuyContainer/BtnBuildFacility
@onready var action_container = $ControlPanel/ResearchMenu/FacilityDetails/ActionContainer
@onready var tech_list = $ControlPanel/ResearchMenu/FacilityDetails/ActionContainer/TechList
@onready var btn_practice_drill = $ControlPanel/ResearchMenu/FacilityDetails/ActionContainer/BtnPractice

# --- TANK & SALES UI REFERENZEN ---
@onready var tank_status_label2 = $ControlPanel/TankMenu/StatusLabel2 
@onready var btn_sell_tanks = $ControlPanel/TankMenu/VBoxContainer/BtnSellTanks
@onready var btn_buy_small = $ControlPanel/TankMenu/VBoxContainer/BtnBuySmall
@onready var btn_buy_medium = $ControlPanel/TankMenu/VBoxContainer/BtnBuyMedium
@onready var btn_buy_large = $ControlPanel/TankMenu/VBoxContainer/BtnBuyLarge

@onready var sales_tabs = $ControlPanel/SalesMenu/TabContainer
@onready var tab_spot = $ControlPanel/SalesMenu/TabContainer/"Bestand & Spotmarkt"
@onready var price_label = tab_spot.get_node("PriceLabel")

@onready var stock_label = tab_spot.get_node_or_null("HSeperator/RegionVSeperator/StockLabel")
@onready var stock_label2 = tab_spot.get_node_or_null("HSeperator/RegionVSeperator/StockLabel2") 
# REFERENZ ZU DEN REGIONS-BUTTONS FÜR VERKAUF
@onready var sales_region_container = tab_spot.get_node("HSeperator/RegionVSeperator")

@onready var lbl_selected_amount = tab_spot.get_node("HSeperator/SellVSeperator/LabelSelectedAmount")
@onready var sales_slider = tab_spot.get_node("HSeperator/SellVSeperator/SalesSlider")
@onready var btn_sell_action = tab_spot.get_node("HSeperator/SellVSeperator/BtnSellAll")

# --- CONTRACT UI REFERENZEN ---
@onready var contracts_active_list = $ControlPanel/SalesMenu/TabContainer/Contracts/ActiveContractsContainer
@onready var contracts_offer_list = $ControlPanel/SalesMenu/TabContainer/Contracts/OfferContractsContainer

@onready var futures_active_list = $ControlPanel/SalesMenu/TabContainer.get_node_or_null("Futures/ActiveFuturesContainer")
@onready var futures_offer_list = $ControlPanel/SalesMenu/TabContainer.get_node_or_null("Futures/OfferFuturesContainer")

# --- SHADER REFERENZ ---
@onready var crt_layer = $CanvasLayer
@onready var crt_rect = $CanvasLayer/ColorRect

# --- LOKALE VARIABLEN ---
var current_sales_region = ""
var current_tank_region = ""
var current_sale_amount = 0.0
var selected_facility_id = ""

func _ready():
		_init_shader()
		
		apply_era_theme()
		connect_research_buttons()
		update_map_buttons()
		update_tank_buttons_visibility()
		update_tank_buy_buttons()
		
		if sales_slider:
				apply_retro_slider_style(sales_slider)
				if not sales_slider.value_changed.is_connected(_on_sales_slider_changed):
						sales_slider.value_changed.connect(_on_sales_slider_changed)
		
		# Statistik Buttons werden nun durch die Szene verbunden (Methodennamen angepasst)
		# if btn_show_current: btn_show_current.pressed.connect(_on_btn_show_current_pressed)
		# if btn_show_history: btn_show_history.pressed.connect(_on_btn_show_history_pressed)
		
		# NEU: Navigations-Buttons für Regionen verbinden
		if btn_stats_prev: 
				if btn_stats_prev.pressed.is_connected(_on__pressed): btn_stats_prev.pressed.disconnect(_on__pressed)
				btn_stats_prev.pressed.connect(_on_stats_prev_region)
		
		if btn_stats_next: 
				if btn_stats_next.pressed.is_connected(_on__pressed): btn_stats_next.pressed.disconnect(_on__pressed)
				btn_stats_next.pressed.connect(_on_stats_next_region)
		
		# Toggle Buttons verbinden
		if check_revenue: check_revenue.toggled.connect(_on_graph_toggles_changed)
		if check_expenses: check_expenses.toggled.connect(_on_graph_toggles_changed)
		if check_profit: check_profit.toggled.connect(_on_graph_toggles_changed)
		if check_cash: check_cash.toggled.connect(_on_graph_toggles_changed)

		# Standard-Ansicht
		_on_btn_show_current_pressed()
		
		GameManager.data_updated.connect(refresh_current_view)

func _init_shader():
		if crt_layer:
				crt_layer.visible = true
				if not crt_layer.has_node("CRTCopy"):
						var bbc = BackBufferCopy.new()
						bbc.name = "CRTCopy"
						bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
						bbc.rect = Rect2(0, 0, 1920, 1080)
						crt_layer.add_child(bbc)
						if crt_rect:
								crt_layer.move_child(bbc, crt_rect.get_index())
		
		if crt_rect:
				crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				crt_rect.visible = true

func connect_research_buttons():
		if btn_lab: btn_lab.pressed.connect(open_facility_details.bind("lab"))
		if btn_drill_ground: btn_drill_ground.pressed.connect(open_facility_details.bind("drill_ground"))
		if btn_workshop: btn_workshop.pressed.connect(open_facility_details.bind("workshop"))
		if btn_test_site: btn_test_site.pressed.connect(open_facility_details.bind("test_site"))
		
		if btn_back_campus and not btn_back_campus.pressed.is_connected(_on_btn_back_to_campus_pressed):
				btn_back_campus.pressed.connect(_on_btn_back_to_campus_pressed)
						
		if btn_build_facility and not btn_build_facility.pressed.is_connected(_on_btn_build_facility_pressed):
				btn_build_facility.pressed.connect(_on_btn_build_facility_pressed)
				
		if btn_practice_drill and not btn_practice_drill.pressed.is_connected(_on_btn_practice_drill_pressed):
				btn_practice_drill.pressed.connect(_on_btn_practice_drill_pressed)

# --- NEUES CONTRACT UI SYSTEM ---
func update_contracts_view():
		# 1. Supply Contracts (Aktiv)
		if contracts_active_list:
				for c in contracts_active_list.get_children(): c.queue_free()
				if GameManager.active_supply_contracts.is_empty():
						var lbl = Label.new(); lbl.text = "Keine laufenden Verträge."; contracts_active_list.add_child(lbl)
				else:
						for c in GameManager.active_supply_contracts:
								var lbl = Label.new()
								lbl.text = "► " + c["region"] + " | " + str(c["months_left"]) + " Mo. übrig | " + str(c["volume_monthly"]) + " bbl/Mo"
								lbl.modulate = Color.GREEN
								contracts_active_list.add_child(lbl)
		
		# 2. Supply Contracts (Angebote)
		if contracts_offer_list:
				for c in contracts_offer_list.get_children(): c.queue_free()
				if GameManager.available_contract_offers.is_empty():
						var lbl = Label.new(); lbl.text = "Derzeit keine Angebote."; contracts_offer_list.add_child(lbl)
				else:
						for i in range(GameManager.available_contract_offers.size()):
								var offer = GameManager.available_contract_offers[i]
								create_offer_accordion_item(contracts_offer_list, offer, i, false)

		# 3. Futures (Aktiv)
		if futures_active_list:
				for c in futures_active_list.get_children(): c.queue_free()
				if GameManager.active_futures.is_empty():
						var lbl = Label.new(); lbl.text = "Keine laufenden Futures."; futures_active_list.add_child(lbl)
				else:
						for f in GameManager.active_futures:
								var lbl = Label.new()
								lbl.text = "► " + f["region"] + " | Fällig: " + str(f["due_month"]) + "/" + str(f["due_year"]) + " | " + str(f["volume"]) + " bbl"
								lbl.modulate = Color.CYAN
								futures_active_list.add_child(lbl)

		# 4. Futures (Angebote)
		if futures_offer_list:
				for c in futures_offer_list.get_children(): c.queue_free()
				if GameManager.available_future_offers.is_empty():
						var lbl = Label.new(); lbl.text = "Derzeit keine Future-Angebote."; futures_offer_list.add_child(lbl)
				else:
						for i in range(GameManager.available_future_offers.size()):
								var offer = GameManager.available_future_offers[i]
								create_offer_accordion_item(futures_offer_list, offer, i, true)

func create_offer_accordion_item(parent, offer, index, is_future):
		var item_vbox = VBoxContainer.new()
		parent.add_child(item_vbox)
		item_vbox.add_theme_constant_override("separation", 0) 

		var btn_header = Button.new()
		var region = offer["region"]
		var summary = ""
		
		if is_future:
				summary = "%s | Fällig: %02d/%d | %d bbl" % [region, offer["due_month"], offer["due_year"], offer["volume"]]
		else:
				summary = "%s | %d Monate | %d bbl/Mo" % [region, offer["months_total"], offer["volume_monthly"]]
		
		btn_header.text = "▼ " + summary
		btn_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_vbox.add_child(btn_header)

		var details_panel = PanelContainer.new()
		details_panel.visible = false 
		item_vbox.add_child(details_panel)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.15)
		style.content_margin_left = 10; style.content_margin_right = 10; style.content_margin_top = 10; style.content_margin_bottom = 10
		details_panel.add_theme_stylebox_override("panel", style)

		var details_vbox = VBoxContainer.new()
		details_panel.add_child(details_vbox)
		
		_add_detail_row(details_vbox, "Region:", region)
		
		if is_future:
				_add_detail_row(details_vbox, "Typ:", "Warentermin-Geschäft (Future)")
				_add_detail_row(details_vbox, "Lieferdatum:", "%02d/%d (in %d Monaten)" % [offer["due_month"], offer["due_year"], offer["months_wait"]])
				_add_detail_row(details_vbox, "Liefermenge:", str(offer["volume"]) + " bbl (Einmalig)")
		else:
				_add_detail_row(details_vbox, "Typ:", "Liefervertrag (Supply)")
				_add_detail_row(details_vbox, "Laufzeit:", str(offer["months_total"]) + " Monate")
				_add_detail_row(details_vbox, "Menge:", str(offer["volume_monthly"]) + " bbl pro Monat")
		
		_add_detail_row(details_vbox, "Preis:", "$" + str(offer["price_per_bbl"]) + " / bbl")
		
		var total_val = 0
		if is_future: total_val = offer["volume"] * offer["price_per_bbl"]
		else: total_val = offer["volume_monthly"] * offer["price_per_bbl"] * offer["months_total"]
		
		_add_detail_row(details_vbox, "Gesamtwert:", "$" + _fmt_money_str(total_val), COL_TERM_MAIN)
		_add_detail_row(details_vbox, "Strafe (bei Ausfall):", "$" + _fmt_money_str(offer["penalty"]), COL_TERM_MAIN)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		details_vbox.add_child(spacer)

		var btn_accept = Button.new()
		btn_accept.text = "VERTRAG UNTERZEICHNEN"
		btn_accept.modulate = COL_TERM_MAIN 
		btn_accept.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		if is_future:
				btn_accept.pressed.connect(_on_sign_future.bind(index))
		else:
				btn_accept.pressed.connect(_on_sign_contract.bind(index))
				
		details_vbox.add_child(btn_accept)

		btn_header.pressed.connect(func(): 
				details_panel.visible = !details_panel.visible
				btn_header.text = ("▲ " if details_panel.visible else "▼ ") + summary
		)

func _add_detail_row(parent, label, value, val_color=COL_TERM_MAIN):
		var hbox = HBoxContainer.new()
		parent.add_child(hbox)
		var l = Label.new(); l.text = label; l.modulate = COL_TERM_DIM; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(l)
		var v = Label.new(); v.text = value; v.modulate = val_color
		hbox.add_child(v)

func _fmt_money_str(v):
		var s = str(int(v))
		var res = ""
		var counter = 0
		for i in range(s.length() - 1, -1, -1):
				res = s[i] + res
				counter += 1
				if counter % 3 == 0 and i > 0:
						res = "." + res
		return res

func _on_sign_contract(index):
		GameManager.sign_supply_contract(index)
		update_contracts_view() 

func _on_sign_future(index):
		GameManager.sign_future_contract(index)
		update_contracts_view()

# --- STATISTIK UI FUNKTIONEN ---

func _on_stats_prev_region():
		stats_region_idx = (stats_region_idx - 1 + stats_region_keys.size()) % stats_region_keys.size()
		update_stats_view()

func _on_stats_next_region():
		stats_region_idx = (stats_region_idx + 1) % stats_region_keys.size()
		update_stats_view()

func update_stats_view():
		if not stats_menu or not stats_menu.visible: return
		
		# Hier trat der Fehler auf (null check hinzugefügt)
		if lbl_stats_region == null or box_income == null or box_expense == null:
				return
		
		var region_key = stats_region_keys[stats_region_idx]
		lbl_stats_region.text = "REPORT: " + region_key.to_upper()
		
		for c in box_income.get_children(): c.queue_free()
		for c in box_expense.get_children(): c.queue_free()
		
		var data = GameManager.current_month_finance.get(region_key, null)
		if not data:
				lbl_total_profit.text = "Keine Daten."
				return
				
		var total_inc = 0.0
		var total_exp = 0.0
		
		for cat in data["revenue"]:
				var val = data["revenue"][cat]
				add_stat_row(box_income, cat, val, COL_TERM_MAIN)
				total_inc += val
				
		for cat in data["expenses"]:
				var val = data["expenses"][cat]
				add_stat_row(box_expense, cat, val, COL_TERM_MAIN)
				total_exp += val
				
		add_stat_row(box_income, "TOTAL", total_inc, COL_TERM_MAIN, true)
		add_stat_row(box_expense, "TOTAL", total_exp, COL_TERM_MAIN, true)
		
		var profit = total_inc - total_exp
		var sign_str = "+" if profit >= 0 else ""
		
		lbl_total_profit.text = "ERGEBNIS (MONAT): " + sign_str + "$" + _fmt_money_str(profit)
		lbl_total_profit.modulate = COL_TERM_MAIN

func add_stat_row(parent, label, value, color, is_bold=false):
		var hbox = HBoxContainer.new()
		parent.add_child(hbox)
		
		var l = Label.new()
		l.text = label
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 22)
		
		if is_bold:
				l.modulate = COL_TERM_MAIN # Hell
		else:
				l.modulate = COL_TERM_DIM  # Dunkler
				
		hbox.add_child(l)
		
		var v = Label.new()
		v.text = "$" + _fmt_money_str(value)
		v.modulate = color
		v.add_theme_font_size_override("font_size", 22)
		
		hbox.add_child(v)

# --- STANDARD FUNKTIONEN ---
func hide_all_menus():
		if oil_field_menu: oil_field_menu.visible = false
		if tank_menu: tank_menu.visible = false
		if sales_menu: sales_menu.visible = false
		if stats_menu: stats_menu.visible = false
		if research_menu: research_menu.visible = false

func switch_menu(target_menu):
		hide_all_menus()
		if target_menu: target_menu.visible = true
		refresh_current_view()

func _on_btn_oil_fields_pressed(): switch_menu(oil_field_menu)
func _on_btn_tanks_pressed(): 
		switch_menu(tank_menu)
		update_tank_buy_buttons()
		if tank_status_label2: tank_status_label2.text = "Status: WÄHLE REGION"
		current_tank_region = ""
		update_tank_buttons_visibility()

func _on_btn_oil_pressed(): 
		switch_menu(sales_menu)
		current_sales_region = ""
		update_sales_buttons_visibility()
		
		if stock_label2: 
				stock_label2.text = "Bestand: WÄHLE REGION"
		elif stock_label: 
				stock_label.text = "Wähle Region..."
				
		if btn_sell_action: btn_sell_action.disabled = true
		update_sales_view()

func _on_btn_stats_pressed(): 
		switch_menu(stats_menu)
		update_stats_view()

func _on_btn_research_pressed(): 
		switch_menu(research_menu)
		_on_btn_back_to_campus_pressed()

func _on_btn_exit_pressed(): get_tree().change_scene_to_file("res://Office.tscn")

func refresh_current_view():
		update_money_display()
		if sales_menu and sales_menu.visible: update_sales_view()
		if tank_menu and tank_menu.visible:
				update_tank_buy_buttons()
				if current_tank_region != "": update_tank_view(current_tank_region)
		if stats_menu and stats_menu.visible: update_stats_view()
		if research_menu and research_menu.visible:
				if facility_details.visible: open_facility_details(selected_facility_id)
				else: update_campus_buttons()
		update_map_buttons()
		update_tank_buttons_visibility()

func update_money_display():
		if lbl_money: lbl_money.text = "$ " + ("%.2f" % GameManager.cash)

# --- RESEARCH FIX ---
func _on_btn_back_to_campus_pressed():
		facility_details.visible = false
		campus_overview.visible = true
		update_campus_buttons()

func update_campus_buttons():
		set_facility_btn_text(btn_lab, "lab")
		set_facility_btn_text(btn_drill_ground, "drill_ground")
		set_facility_btn_text(btn_workshop, "workshop")
		set_facility_btn_text(btn_test_site, "test_site")

func set_facility_btn_text(btn, id):
		if not btn: return
		var fac = GameManager.facilities[id]
		var status = "AKTIV" if fac["built"] else "NICHT GEBAUT"
		btn.text = fac["name"] + "\n[" + status + "]"

func open_facility_details(fac_id):
		selected_facility_id = fac_id
		campus_overview.visible = false
		facility_details.visible = true
		
		if not GameManager.facilities.has(fac_id): return
		var fac = GameManager.facilities[fac_id]
		facility_title.text = "EINRICHTUNG: " + fac["name"]
		
		if fac["built"]:
				buy_container.visible = false
				action_container.visible = true
				if fac_id == "drill_ground" and btn_practice_drill: btn_practice_drill.visible = true
				elif btn_practice_drill: btn_practice_drill.visible = false
				update_tech_list()
		else:
				buy_container.visible = true
				action_container.visible = false
				cost_label.text = "KOSTEN: $" + str(int(fac["cost"] * GameManager.inflation_rate)) + "\n" + fac["desc"]
				btn_build_facility.text = "BAUEN"

func update_tech_list():
		if not tech_list: return
		for child in tech_list.get_children(): child.queue_free()
		
		# Get era-specific styling
		var current_era = GameManager.current_era
		var era_style = GameData.ERA_TECH_STYLES.get(current_era, GameData.ERA_TECH_STYLES[0])
		var era_multiplier = GameData.ERA_TECH_COST_MULTIPLIERS.get(current_era, 1.0)
		var show_icons = era_style.get("icon_visible", false)
		
		var db = GameManager.tech_database
		for tech_id in db:
				var tech = db[tech_id]
				if tech["facility_req"] != selected_facility_id: continue
				
				# Check era requirement
				var min_era = tech.get("min_era", 0)
				var era_locked = current_era < min_era
				
				# Create row container with era-appropriate styling
				var row = HBoxContainer.new()
				tech_list.add_child(row)
				
				# Era-based styling - 1970s: simple text, 1980s+: with borders/panels
				if current_era >= 1:
						# Add panel background for 1980s+
						var panel = PanelContainer.new()
						panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						var style = StyleBoxFlat.new()
						style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
						style.border_color = Color(0.3, 0.3, 0.3)
						style.border_width_all = 1
						if current_era >= 2:
								style.corner_radius_top_left = 4
								style.corner_radius_top_right = 4
								style.corner_radius_bottom_right = 4
								style.corner_radius_bottom_left = 4
						panel.add_theme_stylebox_override("panel", style)
						row.add_child(panel)
						
						var inner_hbox = HBoxContainer.new()
						panel.add_child(inner_hbox)
						
						var lbl = Label.new()
						lbl.text = tech["name"] + "\n(" + tech["desc"] + ")"
						lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						inner_hbox.add_child(lbl)
						
						var btn = Button.new()
						btn.custom_minimum_size = Vector2(140, 0)
						inner_hbox.add_child(btn)
						
						_setup_tech_button(btn, tech_id, tech, era_multiplier, era_locked, show_icons)
				else:
						# 1970s: Simple text-only display (no panels, no borders)
						var lbl = Label.new()
						lbl.text = tech["name"] + " - " + tech["desc"]
						lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						row.add_child(lbl)
						
						var btn = Button.new()
						btn.custom_minimum_size = Vector2(120, 0)
						row.add_child(btn)
						
						_setup_tech_button(btn, tech_id, tech, era_multiplier, era_locked, false)

func _setup_tech_button(btn, tech_id, tech, era_multiplier, era_locked, _show_icons):
		# Apply era-based cost calculation
		var research_cost = int(tech["research_cost"] * GameManager.inflation_rate * era_multiplier)
		var hardware_cost = int(tech["hardware_cost"] * GameManager.inflation_rate * era_multiplier)
		
		if tech_id in GameManager.unlocked_techs:
				btn.text = "AKTIV"
				btn.disabled = true
				btn.modulate = Color.GREEN
		elif tech_id in GameManager.researched_techs:
				btn.text = "KAUFEN\n$" + str(hardware_cost)
				btn.pressed.connect(_on_buy_hardware.bind(tech_id))
		elif tech_id == GameManager.current_research_id:
				btn.text = "FORSCHE...\n" + str(GameManager.current_research_days_left) + "d"
				btn.disabled = true
				btn.modulate = Color.YELLOW
		elif GameManager.current_research_id != "":
				btn.text = "WARTEN"
				btn.disabled = true
		elif era_locked:
				# Tech requires higher era
				var min_era = tech.get("min_era", 0)
				var era_names = {0: "1970s", 1: "1980s", 2: "1990s"}
				btn.text = "ÄRA " + era_names.get(min_era, "?") + "\nNÖTIG"
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5)
		else:
				var req_met = true
				for req in tech["req_tech"]:
						if not req in GameManager.researched_techs:
								req_met = false
								break
				if req_met and GameManager.date["year"] >= tech["year"]:
						btn.text = "FORSCHEN\n$" + str(research_cost)
						btn.pressed.connect(_on_start_research.bind(tech_id))
				else:
						btn.text = "LOCKED"
						btn.disabled = true

func _on_start_research(id):
		GameManager.start_research(id)
		update_tech_list()

func _on_buy_hardware(id):
		GameManager.buy_tech_hardware(id)
		update_tech_list()

func _on_btn_build_facility_pressed():
		if selected_facility_id == "": return
		var cost = GameManager.facilities[selected_facility_id]["cost"] * GameManager.inflation_rate
		if GameManager.cash >= cost:
				GameManager.build_facility(selected_facility_id)
				open_facility_details(selected_facility_id)
		else:
				FeedbackOverlay.show_msg("Zu wenig Geld!")

func _on_btn_practice_drill_pressed():
		GameManager.is_drilling_practice = true
		get_tree().change_scene_to_file("res://DrillingMiniGame.tscn")

# --- SALES/TANK/MAP REST ---
func update_sales_view():
		update_spot_market_view()
		update_contracts_view()

func update_spot_market_view():
		if price_label: price_label.text = "SPOT PREIS: $%.2f" % GameManager.oil_price
		if current_sales_region != "":
				var stored = GameManager.oil_stored.get(current_sales_region, 0)
				var cap = GameManager.tank_capacity.get(current_sales_region, 0)
				
				if stock_label2:
						stock_label2.text = "Lager %s: %d/%d" % [current_sales_region, stored, cap]
						if stock_label: stock_label.text = ""
				elif stock_label:
						stock_label.text = "Lager %s: %d/%d" % [current_sales_region, stored, cap]
						
				if sales_slider:
						sales_slider.max_value = stored
						sales_slider.value = current_sale_amount
						sales_slider.editable = (stored > 0)
				if btn_sell_action:
						btn_sell_action.disabled = (stored <= 0)
						if stored > 0: update_sales_calculation(sales_slider.value)
		else:
				if stock_label2: stock_label2.text = "Wähle Region..."
				elif stock_label: stock_label.text = "Wähle Region..."
				if btn_sell_action: btn_sell_action.disabled = true

func _on_sales_slider_changed(v):
		current_sale_amount = v
		update_sales_calculation(v)

func update_sales_calculation(v):
		if btn_sell_action:
				btn_sell_action.text = "VERKAUFEN ($%d)" % int(v * GameManager.oil_price)

func _on_btn_sell_all_pressed():
		if current_sales_region != "":
				GameManager.commit_sale(current_sales_region, current_sale_amount, current_sale_amount * GameManager.oil_price)
				update_sales_view()

func update_sales_buttons_visibility():
		if not sales_region_container: return
		
		for btn in sales_region_container.get_children():
				if btn is Button and btn.name.begins_with("BtnSell"):
						var region_name = btn.name.replace("BtnSell", "")
						if region_name == "Saudi": region_name = "Saudi-Arabien"
						
						if GameManager.regions.has(region_name):
								btn.visible = GameManager.regions[region_name].get("unlocked", false)
						else:
								btn.visible = false

func update_tank_buy_buttons():
		var cost_s = GameManager.get_tank_cost(500000)
		var cost_m = GameManager.get_tank_cost(1000000)
		var cost_l = GameManager.get_tank_cost(2500000)

		if btn_buy_small:
				btn_buy_small.text = "KLEIN (500k bbl)\n$%s" % _fmt_money_str(cost_s)
		if btn_buy_medium:
				btn_buy_medium.text = "MITTEL (1M bbl)\n$%s" % _fmt_money_str(cost_m)
		if btn_buy_large:
				btn_buy_large.text = "GROSS (2.5M bbl)\n$%s" % _fmt_money_str(cost_l)

func _on_btn_buy_small_pressed(): buy_tank(500000)
func _on_btn_buy_medium_pressed(): buy_tank(1000000)
func _on_btn_buy_large_pressed(): buy_tank(2500000)

func buy_tank(s):
		if current_tank_region != "":
				if GameManager.try_buy_tank(current_tank_region, s, 0):
						update_tank_view(current_tank_region)
						update_tank_buy_buttons()
				else:
						pass

func update_tank_view(r):
		current_tank_region = r
		var cap = GameManager.tank_capacity.get(r, 0)
		var stored = GameManager.oil_stored.get(r, 0)
		
		var is_unlocked = GameManager.regions[r].get("unlocked", false)
		
		if tank_status_label2:
				if is_unlocked:
						tank_status_label2.text = "REGION: %s\nKAPAZITÄT: %s bbl\nBESTAND: %s bbl" % [r, _fmt_money_str(cap), _fmt_money_str(stored)]
						tank_status_label2.modulate = Color.WHITE
				else:
						tank_status_label2.text = "REGION: %s\nSTATUS: GESPERRT\n(Keine Lizenz vorhanden)" % r
						tank_status_label2.modulate = Color.RED
						
		if btn_sell_tanks:
				btn_sell_tanks.disabled = (cap <= 0)
				btn_sell_tanks.text = "Tanks verkaufen" if cap > 0 else "Keine Tanks"
				
		if btn_buy_small: btn_buy_small.disabled = not is_unlocked
		if btn_buy_medium: btn_buy_medium.disabled = not is_unlocked
		if btn_buy_large: btn_buy_large.disabled = not is_unlocked

func _on_btn_sell_tanks_pressed():
		if current_tank_region != "":
				GameManager.sell_tanks(current_tank_region)
				update_tank_view(current_tank_region)

func open_region_detail(r):
		GameManager.current_viewing_region = r
		get_tree().change_scene_to_file("res://RegionDetail.tscn")

func update_map_buttons():
		var map_container = $ControlPanel/OilFieldMenu
		if not map_container: return
		var regions = GameManager.regions
		for r_name in regions:
				var btn_name = "Btn" + r_name.replace("-","").replace(" ", "")
				if map_container.has_node(btn_name):
						var btn = map_container.get_node(btn_name)
						var data = regions[r_name]
						btn.visible = data.get("visible", false)
						if data.get("unlocked", false):
								btn.text = r_name.to_upper() + "\n[ BESITZ ]"
						else:
								var cost_k = int((data.get("license_fee", 0) * GameManager.inflation_rate) / 1000)
								btn.text = r_name.to_upper() + "\n($%dK)" % cost_k

func update_tank_buttons_visibility():
		var container = $ControlPanel/TankMenu/VBoxContainer2
		if not container: return
		var regions = GameManager.regions
		for r_name in regions:
				var btn_name = "BtnTank" + r_name.replace("-","").replace(" ", "")
				if container.has_node(btn_name):
						var btn = container.get_node(btn_name)
						btn.visible = regions[r_name].get("visible", false)

func apply_era_theme():
		if not GameManager.era_colors.has(GameManager.current_era): return
		var colors = GameManager.era_colors[GameManager.current_era]
		customize_children(self, colors)

func customize_children(node, colors):
		for child in node.get_children():
				if child.get_child_count() > 0:
						customize_children(child, colors)
				if child is Label:
						child.add_theme_color_override("font_color", colors["text"])
				if child is Button:
						child.add_theme_color_override("font_color", colors["text"])

func apply_retro_slider_style(slider: HSlider):
		slider.custom_minimum_size.y = 40 
		var sb_bg = StyleBoxFlat.new(); sb_bg.bg_color = Color(0.1, 0.1, 0.1); sb_bg.border_width_left = 2; sb_bg.border_width_top = 2; sb_bg.border_width_right = 2; sb_bg.border_width_bottom = 2; sb_bg.border_color = Color(0.3, 0.3, 0.3); sb_bg.corner_radius_top_left = 4; sb_bg.corner_radius_top_right = 4; sb_bg.corner_radius_bottom_right = 4; sb_bg.corner_radius_bottom_left = 4; sb_bg.content_margin_top = 10; sb_bg.content_margin_bottom = 10
		var sb_fill = StyleBoxFlat.new(); sb_fill.bg_color = Color(0.0, 0.8, 0.0, 0.6); sb_fill.border_width_left = 0; sb_fill.border_width_top = 2; sb_fill.border_width_right = 2; sb_fill.border_width_bottom = 2; sb_fill.border_color = Color(0.2, 1.0, 0.2); sb_fill.corner_radius_top_left = 4; sb_fill.corner_radius_bottom_left = 4
		var img = Image.create(20, 40, false, Image.FORMAT_RGBA8); img.fill(Color(0,0,0,0)); var tex = ImageTexture.create_from_image(img)
		slider.add_theme_stylebox_override("slider", sb_bg)
		slider.add_theme_stylebox_override("grabber_area", sb_fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", sb_fill)
		slider.add_theme_icon_override("grabber", tex)
		slider.add_theme_icon_override("grabber_highlight", tex)
		slider.add_theme_icon_override("grabber_disabled", tex)

# --- MAP BUTTON CONNECTIONS ---
func _on_btn_alaska_pressed(): open_region_detail("Alaska")
func _on_btn_texas_pressed(): open_region_detail("Texas")
func _on_btn_nordsee_pressed(): open_region_detail("Nordsee")
func _on_btn_saudi_arabien_pressed(): open_region_detail("Saudi-Arabien")
func _on_btn_sibirien_pressed(): open_region_detail("Sibirien")
func _on_btn_venezuela_pressed(): open_region_detail("Venezuela")
func _on_btn_mexiko_pressed(): open_region_detail("Mexiko")
func _on_btn_nigeria_pressed(): open_region_detail("Nigeria")
func _on_btn_indonesien_pressed(): open_region_detail("Indonesien")
func _on_btn_brasilien_pressed(): open_region_detail("Brasilien")
func _on_btn_libyen_pressed(): open_region_detail("Libyen")

# --- UI Button Connections (Tank & Sales) ---
func _on_btn_tank_alaska_pressed(): update_tank_view("Alaska")
func _on_btn_tank_texas_pressed(): update_tank_view("Texas")
func _on_btn_tank_nordsee_pressed(): update_tank_view("Nordsee")
func _on_btn_tank_saudi_pressed(): update_tank_view("Saudi-Arabien")
func _on_btn_tank_sibirien_pressed(): update_tank_view("Sibirien")
func _on_btn_tank_indonesien_pressed(): update_tank_view("Indonesien")
func _on_btn_tank_venezuela_pressed(): update_tank_view("Venezuela")
func _on_btn_tank_nigeria_pressed(): update_tank_view("Nigeria")
func _on_btn_tank_libyen_pressed(): update_tank_view("Libyen")
func _on_btn_tank_mexiko_pressed(): update_tank_view("Mexiko")
func _on_btn_tank_brasilien_pressed(): update_tank_view("Brasilien")

func _on_btn_sell_texas_pressed(): current_sales_region="Texas"; update_sales_view()
func _on_btn_sell_alaska_pressed(): current_sales_region="Alaska"; update_sales_view()
func _on_btn_sell_nordsee_pressed(): current_sales_region="Nordsee"; update_sales_view()
func _on_btn_sell_nigeria_pressed(): current_sales_region="Nigeria"; update_sales_view()
func _on_btn_sell_venezuela_pressed(): current_sales_region="Venezuela"; update_sales_view()
func _on_btn_sell_mexiko_pressed(): current_sales_region="Mexiko"; update_sales_view()
func _on_btn_sell_saudi_pressed(): current_sales_region="Saudi-Arabien"; update_sales_view()
func _on_btn_sell_sibirien_pressed(): current_sales_region="Sibirien"; update_sales_view()
func _on_btn_sell_indonesien_pressed(): current_sales_region="Indonesien"; update_sales_view()
func _on_btn_sell_libyen_pressed(): current_sales_region="Libyen"; update_sales_view()
func _on_btn_sell_brasilien_pressed(): current_sales_region="Brasilien"; update_sales_view()

func _on_btn_min_pressed():
		if sales_slider: sales_slider.value = sales_slider.min_value
func _on_btn_50_pressed():
		if sales_slider: sales_slider.value = sales_slider.max_value * 0.5
func _on_btn_max_pressed():
		if sales_slider: sales_slider.value = sales_slider.max_value

# Platzhalter, damit der Code nicht crasht, falls diese Buttons noch in der Szene sind
func _on_btn_show_12_months_pressed(): pass
func _on_btn_show_all_pressed(): pass
func _on_btn_mode_graphs_pressed(): pass
func _on_btn_mode_table_pressed(): pass
func _on_btn_practice_pressed() -> void: pass
func _on_btn_test_site_pressed() -> void: pass
func _on_btn_workshop_pressed() -> void: pass
func _on_btn_drill_ground_pressed() -> void: pass
func _on_btn_lab_pressed() -> void: pass
func _on__pressed() -> void: pass

# --- MODUS WECHSEL (Renamed to match scene signals) ---
func _on_btn_show_current_pressed():
		if report_container: report_container.visible = true
		if graph_container: graph_container.visible = false
		btn_show_current.modulate = COL_TERM_MAIN
		btn_show_history.modulate = COL_TERM_DIM
		update_stats_view()

func _on_btn_show_history_pressed():
		if report_container: report_container.visible = false
		if graph_container: graph_container.visible = true
		btn_show_current.modulate = COL_TERM_DIM
		btn_show_history.modulate = COL_TERM_MAIN
		update_history_graphs()

# --- GRAPH LOGIK ---
func _on_graph_toggles_changed(_toggled_on):
		update_history_graphs()

func update_history_graphs():
		for child in graph_render_area.get_children():
				child.queue_free()
				
		var limit = 12
		var hist_rev = _get_last_n(GameManager.history_revenue, limit)
		var hist_exp = _get_last_n(GameManager.history_expenses, limit)
		var hist_prof = _get_last_n(GameManager.history_profit, limit)
		var hist_cash = _get_last_n(GameManager.history_cash, limit)
		
		if check_revenue.button_pressed:
				create_graph_layer(hist_rev, Color.GREEN, 0)
				
		if check_expenses.button_pressed:
				create_graph_layer(hist_exp, Color.RED, 0)
				
		if check_profit.button_pressed:
				create_graph_layer(hist_prof, Color.YELLOW, 0)
				
		if check_cash.button_pressed:
				create_graph_layer(hist_cash, Color.CYAN, 0)

func create_graph_layer(data: Array, color: Color, max_val: float):
		if data.is_empty(): return
		var graph = Control.new()
		graph.set_script(GraphScript)
		graph.set_anchors_preset(Control.PRESET_FULL_RECT)
		graph_render_area.add_child(graph)
		
		graph.line_color = color
		graph.dot_color = color
		graph.line_width = 3.0
		graph.set_data(data, max_val)

func _get_last_n(array: Array, n: int) -> Array:
		if array.size() <= n:
				return array.duplicate()
		return array.slice(array.size() - n)

# --- ENHANCED FINANCIAL REPORTS ---
func _on_btn_financial_report_pressed():
		var report_panel = preload("res://FinancialReportPanel.gd").new()
		add_child(report_panel)
		report_panel.show_report()

# --- ACHIEVEMENTS DISPLAY ---
func _on_btn_achievements_pressed():
		var achievement_panel = preload("res://AchievementDisplay.gd").new()
		add_child(achievement_panel)
		achievement_panel.show_achievements()

# --- ACTIVITY FEED DISPLAY ---
func _on_btn_activity_feed_pressed():
		var feed_panel = preload("res://ActivityFeedDisplay.gd").new()
		add_child(feed_panel)
		feed_panel.show_feed()

# --- LOAN MANAGEMENT ---
func _on_btn_loans_pressed():
		_show_loan_menu()

func _show_loan_menu():
		if GameManager.loan_manager == null:
				if has_node("/root/FeedbackOverlay"):
						get_node("/root/FeedbackOverlay").show_msg("Kreditsystem nicht verfügbar", Color.RED)
				return
		
		var loan_panel = Panel.new()
		loan_panel.custom_minimum_size = Vector2(600, 450)
		loan_panel.set_anchors_preset(Control.PRESET_CENTER)
		add_child(loan_panel)
		
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 15)
		margin.add_theme_constant_override("margin_bottom", 15)
		loan_panel.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		margin.add_child(vbox)
		
		# Header
		var header = HBoxContainer.new()
		vbox.add_child(header)
		
		var title = Label.new()
		title.text = "KREDITZENTRALE"
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", COL_TERM_MAIN)
		header.add_child(title)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		
		var btn_close = Button.new()
		btn_close.text = "X"
		btn_close.pressed.connect(func(): loan_panel.queue_free())
		header.add_child(btn_close)
		
		# Credit rating display
		var rating_box = HBoxContainer.new()
		vbox.add_child(rating_box)
		
		var rating_label = Label.new()
		rating_label.text = "Kreditrating: " + GameManager.loan_manager.get_credit_rating_text()
		rating_label.add_theme_color_override("font_color", COL_TERM_MAIN)
		rating_box.add_child(rating_label)
		
		# Debt display
		var debt_label = Label.new()
		debt_label.text = " | Gesamtschulden: $" + _fmt_money_str(GameManager.loan_manager.get_total_debt())
		debt_label.add_theme_color_override("font_color", Color.RED if GameManager.loan_manager.get_total_debt() > 0 else COL_TERM_DIM)
		rating_box.add_child(debt_label)
		
		# Active loans
		var loans_label = Label.new()
		loans_label.text = "Aktive Kredite: %d / %d" % [GameManager.loan_manager.active_loans.size(), 3]
		vbox.add_child(loans_label)
		
		# Separator
		var sep = HSeparator.new()
		vbox.add_child(sep)
		
		# Available loan offers
		var offers_label = Label.new()
		offers_label.text = "VERFÜGBARE KREDITE:"
		offers_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(offers_label)
		
		var offers = GameManager.loan_manager.get_available_offers()
		for offer in offers:
				var offer_hbox = HBoxContainer.new()
				offer_hbox.add_theme_constant_override("separation", 10)
				vbox.add_child(offer_hbox)
				
				var offer_info = Label.new()
				offer_info.text = "%s: $%s @ %.1f%% (%d Monate)" % [
						offer["name"], _fmt_money_str(offer["principal"]), 
						offer["interest_rate"] * 100, offer["duration_months"]
				]
				offer_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				offer_hbox.add_child(offer_info)
				
				var btn_take = Button.new()
				btn_take.text = "AUFNEHMEN"
				btn_take.disabled = not offer["can_afford"]
				btn_take.pressed.connect(func(): _take_loan(offer["id"], loan_panel))
				offer_hbox.add_child(btn_take)
		
		# Bankruptcy warning
		if GameManager.loan_manager.bankruptcy_risk > 0.3:
				var warning = Label.new()
				warning.text = "WARNUNG BANKROTT-RISIKO: " + GameManager.loan_manager.get_bankruptcy_risk_text()
				warning.add_theme_color_override("font_color", Color.RED)
				warning.add_theme_font_size_override("font_size", 18)
				vbox.add_child(warning)

func _take_loan(offer_id: String, panel: Panel):
		var result = GameManager.loan_manager.take_loan(offer_id)
		if has_node("/root/FeedbackOverlay"):
				get_node("/root/FeedbackOverlay").show_msg(result["message"], Color.GREEN if result["success"] else Color.RED)
		if result["success"]:
				panel.queue_free()
				_show_loan_menu()
