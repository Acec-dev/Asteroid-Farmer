extends Node2D

@export var player_scene: PackedScene
@export var asteroid_scene: PackedScene
@export var floating_text: PackedScene

# Mineral deposit box settings
@export var spawn_deposit_box: bool = false  # Toggle deposit box on/off
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

# Run timer
var _run_time: float = 0.0
var _run_timer_label: Label
var _last_difficulty_level: int = 1  # Track to avoid repeated updates

# Voyage progress indicator (shown in graph menu area)
var _voyage_bar_container: PanelContainer
var _voyage_bar_fill: ColorRect
var _voyage_bar_label: Label
var _voyage_bar_bg: ColorRect

signal spawn_text

func _ready() -> void:
	randomize()
	_spawn_player()

	# Setup asteroid spawner component
	_setup_asteroid_spawner()

	if spawn_deposit_box:
		_spawn_deposit_box()

	GameState.new_pickup.connect(Callable(self, "_spawn_text"))
	GameState.cargo_full.connect(_on_cargo_full)

	# Initialize camera boundary system
	var radar_cam = $Radar
	if radar_cam:
		ScreenUtils.set_main_camera(radar_cam)

	# Create upgrade panel
	_create_upgrade_panel()

	# Create run timer label at top center
	_create_run_timer_label()

	# Create voyage progress bar for graph menu
	_create_voyage_progress_bar()
	GameState.voyage_progress_updated.connect(_on_voyage_progress)
	GameState.voyage_started.connect(_on_voyage_started)
	GameState.voyage_completed.connect(_on_voyage_completed)

func _process(delta: float) -> void:
	_run_time += delta
	# Update timer display
	if _run_timer_label:
		var minutes := int(_run_time) / 60
		var seconds := int(_run_time) % 60
		_run_timer_label.text = "%d:%02d" % [minutes, seconds]

	# Auto-increase difficulty based on elapsed time
	# Level 1 (Normal) at start, then escalate every 60 seconds
	var target_level := clampi(1 + int(_run_time / 60.0), 0, 4)
	if target_level != _last_difficulty_level:
		_last_difficulty_level = target_level
		GameState.set_spawner_difficulty(target_level)

func _create_run_timer_label() -> void:
	_run_timer_label = Label.new()
	_run_timer_label.text = "0:00"
	_run_timer_label.add_theme_font_size_override("font_size", 20)
	_run_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_timer_label.anchors_preset = Control.PRESET_CENTER_TOP
	_run_timer_label.anchor_left = 0.5
	_run_timer_label.anchor_right = 0.5
	_run_timer_label.anchor_top = 0.0
	_run_timer_label.anchor_bottom = 0.0
	_run_timer_label.offset_left = -50
	_run_timer_label.offset_right = 50
	_run_timer_label.offset_top = 10
	_run_timer_label.offset_bottom = 40
	$CanvasLayer.add_child(_run_timer_label)

func _spawn_player() -> void:
	_player = player_scene.instantiate()
	_player.global_position = get_viewport_rect().size * 0.5
	add_child(_player)
	player_cam = _player.find_child("PlayerCam")

	# Add shield bar as child of player (follows in world space)
	var shield_bar_script = load("res://Scripts/shield_bar.gd")
	var shield_bar = Node2D.new()
	shield_bar.set_script(shield_bar_script)
	shield_bar.name = "ShieldBar"
	_player.add_child(shield_bar)

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

func _on_cargo_full() -> void:
	if _player and _player.has_method("popup_cargo_full"):
		_player.popup_cargo_full()

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

# === Voyage Progress Bar (in graph menu area) ===

func _create_voyage_progress_bar() -> void:
	# Small black & white bar attached to the top edge of the graphs panel
	_voyage_bar_container = PanelContainer.new()
	_voyage_bar_container.name = "VoyageProgressBar"

	# Sit just above the graphs panel (which starts at anchor_top 0.7222)
	_voyage_bar_container.anchor_left = 0.35
	_voyage_bar_container.anchor_right = 0.65
	_voyage_bar_container.anchor_top = 0.695
	_voyage_bar_container.anchor_bottom = 0.72
	_voyage_bar_container.offset_left = 0
	_voyage_bar_container.offset_right = 0
	_voyage_bar_container.offset_top = 0
	_voyage_bar_container.offset_bottom = 0

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	stylebox.border_color = Color(0.6, 0.6, 0.6)
	stylebox.set_border_width_all(1)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(3)
	_voyage_bar_container.add_theme_stylebox_override("panel", stylebox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	_voyage_bar_container.add_child(hbox)

	_voyage_bar_label = Label.new()
	_voyage_bar_label.text = "VOYAGE 0%"
	_voyage_bar_label.add_theme_font_size_override("font_size", 10)
	_voyage_bar_label.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(_voyage_bar_label)

	# Bar background
	var bar_holder = Control.new()
	bar_holder.custom_minimum_size = Vector2(0, 8)
	bar_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(bar_holder)

	_voyage_bar_bg = ColorRect.new()
	_voyage_bar_bg.color = Color(0.15, 0.15, 0.15)
	_voyage_bar_bg.anchor_right = 1.0
	_voyage_bar_bg.anchor_bottom = 1.0
	bar_holder.add_child(_voyage_bar_bg)

	_voyage_bar_fill = ColorRect.new()
	_voyage_bar_fill.color = Color.WHITE
	_voyage_bar_fill.anchor_right = 0.0
	_voyage_bar_fill.anchor_bottom = 1.0
	bar_holder.add_child(_voyage_bar_fill)

	_voyage_bar_container.visible = VoyageManager.voyage_active
	$CanvasLayer.add_child(_voyage_bar_container)

func _on_voyage_progress(progress: float) -> void:
	if _voyage_bar_container:
		_voyage_bar_container.visible = true
	if _voyage_bar_fill:
		_voyage_bar_fill.anchor_right = progress
	if _voyage_bar_label:
		var remaining = VoyageManager.voyage_duration - VoyageManager.voyage_elapsed
		_voyage_bar_label.text = "VOYAGE %d%% (%ds)" % [int(progress * 100), ceili(remaining)]

func _on_voyage_started() -> void:
	if _voyage_bar_container:
		_voyage_bar_container.visible = true
	if _voyage_bar_fill:
		_voyage_bar_fill.anchor_right = 0.0

func _on_voyage_completed(_results: Dictionary) -> void:
	if _voyage_bar_container:
		_voyage_bar_container.visible = false

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

func _on_debug_toggle_pressed() -> void:
	var container = $CanvasLayer/ButtonContainer/DebugContainer
	var toggle_btn = $CanvasLayer/ButtonContainer/DebugToggle
	container.visible = not container.visible
	toggle_btn.text = "DEBUG v" if container.visible else "DEBUG >"


func _on_give_money_pressed() -> void:
	GameState.add_credits(100)
