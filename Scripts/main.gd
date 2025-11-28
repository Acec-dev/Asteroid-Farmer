extends Node2D

@export var player_scene: PackedScene
@export var asteroid_scene: PackedScene
@export var floating_text: PackedScene

# Mineral deposit box settings
@export var spawn_deposit_box: bool = true  # Toggle deposit box on/off
@export var deposit_box_position: Vector2 = Vector2(640, 600)  # Bottom center by default

# Use new asteroid spawner component
var asteroid_spawner: AsteroidSpawner = null

@onready var player_cam = Camera2D

@onready var mineral_name = GameState.get_mat()
var _player: Node2D
var _deposit_box: Node2D = null

signal spawn_text

func _ready() -> void:
	randomize()
	_spawn_player()

	# Setup asteroid spawner component
	_setup_asteroid_spawner()

	if spawn_deposit_box:
		_spawn_deposit_box()

	GameState.new_pickup.connect(Callable(self, "_spawn_text"))

func _spawn_player() -> void:
	"""Instatiates player and initializes PlayerCam"""
	_player = player_scene.instantiate()
	_player.global_position = get_viewport_rect().size * 0.5
	add_child(_player)
	player_cam = _player.find_child("PlayerCam")

func _setup_asteroid_spawner() -> void:
	"""Setup the modular asteroid spawner component"""
	asteroid_spawner = AsteroidSpawner.new()
	asteroid_spawner.name = "AsteroidSpawner"
	asteroid_spawner.asteroid_scene = asteroid_scene
	asteroid_spawner.player = _player
	asteroid_spawner.camera = player_cam

	# Configure spawner (can be overridden by GameState)
	asteroid_spawner.trajectory_mode = AsteroidSpawner.TrajectoryMode.RANDOM_ACROSS

	add_child(asteroid_spawner)

	# Spawner will auto-sync with GameState difficulty
	print("Main: Asteroid spawner initialized")

func _spawn_deposit_box() -> void:
	"""Spawn the mineral deposit box at the configured position"""
	var deposit_box_script = load("res://Scripts/mineral_deposit_box.gd")
	_deposit_box = Area2D.new()
	_deposit_box.set_script(deposit_box_script)
	_deposit_box.global_position = deposit_box_position
	add_child(_deposit_box)
	print("Mineral deposit box spawned at: ", deposit_box_position)
	print("Fly over the box and press E or Space to deposit minerals!")

func _spawn_text():
	_player.popup_mineral(GameState.MINERAL_NAMES[GameState.current_mat])
	emit_signal("spawn_text")
	
func _get_player_pos():
	return Vector2(_player.global_position)


func _on_rockets_button_pressed() -> void:
	print("Upgraded to rockets")
	GameState.unlock_weapon("Rocket Launcher")

func _on_laser_button_pressed() -> void:
	print("Upgraded to laser")
	GameState.unlock_weapon("Laser Beam")

func _on_base_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/base.tscn")

func _on_explore_button_pressed() -> void:
	player_cam.enabled = true
