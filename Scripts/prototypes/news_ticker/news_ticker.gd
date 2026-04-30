# news_ticker.gd
# ─────────────────────────────────────────────────────────────────────────────
# Prototype: scrolling news headlines that telegraph upcoming market moves.
#
# How it works:
#   • Listens to Market.prices_changed (no payload).
#   • For each mineral, peeks at Market.get_price_history() and emits a
#     forward-looking headline that hints at the next move.
#   • 10% of headlines are flipped (misinformation) so the ticker stays a
#     skill check, not a cheat sheet.
#   • Headlines scroll right-to-left across a 32px black bar at the top of
#     the screen, in the standard monochrome palette.
#
# Read-only on Market/GameState. Removable by deleting this folder and the
# matching mount in PrototypeFlags.
# ─────────────────────────────────────────────────────────────────────────────

extends "res://Scripts/prototypes/prototype_base.gd"

# MineralType enum order (from the Bible, Section 4.1):
const MINERAL_NAMES := ["IRON", "NICKEL", "SILICA", "PLATINUM"]

@export var bar_height: float          = 32.0
@export var scroll_speed: float        = 90.0     # pixels per second
@export var misinformation_rate: float = 0.10     # 0.0 disables the lying
@export var max_queue: int             = 8
@export var separator: String          = "   ◆   "
@export var canvas_layer_index: int    = 50       # above gameplay, below modals

var _canvas: CanvasLayer
var _root: Control
var _bar: ColorRect
var _label: Label
var _queue: Array[String] = []
var _current: String = ""
var _label_width: float = 0.0


func _flag_name() -> String:
	return "NEWS_TICKER"


func _setup_prototype() -> void:
	_build_ui()

	var market := get_node_or_null("/root/Market")
	if market == null:
		push_warning("[NewsTicker] Market autoload not found — ticker will idle")
	else:
		_connect_signal(market, "prices_changed", Callable(self, "_on_prices_changed"))

	# Seed an opening message so the bar is never empty on boot.
	_enqueue("MARKET BUREAU ONLINE — STANDING BY")


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = canvas_layer_index
	add_child(_canvas)

	_root = Control.new()
	_root.name = "TickerRoot"
	_root.anchor_right = 1.0
	_root.offset_bottom = bar_height
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_root)

	_bar = ColorRect.new()
	_bar.color = Color(0, 0, 0, 1)
	_bar.anchor_right = 1.0
	_bar.anchor_bottom = 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar)

	# 1px bottom border in the project's standard gray.
	var border := Panel.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 0)
	stylebox.border_color = Color(0.6, 0.6, 0.6)
	stylebox.border_width_top = 0
	stylebox.border_width_left = 0
	stylebox.border_width_right = 0
	stylebox.border_width_bottom = 1
	stylebox.set_corner_radius_all(0)
	border.add_theme_stylebox_override("panel", stylebox)
	border.anchor_right = 1.0
	border.anchor_bottom = 1.0
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(border)

	_label = Label.new()
	_label.name = "TickerLabel"
	_label.position = Vector2(0, 6)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_label.add_theme_font_size_override("font_size", 16)
	_label.text = ""
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inherits DM Mono from the project theme automatically.
	_root.add_child(_label)


func _process(delta: float) -> void:
	if _label == null:
		return
	if _current.is_empty():
		_pull_next()
		return
	_label.position.x -= scroll_speed * delta
	if _label.position.x + _label_width < 0.0:
		_pull_next()


# ─── Headline generation ────────────────────────────────────────────────────

func _on_prices_changed() -> void:
	var market := get_node_or_null("/root/Market")
	if market == null:
		return
	for i in range(MINERAL_NAMES.size()):
		var headline := _predict_headline(market, i)
		if headline.is_empty():
			continue
		if randf() < misinformation_rate:
			headline = _flip_headline(headline)
		_enqueue(headline)


# Forward-looking headline based on the last few prices for one mineral.
# Returns "" when nothing interesting is happening (skip the headline).
func _predict_headline(market: Object, mineral_index: int) -> String:
	var history: Array = market.get_price_history(mineral_index)
	if history.size() < 2:
		return ""

	var last_price: int  = int(history[history.size() - 1])
	var prev_price: int  = int(history[history.size() - 2])
	var direction: int   = last_price - prev_price

	match mineral_index:
		0:  # Iron — random walk
			if direction > 0:
				return "IRON FOUNDRIES REPORT INCOMING SHORTAGE — IRON ↑"
			elif direction < 0:
				return "MARS COLONY DECLARES IRON SURPLUS — IRON ↓"
			else:
				return ""

		1:  # Nickel — supply/demand with appreciation
			if direction >= 0 and last_price >= 5:
				return "NICKEL HOARDERS STAGE A SQUEEZE — NICKEL ↑"
			elif direction < 0:
				return "BULK NICKEL SELL-OFF FLOODS THE MARKET — NICKEL ↓"
			else:
				return "NICKEL SUPPLY CHANNELS QUIET — APPRECIATION BUILDING"

		2:  # Silica — sine wave (predict from last two deltas)
			if history.size() >= 3:
				var d1: int = int(history[history.size() - 1]) - int(history[history.size() - 2])
				var d2: int = int(history[history.size() - 2]) - int(history[history.size() - 3])
				if d1 > 0 and d2 > 0:
					return "SILICA DEMAND CRESTING — PEAK NEAR (SILICA ↑)"
				if d1 < 0 and d2 < 0:
					return "SILICA TROUGH WIDENS — SILICA ↓"
				if d1 > 0 and d2 <= 0:
					return "SILICA INVERSION — UPSWING BEGINS (SILICA ↑)"
				if d1 < 0 and d2 >= 0:
					return "SILICA INVERSION — DOWNSWING BEGINS (SILICA ↓)"
			return ""

		3:  # Platinum — boom & bust
			if last_price >= 8:
				return "PLATINUM BUBBLE WARNING — CRASH IMMINENT"
			elif direction > 0 and last_price >= 6:
				return "PLATINUM RUSH ACCELERATES — PLATINUM ↑"
			elif direction < 0 and last_price <= 4:
				return "PLATINUM REBOUND ON THE HORIZON — PLATINUM ↑"
			elif direction < 0:
				return "PLATINUM BUST — PLATINUM ↓"
			else:
				return ""

	return ""


func _flip_headline(h: String) -> String:
	if h.find("↑") != -1:
		return h.replace("↑", "↓")
	if h.find("↓") != -1:
		return h.replace("↓", "↑")
	# No directional arrow — wrap it in a "rumor" frame to mark it as soft.
	return "RUMOR: " + h


# ─── Queue plumbing ─────────────────────────────────────────────────────────

func _enqueue(headline: String) -> void:
	if _queue.size() >= max_queue:
		return
	_queue.append(headline)


func _pull_next() -> void:
	if _queue.is_empty():
		_enqueue(_idle_headline())
	_current = _queue.pop_front()
	_label.text = _current + separator
	# Force a layout pass so get_minimum_size() reports the new width.
	_label.reset_size()
	_label_width = _label.size.x
	if _label_width <= 0.0:
		_label_width = _label.get_minimum_size().x
	var viewport_size := get_viewport().get_visible_rect().size
	_label.position.x = viewport_size.x


func _idle_headline() -> String:
	var fillers := [
		"ASTEROID BUREAU ADVISES STEADY HANDS",
		"CARGO INSURANCE PREMIUMS UNCHANGED",
		"DRONE GUILD CALLS FOR CALM IN THE BELT",
		"SECTOR TRAFFIC NOMINAL — NO PIRACY ALERTS",
		"DEEP-SPACE WEATHER QUIET — NO FLARES ON RADAR",
	]
	return fillers[randi() % fillers.size()]
