extends Node2D

@export var player_scene: PackedScene
@export var asteroid_scene: PackedScene
@export var small_asteroid_scene: PackedScene
@export var mineral_scene: PackedScene
@export var floating_text: PackedScene

# Tunables for the new behavior
@export var spawn_ring_radius: float = 900.0  # how far from the player to spawn
@export var spawn_ring_jitter: float = 120.0  # randomize radius a bit
@export var band_half_size: Vector2 = Vector2(160, 120)  # “middle band” around screen center
@export var asteroid_speed_range: Vector2 = Vector2(220, 360) # min/max straight speed

@onready var _spawn_timer := $SpawnTimer as Timer
@onready var rocket_button = $CanvasLayer/InventoryMenu/RocketsButton

@onready var mineral_name = GameState.get_mat()
var _player: Node2D

signal spawn_text

func _ready() -> void:
	randomize()
	_spawn_timer.timeout.connect(_spawn_asteroid)
	_spawn_timer.start()
	_spawn_player()
	
	GameState.new_pickup.connect(Callable(self, "_spawn_text"))

func _spawn_player() -> void:
	_player = player_scene.instantiate()
	_player.global_position = get_viewport_rect().size * 0.5
	add_child(_player)

func _spawn_asteroid() -> void:
	if not asteroid_scene or _player == null:
		return

	# 1) Pick a spawn point in a ring AROUND THE PLAYER
	var ang := randf() * TAU
	var r := spawn_ring_radius + randf_range(-spawn_ring_jitter, spawn_ring_jitter)
	var spawn_pos := _player.global_position + Vector2.RIGHT.rotated(ang) * r

	# 2) Pick a target point inside a “middle band”
	var band_point := _player.global_position + Vector2(
		randf_range(-band_half_size.x, band_half_size.x),
		randf_range(-band_half_size.y, band_half_size.y)
	)

	# 3) Spawn and set its straight-line motion so the line passes through that band
	var a: RigidBody2D = asteroid_scene.instantiate()
	add_child(a)
	if small_asteroid_scene:
		a.child_scene = small_asteroid_scene
	if mineral_scene:
		a.mineral_drop_scene = mineral_scene

	var speed := randf_range(asteroid_speed_range.x, asteroid_speed_range.y)
	# Call our new initializer on the asteroid
	a.setup_motion(spawn_pos, band_point, speed)
	
func _spawn_text():
	_player.popup_mineral(GameState.current_mat)
	emit_signal("spawn_text")
	
func _get_player_pos():
	return Vector2(_player.global_position)


func _on_rockets_button_pressed() -> void:
	print("Upgraded to rockets")
	_player.enable_rockets()
