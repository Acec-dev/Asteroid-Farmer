extends Area2D

signal mineral_pickup

@export var value: int = 1
@export var drift: float = 40.0
@export var magnet_range: float = 150.0  # Distance at which magnetism starts working
@export var magnet_strength: float = 80.0  # How strong the pull is
var _life := 8.0

var minerals := ["iron", "nickel", "silica"]

@export var kind: StringName = minerals.pick_random()

var _player: Node2D = null

func _get_kind():
	return kind

func _ready() -> void:
	add_to_group("mineral")
	
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)
	queue_redraw()
	
	# Find the player
	_find_player()

func _find_player() -> void:
	# Look for player in the scene
	var root = get_tree().current_scene
	for child in root.get_children():
		if child.name == "Player" or child.has_method("popup_mineral"):
			_player = child
			break

func _process(delta: float) -> void:
	# Random drift
	var movement = Vector2(randf_range(-1,1), randf_range(-1,1)) * drift * delta
	
	# Magnetic attraction to player
	if _player and is_instance_valid(_player):
		var distance_to_player = global_position.distance_to(_player.global_position)
		
		if distance_to_player < magnet_range:
			# Calculate pull strength (stronger when closer)
			var pull_factor = 1.0 - (distance_to_player / magnet_range)
			var direction_to_player = ((_player.global_position - global_position).normalized())
			
			# Add magnetic pull to movement
			movement += direction_to_player * magnet_strength * pull_factor * delta
	
	position += movement
	
	# Lifetime
	_life -= delta
	if _life <= 0:
		queue_free()

func _draw() -> void:
	# Simple diamond glyph
	var s := 4.0
	var pts = [Vector2(0,-s), Vector2(s,0), Vector2(0,s), Vector2(-s,0), Vector2(0,-s)]
	draw_polyline(pts, Color.WHITE, 1.5)

func _collect() -> void:
	GameState.add_mat(kind)
	GameState.add_mineral(kind, value)
	queue_free()

func _on_area(a: Area2D) -> void:
	if a.is_in_group("player_pickup"):
		_collect()
		emit_signal("mineral_pickup")

func _on_body(_b: Node) -> void:
	# Not used, but kept for compatibility
	pass
