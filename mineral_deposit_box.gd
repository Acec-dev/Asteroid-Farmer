extends Area2D
class_name MineralDepositBox

## Container where player deposits minerals by flying over and releasing them

@export var box_width: float = 200.0
@export var box_height: float = 150.0
@export var visual_mineral_size: float = 3.0
@export var max_visual_minerals: int = 100  # Limit displayed minerals for performance

# Track deposited minerals by type
var deposited_minerals := {
	GameState.MineralType.IRON: 0,
	GameState.MineralType.NICKEL: 0,
	GameState.MineralType.SILICA: 0,
}

# Visual positions of minerals in the box (for drawing)
var _visual_minerals: Array[Dictionary] = []  # {type: MineralType, pos: Vector2}

# Colors for different mineral types
const MINERAL_COLORS = {
	GameState.MineralType.IRON: Color(0.7, 0.7, 0.7),      # Gray
	GameState.MineralType.NICKEL: Color(0.9, 0.9, 0.6),    # Yellowish
	GameState.MineralType.SILICA: Color(0.6, 0.8, 1.0),    # Light blue
}

var _player_in_range: bool = false

func _ready() -> void:
	add_to_group("mineral_deposit_box")

	# Set up collision shape for detection
	var collision = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(box_width, box_height)
	collision.shape = rect
	add_child(collision)

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	# Collect falling minerals that enter the box
	if area.is_in_group("falling_mineral"):
		var mineral_type = area.get("kind")
		if mineral_type != null:
			add_mineral(mineral_type)
			area.queue_free()

func add_mineral(type: GameState.MineralType) -> void:
	"""Add a mineral to the deposit box"""
	deposited_minerals[type] += 1

	# Add visual representation (don't exceed max for performance)
	if _visual_minerals.size() < max_visual_minerals:
		var mineral_data = {
			"type": type,
			"pos": _get_random_position_in_box()
		}
		_visual_minerals.append(mineral_data)

	queue_redraw()

func _get_random_position_in_box() -> Vector2:
	"""Get a random position within the box bounds"""
	var x = randf_range(-box_width * 0.4, box_width * 0.4)
	var y = randf_range(-box_height * 0.4, box_height * 0.4)
	return Vector2(x, y)

func get_total_minerals() -> int:
	"""Get total count of all deposited minerals"""
	var total = 0
	for count in deposited_minerals.values():
		total += count
	return total

func withdraw_all() -> Dictionary:
	"""Remove all minerals from the box and return them"""
	var withdrawn = deposited_minerals.duplicate()
	deposited_minerals = {
		GameState.MineralType.IRON: 0,
		GameState.MineralType.NICKEL: 0,
		GameState.MineralType.SILICA: 0,
	}
	_visual_minerals.clear()
	queue_redraw()
	return withdrawn

func is_player_in_range() -> bool:
	return _player_in_range

func _draw() -> void:
	# Draw the container box
	var box_rect = Rect2(-box_width * 0.5, -box_height * 0.5, box_width, box_height)
	var box_color = Color.WHITE if _player_in_range else Color(0.6, 0.6, 0.6)
	draw_rect(box_rect, Color.TRANSPARENT)

	# Draw box outline with thicker line when player is in range
	var line_width = 3.0 if _player_in_range else 1.5

	# Draw four sides of the rectangle
	var top_left = Vector2(-box_width * 0.5, -box_height * 0.5)
	var top_right = Vector2(box_width * 0.5, -box_height * 0.5)
	var bottom_left = Vector2(-box_width * 0.5, box_height * 0.5)
	var bottom_right = Vector2(box_width * 0.5, box_height * 0.5)

	draw_line(top_left, top_right, box_color, line_width)
	draw_line(top_right, bottom_right, box_color, line_width)
	draw_line(bottom_right, bottom_left, box_color, line_width)
	draw_line(bottom_left, top_left, box_color, line_width)

	# Draw minerals in the box
	for mineral_data in _visual_minerals:
		_draw_mineral(mineral_data["pos"], mineral_data["type"])

	# Draw count label if minerals are present
	if get_total_minerals() > 0:
		var label_pos = Vector2(0, -box_height * 0.5 - 20)
		var label_text = "Minerals: %d" % get_total_minerals()
		# Note: In production, you'd use a Label node, but for consistency with the codebase style
		# we're keeping it minimal

func _draw_mineral(pos: Vector2, type: GameState.MineralType) -> void:
	"""Draw a small mineral representation (diamond shape)"""
	var s = visual_mineral_size
	var pts = PackedVector2Array([
		pos + Vector2(0, -s),
		pos + Vector2(s, 0),
		pos + Vector2(0, s),
		pos + Vector2(-s, 0),
		pos + Vector2(0, -s)
	])

	var color = MINERAL_COLORS.get(type, Color.WHITE)
	draw_polyline(pts, color, 1.0)

func _process(_delta: float) -> void:
	# Periodically update visual if needed
	pass
