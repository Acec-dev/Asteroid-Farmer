extends Node2D

var _ship_node: Node2D
var _ship_rest_pos: Vector2
var _bob_time: float = 0.0
const BOB_AMPLITUDE := 4.0  # pixels up/down
const BOB_SPEED := 1.5  # cycles per second
const FLY_IN_DURATION := 1.2  # seconds

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_spawn_docked_ship()
	

func _spawn_docked_ship() -> void:
	var viewport_size = get_viewport_rect().size

	# Rest position: upper-left quadrant
	_ship_rest_pos = Vector2(viewport_size.x * -0.35, viewport_size.y * -0.18)

	# Start off-screen to the left
	var start_pos = Vector2(-viewport_size.x * 0.6, _ship_rest_pos.y + 40)

	_ship_node = Node2D.new()
	_ship_node.name = "DockedShip"
	_ship_node.position = start_pos
	add_child(_ship_node)

	# Draw the same triangle as the player ship
	var ship_draw = _ShipDrawer.new()
	_ship_node.add_child(ship_draw)

	# Fly-in tween
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_ship_node, "position", _ship_rest_pos, FLY_IN_DURATION)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _ship_node:
		_bob_time += delta
		_ship_node.position.y = _ship_rest_pos.y + sin(_bob_time * BOB_SPEED * TAU) * BOB_AMPLITUDE


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_base_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/base.tscn")


# Inner class that draws the player ship triangle

class _ShipDrawer extends Node2D:
	func _draw() -> void:
		var points = PackedVector2Array([
			Vector2(60, 0),
			Vector2(-20, -16),
			Vector2(-20, 16),
			Vector2(60, 0)
		])
		draw_polyline(points, Color.WHITE, 2.0)