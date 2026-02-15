extends Node2D

@onready var purchased_silo = false
@onready var purchased_drill = false
@onready var base_sprite = $BaseSprite
@onready var camera = $Camera2D
@onready var drill_timer = $DrillTimer
@onready var fuel_capacity = 0

# Docked ship visual
var _ship_node: Node2D
var _ship_rest_pos: Vector2
var _bob_time: float = 0.0
const BOB_AMPLITUDE := 4.0  # pixels up/down
const BOB_SPEED := 1.5  # cycles per second
const FLY_IN_DURATION := 1.2  # seconds

func _ready() -> void:
	_spawn_docked_ship()

func _spawn_docked_ship() -> void:
	var viewport_size = get_viewport_rect().size

	# Rest position: upper-right quadrant
	_ship_rest_pos = Vector2(viewport_size.x * 0.35, viewport_size.y * -0.22)

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

func _process(delta: float) -> void:
	if _ship_node:
		_bob_time += delta
		_ship_node.position.y = _ship_rest_pos.y + sin(_bob_time * BOB_SPEED * TAU) * BOB_AMPLITUDE

func _on_silo_button_pressed() -> void:
	if purchased_drill == true:
		base_sprite.texture = load("res://Assets/complete planet.png")
	else:
		base_sprite.texture = load("res://Assets/planet+fuel.png")
	purchased_silo = true


func _on_drill_button_pressed() -> void:
	if purchased_silo == true:
		base_sprite.texture = load("res://Assets/complete planet.png")
	else:
		base_sprite.texture = load("res://Assets/planet+drill.png")
	purchased_drill = true
	drill_timer.start()


func _on_drill_timer_timeout() -> void:
	if fuel_capacity < 100:
		fuel_capacity += 1
		print("Fuel at " + str(fuel_capacity) + "%")


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


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
