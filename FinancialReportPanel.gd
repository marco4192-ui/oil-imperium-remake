extends Control
# FinancialReportPanel.gd - Enhanced financial reports with charts and year-over-year analysis

# --- UI REFERENCES ---
var panel: Panel
var main_vbox: VBoxContainer

# Chart containers
var line_chart_container: Control
var pie_chart_container: Control

# Data
var current_view: String = "monthly"  # "monthly" or "yearly"
var selected_year: int = 1970

# Colors for charts
const COLORS = {
		"revenue": Color(0.2, 0.8, 0.2),
		"expenses": Color(0.9, 0.3, 0.3),
		"profit": Color(0.3, 0.7, 0.9),
		"cash": Color(1.0, 0.8, 0.2),
		"office": Color(0.6, 0.4, 0.2),
		"rigs": Color(0.3, 0.5, 0.8),
		"tanks": Color(0.5, 0.3, 0.6),
		"construction": Color(0.8, 0.6, 0.2),
		"facilities": Color(0.4, 0.7, 0.5),
		"research": Color(0.7, 0.5, 0.7),
		"contracts": Color(0.3, 0.8, 0.6),
		"sales": Color(0.2, 0.9, 0.4),
		"other": Color(0.5, 0.5, 0.5)
}

var game_manager = null

func _ready():
		await get_tree().create_timer(0.3).timeout
		if has_node("/root/GameManager"):
				game_manager = get_node("/root/GameManager")
		
		_build_ui()

func _build_ui():
		# Main panel
		panel = Panel.new()
		panel.custom_minimum_size = Vector2(800, 600)
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(panel)
		
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 20)
		margin.add_theme_constant_override("margin_bottom", 20)
		panel.add_child(margin)
		
		main_vbox = VBoxContainer.new()
		main_vbox.add_theme_constant_override("separation", 15)
		margin.add_child(main_vbox)
		
		# Header
		_build_header()
		
		# Tab buttons
		_build_tab_buttons()
		
		# Content area
		_build_content_area()

func _build_header():
		var header = HBoxContainer.new()
		main_vbox.add_child(header)
		
		var title = Label.new()
		title.text = "FINANZBERICHT"
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		header.add_child(title)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		
		# Close button
		var btn_close = Button.new()
		btn_close.text = "X"
		btn_close.custom_minimum_size = Vector2(40, 40)
		btn_close.pressed.connect(func(): queue_free())
		header.add_child(btn_close)

func _build_tab_buttons():
		var tab_bar = HBoxContainer.new()
		tab_bar.add_theme_constant_override("separation", 10)
		main_vbox.add_child(tab_bar)
		
		var btn_monthly = Button.new()
		btn_monthly.text = "Monatsbericht"
		btn_monthly.pressed.connect(func(): _switch_view("monthly"))
		tab_bar.add_child(btn_monthly)
		
		var btn_yearly = Button.new()
		btn_yearly.text = "Jahresvergleich"
		btn_yearly.pressed.connect(func(): _switch_view("yearly"))
		tab_bar.add_child(btn_yearly)
		
		var btn_breakdown = Button.new()
		btn_breakdown.text = "Kostenaufschlüsselung"
		btn_breakdown.pressed.connect(func(): _switch_view("breakdown"))
		tab_bar.add_child(btn_breakdown)

func _build_content_area():
		# Scroll container for content
		var scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main_vbox.add_child(scroll)
		
		var content = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(content)
		
		# Line chart for history
		line_chart_container = Control.new()
		line_chart_container.custom_minimum_size = Vector2(760, 250)
		content.add_child(line_chart_container)
		
		# Pie chart for breakdown
		pie_chart_container = Control.new()
		pie_chart_container.custom_minimum_size = Vector2(760, 300)
		pie_chart_container.visible = false
		content.add_child(pie_chart_container)

func _switch_view(view: String):
		current_view = view
		line_chart_container.visible = (view != "breakdown")
		pie_chart_container.visible = (view == "breakdown")
		queue_redraw()

func _draw():
		match current_view:
				"monthly":
						_draw_monthly_report()
				"yearly":
						_draw_yearly_comparison()
				"breakdown":
						_draw_cost_breakdown()

func _draw_monthly_report():
		if game_manager == null:
				return
		
		# Draw profit/loss line chart
		var data = _get_monthly_data()
		if data.size() < 2:
				_draw_empty_state(line_chart_container, "Nicht genügend Daten")
				return
		
		# Draw axes
		var chart_rect = Rect2(50, 30, 700, 200)
		_draw_chart_axes(line_chart_container, chart_rect, data)
		
		# Draw profit line
		_draw_line_chart(line_chart_container, chart_rect, data["profit"], COLORS.profit, "Gewinn")
		
		# Draw revenue line
		_draw_line_chart(line_chart_container, chart_rect, data["revenue"], COLORS.revenue, "Einnahmen")
		
		# Draw expense line
		_draw_line_chart(line_chart_container, chart_rect, data["expenses"], COLORS.expenses, "Ausgaben")

func _draw_yearly_comparison():
		if game_manager == null:
				return
		
		# Aggregate data by year
		var yearly_data = _get_yearly_data()
		if yearly_data.is_empty():
				_draw_empty_state(line_chart_container, "Keine Jahresdaten verfügbar")
				return
		
		var chart_rect = Rect2(50, 30, 700, 200)
		_draw_chart_axes(line_chart_container, chart_rect, {"profit": yearly_data["profits"]})
		
		# Draw bars for each year
		var bar_width = 50
		var spacing = 20
		var start_x = chart_rect.position.x + 30
		
		for i in range(yearly_data["years"].size()):
				var year = yearly_data["years"][i]
				var profit = yearly_data["profits"][i]
				var revenue = yearly_data["revenues"][i]
				
				var max_val = max(yearly_data["max_profit"], abs(yearly_data["min_profit"]))
				if max_val == 0:
						max_val = 1
				
				# Revenue bar
				var rev_height = (revenue / max_val) * (chart_rect.size.y / 2)
				var rev_rect = Rect2(start_x + i * (bar_width * 2 + spacing), 
								chart_rect.position.y + chart_rect.size.y / 2 - rev_height,
								bar_width, rev_height)
				_draw_rect(line_chart_container, rev_rect, COLORS.revenue)
				
				# Profit bar (can be negative)
				var prof_height = abs(profit / max_val) * (chart_rect.size.y / 2)
				var prof_y = chart_rect.position.y + chart_rect.size.y / 2
				if profit < 0:
						prof_y = chart_rect.position.y + chart_rect.size.y / 2
				else:
						prof_y = chart_rect.position.y + chart_rect.size.y / 2 - prof_height
				
				var prof_rect = Rect2(start_x + i * (bar_width * 2 + spacing) + bar_width,
								prof_y, bar_width, prof_height)
				_draw_rect(line_chart_container, prof_rect, COLORS.profit if profit >= 0 else COLORS.expenses)
				
				# Year label
				_draw_text(line_chart_container, str(year), 
								Vector2(start_x + i * (bar_width * 2 + spacing) + bar_width, chart_rect.end.y + 5),
								12, Color.WHITE)

func _draw_cost_breakdown():
		if game_manager == null:
				return
		
		# Get expense breakdown for current month
		var expenses = _get_expense_breakdown()
		if expenses.is_empty():
				_draw_empty_state(pie_chart_container, "Keine Ausgabendaten")
				return
		
		# Draw pie chart
		var center = Vector2(250, 150)
		var radius = 120.0
		var total = 0.0
		for cat in expenses:
				total += expenses[cat]
		
		if total == 0:
				return
		
		var current_angle = -PI / 2  # Start at top
		var legend_x = 420
		var legend_y = 50
		
		for i in range(expenses.keys().size()):
				var cat = expenses.keys()[i]
				var value = expenses[cat]
				var angle = (value / total) * 2 * PI
				
				# Draw pie slice
				var color = COLORS.get(cat, COLORS.other)
				_draw_pie_slice(pie_chart_container, center, radius, current_angle, current_angle + angle, color)
				
				# Draw legend
				var legend_rect = Rect2(legend_x, legend_y + i * 25, 15, 15)
				_draw_rect(pie_chart_container, legend_rect, color)
				_draw_text(pie_chart_container, "%s: $%s (%.1f%%)" % [cat, _fmt(value), (value/total)*100],
								Vector2(legend_x + 20, legend_y + i * 25), 14, Color.WHITE)
				
				current_angle += angle
		
		# Total
		_draw_text(pie_chart_container, "GESAMT: $%s" % _fmt(total), 
						Vector2(legend_x, legend_y + expenses.keys().size() * 25 + 20), 16, Color.YELLOW)

# --- HELPER FUNCTIONS ---
func _get_monthly_data() -> Dictionary:
		if game_manager == null:
				return {}
		
		return {
				"revenue": game_manager.history_revenue,
				"expenses": game_manager.history_expenses,
				"profit": game_manager.history_profit
		}

func _get_yearly_data() -> Dictionary:
		if game_manager == null or game_manager.history_profit.is_empty():
				return {}
		
		var years = []
		var revenues = []
		var profits = []
		
		var start_year = 1970
		var current_idx = 0
		
		# Group by year (12 months each)
		while current_idx < game_manager.history_profit.size():
				var year = start_year + int(current_idx / 12.0)
				var year_revenue = 0.0
				var year_profit = 0.0
				
				for m in range(12):
						if current_idx + m < game_manager.history_profit.size():
								year_revenue += game_manager.history_revenue[current_idx + m]
								year_profit += game_manager.history_profit[current_idx + m]
				
				years.append(year)
				revenues.append(year_revenue)
				profits.append(year_profit)
				
				current_idx += 12
		
		var max_profit = 0.0
		var min_profit = 0.0
		for p in profits:
				if p > max_profit: max_profit = p
				if p < min_profit: min_profit = p
		
		return {
				"years": years,
				"revenues": revenues,
				"profits": profits,
				"max_profit": max_profit,
				"min_profit": min_profit
		}

func _get_expense_breakdown() -> Dictionary:
		if game_manager == null:
				return {}
		
		var result = {}
		var finance_data = game_manager.current_month_finance
		
		for region_key in finance_data:
				var data = finance_data[region_key]
				if data.has("expenses"):
						for cat in data["expenses"]:
								if not result.has(cat):
										result[cat] = 0.0
								result[cat] += data["expenses"][cat]
		
		return result

func _draw_empty_state(container: Control, message: String):
		var label = Label.new()
		label.text = message
		label.position = Vector2(300, 100)
		label.add_theme_font_size_override("font_size", 20)
		container.add_child(label)

func _draw_chart_axes(container: Control, rect: Rect2, data: Dictionary):
		# Draw axes
		container.draw_line(rect.position, Vector2(rect.position.x, rect.end.y), Color.WHITE, 2)
		container.draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color.WHITE, 2)
		
		# Find max value
		var max_val = 0.0
		for key in data:
				for v in data[key]:
						if abs(v) > max_val:
								max_val = abs(v)
		
		if max_val == 0:
				max_val = 1000
		
		# Y-axis labels
		for i in range(5):
				var val = (max_val / 4) * i
				var y = rect.end.y - (i / 4.0) * rect.size.y
				container.draw_string(_get_default_font(), Vector2(rect.position.x - 40, y), 
								"$" + _fmt(val), HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color.GRAY)

func _draw_line_chart(container: Control, rect: Rect2, data: Array, color: Color, _label: String):
		if data.size() < 2:
				return
		
		var max_val = 0.0
		for v in data:
				if abs(v) > max_val:
						max_val = abs(v)
		if max_val == 0:
				max_val = 1
		
		var points = []
		var step_x = rect.size.x / (data.size() - 1)
		
		for i in range(data.size()):
				var x = rect.position.x + i * step_x
				var y = rect.end.y - ((data[i] / max_val) * rect.size.y * 0.9)
				points.append(Vector2(x, y))
		
		# Draw line
		for i in range(points.size() - 1):
				container.draw_line(points[i], points[i + 1], color, 2)

func _draw_pie_slice(container: Control, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color):
		var points = [center]
		var segments = 32
		
		for i in range(segments + 1):
				var angle = start_angle + (end_angle - start_angle) * (float(i) / segments)
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		
		container.draw_polygon(points, [color])

func _draw_rect(container: Control, rect: Rect2, color: Color):
		container.draw_rect(rect, color)

func _draw_text(container: Control, text: String, pos: Vector2, font_size: int, color: Color):
		container.draw_string(_get_default_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _get_default_font():
		return ThemeDB.fallback_font

func _fmt(value) -> String:
		var s = str(int(value))
		var res = ""
		var counter = 0
		for i in range(s.length() - 1, -1, -1):
				res = s[i] + res
				counter += 1
				if counter % 3 == 0 and i > 0:
						res = "." + res
		return res

# --- PUBLIC INTERFACE ---
func show_report():
		visible = true
		queue_redraw()

func hide_report():
		visible = false
