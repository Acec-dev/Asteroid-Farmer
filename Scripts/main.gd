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
var _voyage_bar_tween: Tween

# Voyage results display (visible on main scene)
var _voyage_results_label: Label
var _voyage_results_timer: float = 0.0
const VOYAGE_RESULTS_DISPLAY_TIME := 6.0

# Expedition progress indicator (shown in graph menu area)
var _expedition_bar_container: PanelContainer
var _expedition_bar_fill: ColorRect
var _expedition_bar_label: Label
var _expedition_bar_bg: ColorRect
var _expedition_bar_tween: Tween

# Go to Base button
var _base_panel: PanelContainer
var _base_btn: Button
var _base_countdown_label: Label
var _base_countdown_active: bool = false
var _base_countdown_time: float = 0.0
var _base_btn_tween: Tween
const BASE_COUNTDOWN_DURATION := 5.0

signal spawn_text

func _ready() -> void:
	randomize()
	_run_time = GameState.run_time
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

	# Create expedition progress bar for graph menu
	_create_expedition_progress_bar()
	GameState.expedition_progress_updated.connect(_on_expedition_progress)
	GameState.expedition_started.connect(_on_expedition_started)
	GameState.expedition_completed.connect(_on_expedition_completed)

	# Create styled "Go to Base!" button
	_create_base_button()

func _process(delta: float) -> void:
	_run_time += delta
	GameState.run_time = _run_time
	# Update timer display
	if _run_timer_label:
		var minutes := int(_run_time) / 60
		var seconds := int(_run_time) % 60
		_run_timer_label.text = "%d:%02d" % [minutes, seconds]

	# Auto-increase difficulty based on elapsed time
	# Level 1 (Normal) at start, then escalate every 60 seconds (no cap)
	var target_level := maxi(1 + int(_run_time / 60.0), 0)
	if target_level != _last_difficulty_level:
		_last_difficulty_level = target_level
		GameState.set_spawner_difficulty(target_level)

	# Base countdown
	if _base_countdown_active:
		_base_countdown_time -= delta
		if _base_countdown_time <= 0.0:
			_base_countdown_active = false
			SaveManager.save_game()
			get_tree().change_scene_to_file("res://Scenes/base.tscn")
		elif _base_countdown_label:
			_base_countdown_label.text = "Traveling to base... %ds" % ceili(_base_countdown_time)
	
  # Voyage results display timer
	if _voyage_results_timer > 0.0:
		_voyage_results_timer -= delta
		if _voyage_results_timer <= 0.0 and _voyage_results_label:
			_voyage_results_label.text = ""
			_voyage_results_label.visible = false

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
	# Don't show the mineral name popup when over-encumbered;
	# the cargo_full signal already shows "OVER-ENCUMBERED"
	if GameState.is_over_encumbered():
		return
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

# === Go to Base Button ===

func _create_base_button() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_base_panel = PanelContainer.new()
	_base_panel.name = "BaseButtonPanel"

	# Top center-right, starts off-screen above
	_base_panel.anchor_left = 0.6
	_base_panel.anchor_right = 0.75
	_base_panel.anchor_top = -0.06
	_base_panel.anchor_bottom = -0.01
	_base_panel.offset_left = 0
	_base_panel.offset_right = 0
	_base_panel.offset_top = 0
	_base_panel.offset_bottom = 0

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 1)
	panel_style.border_color = Color(0.6, 0.6, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin_all(4)
	_base_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_base_panel.add_child(vbox)

	_base_btn = Button.new()
	_base_btn.text = "Go to Base!"
	_base_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_base_button_style(_base_btn, mono_font, 14)
	_base_btn.pressed.connect(_on_go_to_base_pressed)
	vbox.add_child(_base_btn)

	_base_countdown_label = Label.new()
	_base_countdown_label.text = ""
	_base_countdown_label.visible = false
	_base_countdown_label.add_theme_font_size_override("font_size", 11)
	_base_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_base_countdown_label.add_theme_font_override("font", mono_font)
	_base_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_base_countdown_label)

	$CanvasLayer.add_child(_base_panel)

func _on_go_to_base_pressed() -> void:
	_base_countdown_active = true
	_base_countdown_time = BASE_COUNTDOWN_DURATION
	_base_btn.visible = false
	if _base_countdown_label:
		_base_countdown_label.visible = true
		_base_countdown_label.text = "Traveling to base... %ds" % ceili(_base_countdown_time)

func _apply_base_button_style(btn: Button, font: Font, font_size: int) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.7))
	if font:
		btn.add_theme_font_override("font", font)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 1)
	normal.border_color = Color(0.6, 0.6, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.1, 0.1, 0.1, 1)
	hover.border_color = Color.WHITE
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(0)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.2, 0.2, 0.2, 1)
	pressed.border_color = Color.WHITE
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(0)
	pressed.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", focus)

# === Voyage Progress Bar (in graph menu area) ===

func _create_voyage_progress_bar() -> void:
	# Small black & white bar attached to the top edge of the graphs panel
	_voyage_bar_container = PanelContainer.new()
	_voyage_bar_container.name = "VoyageProgressBar"

	# Anchored just above the graphs panel (which starts at anchor_top 0.7222)
	# Start off-screen to the left (matching graphs panel hidden state)
	_voyage_bar_container.anchor_left = -0.65
	_voyage_bar_container.anchor_right = -0.35
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

	# Voyage results label (shown at top-center when a voyage completes)
	_voyage_results_label = Label.new()
	_voyage_results_label.name = "VoyageResultsLabel"
	_voyage_results_label.text = ""
	_voyage_results_label.visible = false
	_voyage_results_label.add_theme_font_size_override("font_size", 16)
	_voyage_results_label.add_theme_color_override("font_color", Color.WHITE)
	_voyage_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voyage_results_label.anchor_left = 0.25
	_voyage_results_label.anchor_right = 0.75
	_voyage_results_label.anchor_top = 0.05
	_voyage_results_label.anchor_bottom = 0.15
	_voyage_results_label.offset_left = 0
	_voyage_results_label.offset_right = 0
	_voyage_results_label.offset_top = 0
	_voyage_results_label.offset_bottom = 0
	$CanvasLayer.add_child(_voyage_results_label)

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

func _on_voyage_completed(results: Dictionary) -> void:
	if _voyage_bar_container:
		_voyage_bar_container.visible = false

	# Show results message on main scene
	var total_minerals := 0
	for type in results.minerals_gained:
		total_minerals += results.minerals_gained[type]

	var result_text = "Voyage complete! "
	result_text += "%d/%d drones returned" % [results.drones_survived, results.drones_sent]
	if results.drones_lost > 0:
		result_text += " | %d lost" % results.drones_lost
	result_text += " | +%d minerals" % total_minerals

	if _voyage_results_label:
		_voyage_results_label.text = result_text
		_voyage_results_label.visible = true
		_voyage_results_timer = VOYAGE_RESULTS_DISPLAY_TIME

# === Expedition Progress Bar (in graph menu area) ===

func _create_expedition_progress_bar() -> void:
	_expedition_bar_container = PanelContainer.new()
	_expedition_bar_container.name = "ExpeditionProgressBar"

	# Positioned just above the voyage bar
	_expedition_bar_container.anchor_left = -0.65
	_expedition_bar_container.anchor_right = -0.35
	_expedition_bar_container.anchor_top = 0.665
	_expedition_bar_container.anchor_bottom = 0.69
	_expedition_bar_container.offset_left = 0
	_expedition_bar_container.offset_right = 0
	_expedition_bar_container.offset_top = 0
	_expedition_bar_container.offset_bottom = 0

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	stylebox.border_color = Color(0.4, 0.6, 0.8)
	stylebox.set_border_width_all(1)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(3)
	_expedition_bar_container.add_theme_stylebox_override("panel", stylebox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	_expedition_bar_container.add_child(hbox)

	_expedition_bar_label = Label.new()
	_expedition_bar_label.text = "EXPEDITION 0%"
	_expedition_bar_label.add_theme_font_size_override("font_size", 10)
	_expedition_bar_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	hbox.add_child(_expedition_bar_label)

	var bar_holder = Control.new()
	bar_holder.custom_minimum_size = Vector2(0, 8)
	bar_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(bar_holder)

	_expedition_bar_bg = ColorRect.new()
	_expedition_bar_bg.color = Color(0.15, 0.15, 0.15)
	_expedition_bar_bg.anchor_right = 1.0
	_expedition_bar_bg.anchor_bottom = 1.0
	bar_holder.add_child(_expedition_bar_bg)

	_expedition_bar_fill = ColorRect.new()
	_expedition_bar_fill.color = Color(0.4, 0.7, 1.0)
	_expedition_bar_fill.anchor_right = 0.0
	_expedition_bar_fill.anchor_bottom = 1.0
	bar_holder.add_child(_expedition_bar_fill)

	_expedition_bar_container.visible = ExpeditionManager.expedition_active
	$CanvasLayer.add_child(_expedition_bar_container)

func _on_expedition_progress(progress: float) -> void:
	if _expedition_bar_container:
		_expedition_bar_container.visible = true
	if _expedition_bar_fill:
		_expedition_bar_fill.anchor_right = progress
	if _expedition_bar_label:
		var remaining = ExpeditionManager.expedition_duration - ExpeditionManager.expedition_elapsed
		_expedition_bar_label.text = "EXPEDITION %d%% (%ds)" % [int(progress * 100), ceili(remaining)]

func _on_expedition_started() -> void:
	if _expedition_bar_container:
		_expedition_bar_container.visible = true
	if _expedition_bar_fill:
		_expedition_bar_fill.anchor_right = 0.0

func _on_expedition_completed(results: Dictionary) -> void:
	if _expedition_bar_container:
		_expedition_bar_container.visible = false

	# Show results message on main scene
	var total_minerals := 0
	for type in results.minerals_gained:
		total_minerals += results.minerals_gained[type]

	var result_text = "Expedition complete! "
	result_text += "%d/%d drones returned" % [results.drones_survived, results.drones_sent]
	if results.drones_lost > 0:
		result_text += " | %d lost" % results.drones_lost
	result_text += " | +%d exotic minerals" % total_minerals

	if _voyage_results_label:
		_voyage_results_label.text = result_text
		_voyage_results_label.visible = true
		_voyage_results_timer = VOYAGE_RESULTS_DISPLAY_TIME

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
		_slide_voyage_bar_in()
		_slide_expedition_bar_in()
		_slide_base_btn_in()
		_zoom_camera_out()
	else:
		graphs_panel.slide_out()
		_upgrade_panel.slide_out()
		_slide_voyage_bar_out()
		_slide_expedition_bar_out()
		_slide_base_btn_out()
		_zoom_camera_in()

func _slide_voyage_bar_in() -> void:
	if not _voyage_bar_container:
		return
	if _voyage_bar_tween:
		_voyage_bar_tween.kill()
	_voyage_bar_tween = create_tween()
	_voyage_bar_tween.set_ease(Tween.EASE_OUT)
	_voyage_bar_tween.set_trans(Tween.TRANS_CUBIC)
	_voyage_bar_tween.set_parallel(true)
	_voyage_bar_tween.tween_property(_voyage_bar_container, "anchor_left", 0.35, menu_slide_duration)
	_voyage_bar_tween.tween_property(_voyage_bar_container, "anchor_right", 0.65, menu_slide_duration)

func _slide_voyage_bar_out() -> void:
	if not _voyage_bar_container:
		return
	if _voyage_bar_tween:
		_voyage_bar_tween.kill()
	_voyage_bar_tween = create_tween()
	_voyage_bar_tween.set_ease(Tween.EASE_IN)
	_voyage_bar_tween.set_trans(Tween.TRANS_CUBIC)
	_voyage_bar_tween.set_parallel(true)
	_voyage_bar_tween.tween_property(_voyage_bar_container, "anchor_left", -0.65, menu_slide_duration)
	_voyage_bar_tween.tween_property(_voyage_bar_container, "anchor_right", -0.35, menu_slide_duration)

func _slide_expedition_bar_in() -> void:
	if not _expedition_bar_container:
		return
	if _expedition_bar_tween:
		_expedition_bar_tween.kill()
	_expedition_bar_tween = create_tween()
	_expedition_bar_tween.set_ease(Tween.EASE_OUT)
	_expedition_bar_tween.set_trans(Tween.TRANS_CUBIC)
	_expedition_bar_tween.set_parallel(true)
	_expedition_bar_tween.tween_property(_expedition_bar_container, "anchor_left", 0.35, menu_slide_duration)
	_expedition_bar_tween.tween_property(_expedition_bar_container, "anchor_right", 0.65, menu_slide_duration)

func _slide_expedition_bar_out() -> void:
	if not _expedition_bar_container:
		return
	if _expedition_bar_tween:
		_expedition_bar_tween.kill()
	_expedition_bar_tween = create_tween()
	_expedition_bar_tween.set_ease(Tween.EASE_IN)
	_expedition_bar_tween.set_trans(Tween.TRANS_CUBIC)
	_expedition_bar_tween.set_parallel(true)
	_expedition_bar_tween.tween_property(_expedition_bar_container, "anchor_left", -0.65, menu_slide_duration)
	_expedition_bar_tween.tween_property(_expedition_bar_container, "anchor_right", -0.35, menu_slide_duration)

func _slide_base_btn_in() -> void:
	if not _base_panel:
		return
	if _base_btn_tween:
		_base_btn_tween.kill()
	_base_btn_tween = create_tween()
	_base_btn_tween.set_ease(Tween.EASE_OUT)
	_base_btn_tween.set_trans(Tween.TRANS_CUBIC)
	_base_btn_tween.set_parallel(true)
	_base_btn_tween.tween_property(_base_panel, "anchor_top", 0.01, menu_slide_duration)
	_base_btn_tween.tween_property(_base_panel, "anchor_bottom", 0.06, menu_slide_duration)

func _slide_base_btn_out() -> void:
	if not _base_panel:
		return
	if _base_btn_tween:
		_base_btn_tween.kill()
	_base_btn_tween = create_tween()
	_base_btn_tween.set_ease(Tween.EASE_IN)
	_base_btn_tween.set_trans(Tween.TRANS_CUBIC)
	_base_btn_tween.set_parallel(true)
	_base_btn_tween.tween_property(_base_panel, "anchor_top", -0.06, menu_slide_duration)
	_base_btn_tween.tween_property(_base_panel, "anchor_bottom", -0.01, menu_slide_duration)

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


func _on_bank_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/bank.tscn")
