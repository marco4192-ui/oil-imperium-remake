extends Node
# NewspaperManager.gd - Dynamic newspaper headlines system
# Shows world events, company news, and historical events

signal newspaper_published(headline: String, category: String)

# --- NEWSPAPER CATEGORIES ---
enum Category {
        WORLD_EVENT,
        COMPANY_SUCCESS,
        COMPANY_FAILURE,
        HISTORICAL_EVENT,
        OPEC_NEWS,
        POLITICAL_NEWS,
        MARKET_NEWS,
        DISASTER
}

# --- HISTORICAL EVENTS (Real world events 1970-2000) ---
const HISTORICAL_EVENTS = [
        {
                "year": 1970,
                "month": 1,
                "title": "EARTH DAY BEGINS ENVIRONMENTAL MOVEMENT",
                "text": "Millions of Americans protest for environmental awareness. Oil industry faces new scrutiny.",
                "effect": {"reputation": -5},
                "triggered": false
        },
        {
                "year": 1973,
                "month": 10,
                "title": "OIL CRISIS BEGINS - OPEC EMBARGO",
                "text": "Arab oil producers announce embargo against US. Prices quadruple overnight! Gas lines stretch for miles.",
                "effect": {"oil_price_multiplier": 4.0, "inflation": 1.1},
                "triggered": false
        },
        {
                "year": 1974,
                "month": 3,
                "title": "SPEED LIMIT 55 MPH TO SAVE FUEL",
                "text": "Federal government imposes 55 mph speed limit nationwide to conserve gasoline.",
                "effect": {"demand_reduction": 0.95},
                "triggered": false
        },
        {
                "year": 1979,
                "month": 3,
                "title": "THREE MILE ISLAND NUCLEAR ACCIDENT",
                "text": "Nuclear accident in Pennsylvania. Oil stocks surge as alternative energy fears grow.",
                "effect": {"oil_price_multiplier": 1.15},
                "triggered": false
        },
        {
                "year": 1979,
                "month": 11,
                "title": "IRAN HOSTAGE CRISIS - OIL PRICES SPIKE",
                "text": "American hostages taken in Tehran. Iranian oil exports halted. Global panic buying ensues.",
                "effect": {"oil_price_multiplier": 2.0, "volatility": 0.1},
                "triggered": false
        },
        {
                "year": 1980,
                "month": 9,
                "title": "IRAN-IRAQ WAR BEGINS",
                "text": "War between two major oil producers threatens Gulf exports. Prices reach record highs.",
                "effect": {"oil_price_multiplier": 1.5, "region_blocked": "Saudi-Arabien"},
                "triggered": false
        },
        {
                "year": 1986,
                "month": 1,
                "title": "OIL PRICE COLLAPSE - $10 PER BARREL",
                "text": "OPEC price war floods market with oil. Prices crash from $30 to $10. Small producers go bankrupt.",
                "effect": {"oil_price_multiplier": 0.4},
                "triggered": false
        },
        {
                "year": 1988,
                "month": 7,
                "title": "PIPER ALPHA DISASTER",
                "text": "North Sea oil platform explodes, killing 167 workers. Safety regulations tightened worldwide.",
                "effect": {"safety_costs": 1.2},
                "triggered": false
        },
        {
                "year": 1989,
                "month": 3,
                "title": "EXXON VALDEZ OIL SPILL",
                "text": "Tanker spills 11 million gallons off Alaska. Environmental catastrophe sparks outrage.",
                "effect": {"reputation_all": -10, "environmental_regulations": true},
                "triggered": false
        },
        {
                "year": 1990,
                "month": 8,
                "title": "IRAQ INVADES KUWAIT - GULF WAR BEGINS",
                "text": "Saddam Hussein's forces seize Kuwait. Oil prices double. US sends troops to Saudi Arabia.",
                "effect": {"oil_price_multiplier": 2.0, "region_blocked": "Saudi-Arabien"},
                "triggered": false
        },
        {
                "year": 1991,
                "month": 1,
                "title": "OPERATION DESERT STORM",
                "text": "US-led coalition launches air war against Iraq. 'Smart bombs' broadcast live on CNN.",
                "effect": {"oil_price_multiplier": 1.3},
                "triggered": false
        },
        {
                "year": 1991,
                "month": 2,
                "title": "KUWAIT OIL FIRES BURNING",
                "text": "Retreating Iraqis torch 700 Kuwaiti oil wells. Black rain falls across region.",
                "effect": {"oil_price_multiplier": 1.1},
                "triggered": false
        },
        {
                "year": 1997,
                "month": 7,
                "title": "ASIAN FINANCIAL CRISIS",
                "text": "Currency collapse spreads across Asia. Oil demand drops sharply.",
                "effect": {"oil_price_multiplier": 0.8, "demand_reduction": 0.9},
                "triggered": false
        },
        {
                "year": 1999,
                "month": 4,
                "title": "OPEC PRODUCTION CUTS",
                "text": "OPEC agrees to cut production by 1.7 million barrels per day. Prices begin recovery.",
                "effect": {"oil_price_multiplier": 1.3},
                "triggered": false
        }
]

# --- COMPANY NEWS TEMPLATES ---
const COMPANY_SUCCESS_TEMPLATES = [
        {"title": "MAJOR OIL STRIKE FOR %s!", "text": "%s announces discovery of massive oil reserves. Stock prices soar!", "min_cash": 10000000},
        {"title": "%s SIGNS MEGA-CONTRACT", "text": "%s secures billion-dollar supply deal with major buyer.", "min_cash": 5000000},
        {"title": "%s EXPANDS OPERATIONS", "text": "%s opens new drilling operations in promising territory.", "min_cash": 2000000},
        {"title": "%s BEATS QUARTERLY EXPECTATIONS", "text": "Analysts surprised as %s reports better than expected profits.", "min_cash": 1000000},
        {"title": "%s CEO NAMED INDUSTRY LEADER", "text": "Trade magazine names %s executive 'Oilman of the Year'.", "reputation_min": 70},
]

const COMPANY_FAILURE_TEMPLATES = [
        {"title": "DRY HOLE DISASTER FOR %s", "text": "%s wastes millions on non-productive well. Investors concerned.", "cash_loss": 500000},
        {"title": "%s FACES SAFETY VIOLATIONS", "text": "Regulators cite %s for workplace safety infractions.", "reputation_max": 50},
        {"title": "%s OIL SPILL INVESTIGATION", "text": "Environmental agencies investigate %s for alleged pollution.", "reputation_max": 60},
        {"title": "%s WORKER STRIKE CONTINUES", "text": "Labor dispute at %s enters second week. Production halted.", "condition": "strike"},
        {"title": "%s STOCK TUMBLES", "text": "Investors flee %s amid rumors of financial troubles.", "cash_max": 1000000},
]

# --- WORLD EVENT TEMPLATES ---
const WORLD_EVENT_TEMPLATES = [
        {"title": "NEW OIL DISCOVERY IN NORTH SEA", "text": "Massive reserves discovered. European production set to increase.", "effect": {"oil_price_adjust": -2.0}},
        {"title": "HURRICANE THREATENS GULF PLATFORMS", "text": "Storm forces evacuation of offshore rigs. Production halted.", "effect": {"production_penalty": 0.8}},
        {"title": "TECHNOLOGY BREAKTHROUGH IN DRILLING", "text": "New techniques promise deeper, cheaper wells.", "effect": {"drill_cost_reduction": 0.9}},
        {"title": "ENVIRONMENTAL GROUPS PROTEST", "text": "Greenpeace stages protest at major oil terminal.", "effect": {"reputation_all": -5}},
        {"title": "NEW PIPELINE OPENS", "text": "Major pipeline completed, reducing transport costs.", "effect": {"transport_cost": 0.95}},
]

# --- REFERENCES ---
var game_manager = null
var triggered_events: Dictionary = {}  # Track triggered events by "year_month" key
var current_headlines = []
var newspaper_history = []

func _ready():
        await get_tree().create_timer(0.5).timeout
        if has_node("/root/GameManager"):
                game_manager = get_node("/root/GameManager")

# --- CHECK FOR NEWSPAPER PUBLICATION ---
func check_monthly_events():
        if game_manager == null:
                return []
        
        var new_headlines = []
        
        # Check historical events
        for event in HISTORICAL_EVENTS:
                var event_key = "%d_%d" % [event["year"], event["month"]]
                if not triggered_events.has(event_key):
                        if game_manager.date["year"] == event["year"] and game_manager.date["month"] == event["month"]:
                                triggered_events[event_key] = true
                                new_headlines.append({
                                        "title": event["title"],
                                        "text": event["text"],
                                        "category": Category.HISTORICAL_EVENT,
                                        "effect": event.get("effect", {})
                                })
                                _apply_event_effect(event.get("effect", {}))
        
        # Generate random world events (10% chance per month)
        if randf() < 0.1:
                var event = WORLD_EVENT_TEMPLATES.pick_random()
                new_headlines.append({
                        "title": event["title"],
                        "text": event["text"],
                        "category": Category.WORLD_EVENT,
                        "effect": event.get("effect", {})
                })
        
        # Generate company-specific news
        new_headlines.append_array(_generate_company_news())
        
        # Store headlines
        for headline in new_headlines:
                headline["date"] = "%02d/%d" % [game_manager.date["month"], game_manager.date["year"]]
                newspaper_history.append(headline)
                newspaper_published.emit(headline["title"], str(headline["category"]))
        
        current_headlines = new_headlines
        return new_headlines

func _generate_company_news() -> Array:
        var news = []
        if game_manager == null:
                return news
        
        var company = game_manager.company_name
        
        # Success news based on performance
        if game_manager.cash > 5000000:
                var template = COMPANY_SUCCESS_TEMPLATES[0]
                news.append({
                        "title": template["title"] % company,
                        "text": template["text"] % company,
                        "category": Category.COMPANY_SUCCESS,
                        "effect": {"reputation": 5}
                })
        
        # Failure news if things are going badly
        if game_manager.cash < 1000000:
                var template = COMPANY_FAILURE_TEMPLATES[4]
                news.append({
                        "title": template["title"] % company,
                        "text": template["text"] % company,
                        "category": Category.COMPANY_FAILURE,
                        "effect": {"reputation": -5}
                })
        
        return news

func _apply_event_effect(effect: Dictionary):
        if game_manager == null:
                return
        
        if effect.has("oil_price_multiplier"):
                game_manager.price_multiplier *= effect["oil_price_multiplier"]
        
        if effect.has("inflation"):
                game_manager.inflation_rate *= effect["inflation"]
        
        if effect.has("reputation"):
                # Would need reputation system
                pass
        
        if effect.has("region_blocked"):
                if game_manager.regions.has(effect["region_blocked"]):
                        game_manager.regions[effect["region_blocked"]]["block_timer"] = 6

# --- GET HEADLINES FOR DISPLAY ---
func get_current_headlines() -> Array:
        return current_headlines

func get_history_headlines(count: int = 10) -> Array:
        var start = max(0, newspaper_history.size() - count)
        return newspaper_history.slice(start)

# --- GENERATE NEWSPAPER DISPLAY ---
func create_newspaper_display() -> Control:
        var panel = PanelContainer.new()
        panel.custom_minimum_size = Vector2(600, 400)
        
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.95, 0.92, 0.85)  # Old paper color
        style.border_color = Color(0.3, 0.25, 0.2)
        style.set_border_width_all(3)
        panel.add_theme_stylebox_override("panel", style)
        
        var vbox = VBoxContainer.new()
        panel.add_child(vbox)
        
        # Newspaper masthead
        var masthead = Label.new()
        masthead.text = "━━━━━ THE DAILY BARREL ━━━━━"
        masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        masthead.add_theme_font_size_override("font_size", 24)
        masthead.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
        vbox.add_child(masthead)
        
        var date_label = Label.new()
        if game_manager:
                date_label.text = "Vol. %d | %s %d | Price: $%.2f/bbl" % [
                        game_manager.date["year"] - 1969,
                        _get_month_name(game_manager.date["month"]),
                        game_manager.date["year"],
                        game_manager.oil_price
                ]
        date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        date_label.add_theme_font_size_override("font_size", 12)
        date_label.add_theme_color_override("font_color", Color(0.3, 0.25, 0.2))
        vbox.add_child(date_label)
        
        # Headlines
        var scroll = ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vbox.add_child(scroll)
        
        var headlines_container = VBoxContainer.new()
        scroll.add_child(headlines_container)
        
        for headline in current_headlines:
                var item = _create_headline_item(headline)
                headlines_container.add_child(item)
        
        return panel

func _create_headline_item(headline: Dictionary) -> Control:
        var container = VBoxContainer.new()
        
        # Title
        var title = Label.new()
        title.text = headline["title"]
        title.autowrap_mode = TextServer.AUTOWRAP_WORD
        title.add_theme_font_size_override("font_size", 16)
        title.add_theme_color_override("font_color", _get_category_color(headline["category"]))
        container.add_child(title)
        
        # Text
        var text = Label.new()
        text.text = headline["text"]
        text.autowrap_mode = TextServer.AUTOWRAP_WORD
        text.add_theme_font_size_override("font_size", 12)
        text.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
        container.add_child(text)
        
        # Separator
        var sep = HSeparator.new()
        container.add_child(sep)
        
        return container

func _get_category_color(category: int) -> Color:
        match category:
                Category.HISTORICAL_EVENT:
                        return Color(0.6, 0.1, 0.1)  # Dark red for historical
                Category.COMPANY_SUCCESS:
                        return Color(0.1, 0.4, 0.1)  # Green for success
                Category.COMPANY_FAILURE:
                        return Color(0.5, 0.2, 0.1)  # Brown for failure
                Category.WORLD_EVENT:
                        return Color(0.1, 0.1, 0.5)  # Blue for world news
                Category.OPEC_NEWS:
                        return Color(0.5, 0.4, 0.1)  # Gold for OPEC
                _:
                        return Color(0.2, 0.15, 0.1)

func _get_month_name(month: int) -> String:
        var months = ["January", "February", "March", "April", "May", "June",
                                  "July", "August", "September", "October", "November", "December"]
        return months[month - 1] if month >= 1 and month <= 12 else "Unknown"

# --- SAVE/LOAD ---
func get_save_data() -> Dictionary:
        return {
                "history": newspaper_history,
                "triggered_events": triggered_events
        }

func load_save_data(data: Dictionary):
        newspaper_history = data.get("history", [])
        triggered_events = data.get("triggered_events", {})
