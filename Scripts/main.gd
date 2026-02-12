extends Node2D

@export var player_scene: PackedScene
@export var asteroid_scene: PackedScene
@export var floating_text: PackedScene

# Mineral deposit box settings
@export var spawn_deposit_box: bool = true  # Toggle deposit box on/off
@export var deposit_box_position: Vector2 = Vector2(640, 600)  # Bottom center by default

# Menu system settings
@export var menu_zoom_amount: float = 0.75
@export var menu_slide_duration: float = 0.5

# Use new asteroid spawner component
var asteroid_spawner: AsteroidSpawner = null

@onready var player_cam = Camera2D

@onready var mineral_name = GameState.get_mat()
var _player: Node2D
var _deposit_box: Node2D = null

# Menu state
var _menus_open: bool = false
var _menu_tween: Tween
var _upgrade_panel: Node

signal spawn_text

func _ready() -> void:
	randomize()
	_spawn_player()

	# Setup asteroid spawner component
	_setup_asteroid_spawner()

	if spawn_deposit_box:
		_spawn_deposit_box()

	GameState.new_pickup.connect(Callable(self, "_spawn_text"))

	# Initialize camera boundary system
	var radar_cam = $Radar
	if radar_cam:
		ScreenUtils.set_main_camera(radar_cam)

	# Create upgrade panel
	_create_upgrade_panel()

func _spawn_player() -> void:
	_player = player_scene.instantiate()
	_player.global_position = get_viewport_rect().size * 0.5
	add_child(_player)
	player_cam = _player.find_child("PlayerCam")

func _setup_asteroid_spawner() -> void:
	asteroid_spawner = AsteroidSpawner.new()
	asteroid_spawner.name = "AsteroidSpawner"
	asteroid_spawner.asteroid_scene = asteroid_scene
	asteroid_spawner.player = _player
	asteroid_spawner.camera = player_cam

	asteroid_spawner.trajectory_mode = AsteroidSpawner.TrajectoryMode.RANDOM_ACROSS

	add_child(asteroid_spawner)
	print("Main: Asteroid spawner initialized")

func _spawn_deposit_box() -> void:
	var deposit_box_script = load("res://Scripts/mineral_deposit_box.gd")
	_deposit_box = Area2D.new()
	_deposit_box.set_script(deposit_box_script)
	_deposit_box.global_position = deposit_box_position
	add_child(_deposit_box)
	print("Mineral deposit box spawned at: ", deposit_box_position)

func _spawn_text():
	_player.popup_mineral(GameState.MINERAL_NAMES[GameState.current_mat])
	emit_signal("spawn_text")

func _get_player_pos():
	return Vector2(_player.global_position)

func _create_upgrade_panel() -> void:
	var upgrade_panel_script = load("res://Scripts/upgrade_panel.gd")
	_upgrade_panel = PanelContainer.new()
	_upgrade_panel.set_script(upgrade_panel_script)

	var theme = load("res://Assets/market_ui.tres")
	if theme:
		_upgrade_panel.theme = theme

	$CanvasLayer.add_child(_upgrade_panel)

# === Menu Toggle System ===

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle_menus()
		get_viewport().set_input_as_handled()

func _toggle_menus() -> void:
	_menus_open = !_menus_open

	var graphs_panel = $CanvasLayer/GraphsPanel

	if _menus_open:
		graphs_panel.slide_in()
		_upgrade_panel.slide_in()
		_zoom_camera_out()
	else:
		graphs_panel.slide_out()
		_upgrade_panel.slide_out()
		_zoom_camera_in()

func _zoom_camera_out() -> void:
	var radar = $Radar
	if not radar:
		return

	if _menu_tween:
		_menu_tween.kill()

	_menu_tween = create_tween()
	_menu_tween.set_ease(Tween.EASE_OUT)
	_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_menu_tween.set_parallel(true)

	var zoom_vec = Vector2(menu_zoom_amount, menu_zoom_amount)
	_menu_tween.tween_property(radar, "zoom", zoom_vec, menu_slide_duration)

	_menu_tween.tween_property(radar, "limit_left", -1280, menu_slide_duration)
	_menu_tween.tween_property(radar, "limit_right", 1280, menu_slide_duration)
	_menu_tween.tween_property(radar, "limit_top", -180, menu_slide_duration)
	_menu_tween.tween_property(radar, "limit_bottom", 1140, menu_slide_duration)

func _zoom_camera_in() -> void:
	var radar = $Radar
	if not radar:
		return

	if _menu_tween:
		_menu_tween.kill()

	_menu_tween = create_tween()
	_menu_tween.set_ease(Tween.EASE_IN)
	_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_menu_tween.set_parallel(true)

	_menu_tween.tween_property(radar, "zoom", Vector2(1.0, 1.0), menu_slide_duration)

	ScreenUtils.restore_boundaries(menu_slide_duration)

# === Button Callbacks ===

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

func _on_mine_button_pressed() -> void:
	print("Upgraded to mines")
	GameState.unlock_weapon("Mine Layer")

func _on_graph_button_pressed() -> void:
	_toggle_menus()
