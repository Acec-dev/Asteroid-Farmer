extends Control
## Displays a line graph of the last 10 prices for a specific mineral
## Modular - can be configured to track any mineral type
## Automatically updates when Market prices change

## The mineral to track (iron, nickel, or silica)
@export var mineral_type: String = "iron"

## Graph visual settings
@export_group("Appearance")
@export var line_color: Color = Color.CYAN
@export var line_width: float = 2.0
@export var point_radius: float = 4.0
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.8)
@export var grid_color: Color = Color(0.3, 0.3, 0.4, 0.5)
@export var text_color: Color = Color.WHITE
@export var show_grid: bool = true
@export var show_labels: bool = true

## Graph dimensions (margins for labels)
@export_group("Layout")
@export var margin_left: float = 40.0
@export var margin_right: float = 20.0
@export var margin_top: float = 30.0
@export var margin_bottom: float = 30.0

## Price range for the graph
const MIN_PRICE := 0
const MAX_PRICE := 8

# Cached price history for this mineral
var _price_history: Array = []


func _ready() -> void:
	# Connect to Market signals
	if Market:
		Market.prices_changed.connect(_on_prices_changed)
		# Initialize with current history
		_price_history = Market.get_price_history(mineral_type).duplicate()

	# Ensure we redraw when ready
	queue_redraw()


func _on_prices_changed(_new_prices: Dictionary) -> void:
	# Update our cached history
	_price_history = Market.get_price_history(mineral_type).duplicate()
	queue_redraw()


func _draw() -> void:
	if _price_history.is_empty():
		return

	# Calculate drawable area
	var graph_width := size.x - margin_left - margin_right
	var graph_height := size.y - margin_top - margin_bottom
	var graph_origin := Vector2(margin_left, size.y - margin_bottom)

	# Draw background
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true)

	# Draw grid if enabled
	if show_grid:
		_draw_grid(graph_origin, graph_width, graph_height)

	# Draw labels if enabled
	if show_labels:
		_draw_labels(graph_origin, graph_width, graph_height)

	# Draw the price line graph
	_draw_price_line(graph_origin, graph_width, graph_height)


func _draw_grid(origin: Vector2, width: float, height: float) -> void:
	# Horizontal grid lines (price levels)
	for i in range(MIN_PRICE, MAX_PRICE + 1):
		var y := origin.y - (float(i) / MAX_PRICE) * height
		draw_line(
			Vector2(origin.x, y),
			Vector2(origin.x + width, y),
			grid_color,
			1.0
		)

	# Vertical grid lines (time points)
	var num_points := min(_price_history.size(), 10)
	if num_points > 1:
		for i in range(num_points):
			var x := origin.x + (float(i) / (num_points - 1)) * width
			draw_line(
				Vector2(x, origin.y),
				Vector2(x, origin.y - height),
				grid_color,
				1.0
			)


func _draw_labels(origin: Vector2, width: float, height: float) -> void:
	# Title
	var title := mineral_type.capitalize() + " Price History"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(margin_left, margin_top - 10),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		text_color
	)

	# Y-axis labels (prices)
	for i in range(0, MAX_PRICE + 1, 2):
		var y := origin.y - (float(i) / MAX_PRICE) * height
		var label := "$%d" % i
		draw_string(
			ThemeDB.fallback_font,
			Vector2(margin_left - 30, y + 5),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			text_color
		)

	# X-axis label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(origin.x + width / 2 - 20, size.y - 5),
		"Time →",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		text_color
	)


func _draw_price_line(origin: Vector2, width: float, height: float) -> void:
	var num_points := _price_history.size()
	if num_points < 2:
		# Just draw a single point if we only have one price
		if num_points == 1:
			var price: float = _price_history[0]
			var y := origin.y - (price / MAX_PRICE) * height
			draw_circle(Vector2(origin.x, y), point_radius, line_color)
		return

	# Draw lines connecting price points
	for i in range(num_points - 1):
		var price1: float = _price_history[i]
		var price2: float = _price_history[i + 1]

		# Calculate positions (spread evenly across width)
		var x1 := origin.x + (float(i) / (num_points - 1)) * width
		var x2 := origin.x + (float(i + 1) / (num_points - 1)) * width
		var y1 := origin.y - (price1 / MAX_PRICE) * height
		var y2 := origin.y - (price2 / MAX_PRICE) * height

		# Draw line segment
		draw_line(Vector2(x1, y1), Vector2(x2, y2), line_color, line_width)

	# Draw points on top of lines
	for i in range(num_points):
		var price: float = _price_history[i]
		var x := origin.x + (float(i) / (num_points - 1)) * width
		var y := origin.y - (price / MAX_PRICE) * height

		# Draw point
		draw_circle(Vector2(x, y), point_radius, line_color)

		# Draw darker center
		draw_circle(Vector2(x, y), point_radius - 1, line_color.darkened(0.3))


## Manually set the mineral type to track
func set_mineral_type(new_mineral: String) -> void:
	mineral_type = new_mineral
	if Market:
		_price_history = Market.get_price_history(mineral_type).duplicate()
		queue_redraw()


## Force a refresh of the graph
func refresh() -> void:
	if Market:
		_price_history = Market.get_price_history(mineral_type).duplicate()
		queue_redraw()
