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

# Drone visuals
var _drone_container: Node2D
var _drone_nodes: Array[Node2D] = []
const DRONE_AREA_CENTER := Vector2(480, -330)  # Top-right quadrant
const DRONE_SPACING := 50.0
const DRONE_BOB_AMPLITUDE := 3.0
const DRONE_BOB_SPEED := 1.2
const DRONE_SCALE := 0.4

# Panel layout — tweak these to reposition the menus
const RIGHT_MENU_WIDTH := 280.0
const RIGHT_MENU_PADDING := 20.0
const RIGHT_MENU_TOP_OFFSET := 60.0
const RIGHT_MENU_SPACING := 12

# Right-side menu container
var _right_menu: VBoxContainer

# Voyage UI
var _voyage_panel: PanelContainer
var _voyage_progress_bar: Control
var _voyage_progress_label: Label
var _voyage_drone_count_label: Label
var _buy_voyage_drone_btn: Button
var _voyage_results_label: Label
var _results_timer: float = 0.0
const RESULTS_DISPLAY_TIME := 5.0

# Expedition UI
var _expedition_panel: PanelContainer
var _expedition_progress_bar: Control
var _expedition_progress_label: Label
var _expedition_drone_count_label: Label
var _buy_expedition_drone_btn: Button
var _expedition_results_timer: float = 0.0

# Drone upgrades UI
var _upgrades_panel: PanelContainer
var _exotic_labels: Dictionary = {}
var _upgrade_btns: Dictionary = {}

# Wallet display
var _wallet_label: Label
var _vault_label: Label

# Mission history panel
var _history_panel: PanelContainer

func _ready() -> void:
	_spawn_docked_ship()
	_spawn_drone_visuals()
	_build_wallet_display()
	_build_drone_ui()
	_build_right_side_menu()
	_build_voyage_ui()
	_build_expedition_ui()
	_build_drone_upgrades_ui()
	_build_mission_history_panel()

	GameState.voyage_drones_changed.connect(_on_voyage_drones_changed)
	GameState.expedition_drones_changed.connect(_on_expedition_drones_changed)
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.voyage_started.connect(_on_voyage_started)
	GameState.voyage_completed.connect(_on_voyage_completed)
	GameState.voyage_progress_updated.connect(_on_voyage_progress)
	GameState.expedition_started.connect(_on_expedition_started)
	GameState.expedition_completed.connect(_on_expedition_completed)
	GameState.expedition_progress_updated.connect(_on_expedition_progress)
	GameState.exotic_minerals_changed.connect(_on_exotic_minerals_changed)
	GameState.drone_upgrades_changed.connect(_on_drone_upgrades_changed)
	GameState.bank_balance_changed.connect(_on_bank_balance_changed)

	_refresh_drone_visuals()
	_refresh_ui()

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

func _process(delta: float) -> void:
	if _ship_node:
		_bob_time += delta
		_ship_node.position.y = _ship_rest_pos.y + sin(_bob_time * BOB_SPEED * TAU) * BOB_AMPLITUDE

	# Bob drone visuals
	for i in range(_drone_nodes.size()):
		var drone = _drone_nodes[i]
		if drone and is_instance_valid(drone):
			var base_pos: Vector2 = drone.get_meta("base_pos")
			var phase: float = drone.get_meta("phase")
			drone.position.y = base_pos.y + sin((_bob_time * DRONE_BOB_SPEED + phase) * TAU) * DRONE_BOB_AMPLITUDE

	# Voyage results display timer
	if _results_timer > 0.0:
		_results_timer -= delta
		if _results_timer <= 0.0 and _voyage_results_label:
			_voyage_results_label.text = ""

# === DRONE VISUALS ===

func _spawn_drone_visuals() -> void:
	_drone_container = Node2D.new()
	_drone_container.name = "DroneContainer"
	_drone_container.position = DRONE_AREA_CENTER
	add_child(_drone_container)

func _refresh_drone_visuals() -> void:
	# Clear existing drones
	for drone in _drone_nodes:
		if is_instance_valid(drone):
			drone.queue_free()
	_drone_nodes.clear()

	_drone_container.visible = true

	# Show voyage drones on the left, expedition drones on the right
	var voyage_count = GameState.voyage_drone_count if not VoyageManager.voyage_active else 0
	var expedition_count = GameState.expedition_drone_count if not ExpeditionManager.expedition_active else 0

	# Voyage drones (left side, white)
	if voyage_count > 0:
		var cols = ceili(sqrt(float(voyage_count)))
		for i in range(voyage_count):
			var col = i % cols
			@warning_ignore("integer_division")
			var row = i / cols
			var pos = Vector2(col * DRONE_SPACING - (cols - 1) * DRONE_SPACING * 0.5 - 80, row * DRONE_SPACING)

			var drone_node = Node2D.new()
			drone_node.position = pos
			drone_node.scale = Vector2(DRONE_SCALE, DRONE_SCALE)
			drone_node.set_meta("base_pos", pos)
			drone_node.set_meta("phase", randf() * TAU)

			var drawer = _DroneDrawer.new()
			drone_node.add_child(drawer)
			_drone_container.add_child(drone_node)
			_drone_nodes.append(drone_node)

	# Expedition drones (right side, blue tint)
	if expedition_count > 0:
		var cols = ceili(sqrt(float(expedition_count)))
		for i in range(expedition_count):
			var col = i % cols
			@warning_ignore("integer_division")
			var row = i / cols
			var pos = Vector2(col * DRONE_SPACING - (cols - 1) * DRONE_SPACING * 0.5 + 80, row * DRONE_SPACING)

			var drone_node = Node2D.new()
			drone_node.position = pos
			drone_node.scale = Vector2(DRONE_SCALE, DRONE_SCALE)
			drone_node.set_meta("base_pos", pos)
			drone_node.set_meta("phase", randf() * TAU)

			var drawer = _ExpeditionDroneDrawer.new()
			drone_node.add_child(drawer)
			_drone_container.add_child(drone_node)
			_drone_nodes.append(drone_node)

# === WALLET DISPLAY ===

func _build_wallet_display() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")
	var viewport_size = get_viewport_rect().size

	# Position at top-left corner of viewport
	var x_pos = -viewport_size.x * 0.5 + 16
	var y_pos = -viewport_size.y * 0.5 + 12

	# Credits line
	_wallet_label = Label.new()
	_wallet_label.text = "%d cr" % GameState.credits
	_wallet_label.add_theme_font_size_override("font_size", 18)
	_wallet_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_wallet_label.add_theme_font_override("font", mono_font)
	_wallet_label.position = Vector2(x_pos, y_pos)
	add_child(_wallet_label)

	# Vault line (smaller, below credits)
	_vault_label = Label.new()
	_vault_label.add_theme_font_size_override("font_size", 13)
	_vault_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	if mono_font:
		_vault_label.add_theme_font_override("font", mono_font)
	_vault_label.position = Vector2(x_pos, y_pos + 24)
	add_child(_vault_label)

	_refresh_wallet_display()

func _refresh_wallet_display() -> void:
	if _wallet_label:
		_wallet_label.text = "%d cr" % GameState.credits
	if _vault_label:
		if GameState.bank_balance > 0:
			_vault_label.text = "vault: %d cr" % GameState.bank_balance
		else:
			_vault_label.text = ""

# === UI BUILDING ===

func _build_drone_ui() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")
	var viewport_size = get_viewport_rect().size

	# Voyage drone count label (left side above drone area)
	_voyage_drone_count_label = Label.new()
	_voyage_drone_count_label.text = "Voyage: 0"
	_voyage_drone_count_label.add_theme_font_size_override("font_size", 16)
	_voyage_drone_count_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_voyage_drone_count_label.add_theme_font_override("font", mono_font)
	_voyage_drone_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voyage_drone_count_label.position = Vector2(DRONE_AREA_CENTER.x - 140, DRONE_AREA_CENTER.y - 50)
	add_child(_voyage_drone_count_label)

	# Expedition drone count label (right side above drone area)
	_expedition_drone_count_label = Label.new()
	_expedition_drone_count_label.text = "Expedition: 0"
	_expedition_drone_count_label.add_theme_font_size_override("font_size", 16)
	_expedition_drone_count_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	if mono_font:
		_expedition_drone_count_label.add_theme_font_override("font", mono_font)
	_expedition_drone_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_expedition_drone_count_label.position = Vector2(DRONE_AREA_CENTER.x + 20, DRONE_AREA_CENTER.y - 50)
	add_child(_expedition_drone_count_label)

	# Voyage results label (center-top of screen)
	_voyage_results_label = Label.new()
	_voyage_results_label.text = ""
	_voyage_results_label.add_theme_font_size_override("font_size", 18)
	_voyage_results_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_voyage_results_label.add_theme_font_override("font", mono_font)
	_voyage_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var label_width := 500.0
	_voyage_results_label.custom_minimum_size.x = label_width
	_voyage_results_label.position = Vector2(-label_width * 0.5, -viewport_size.y * 0.5 + 30)
	add_child(_voyage_results_label)

func _build_right_side_menu() -> void:
	var viewport_size = get_viewport_rect().size
	_right_menu = VBoxContainer.new()
	_right_menu.name = "RightSideMenu"
	_right_menu.add_theme_constant_override("separation", RIGHT_MENU_SPACING)
	_right_menu.custom_minimum_size.x = RIGHT_MENU_WIDTH
	# Position at the right edge of the viewport with padding
	_right_menu.position = Vector2(
		viewport_size.x * 0.5 - RIGHT_MENU_WIDTH - RIGHT_MENU_PADDING,
		-viewport_size.y * 0.5 + RIGHT_MENU_TOP_OFFSET
	)
	add_child(_right_menu)

func _build_voyage_ui() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	# Panel in the lower-right area for voyage controls
	_voyage_panel = PanelContainer.new()
	_voyage_panel.name = "VoyagePanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.6, 0.6, 0.6)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_voyage_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_voyage_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DRONE BAY"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.6, 0.6, 0.6)
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Buy voyage drone button
	_buy_voyage_drone_btn = Button.new()
	_buy_voyage_drone_btn.text = "Buy Voyage Drone (%dcr)" % GameState.DRONE_COST
	_apply_button_style(_buy_voyage_drone_btn, mono_font, 14)
	_buy_voyage_drone_btn.pressed.connect(_on_buy_voyage_drone_pressed)
	vbox.add_child(_buy_voyage_drone_btn)

	# Voyage section header
	var voyage_header = Label.new()
	voyage_header.text = "SEND ON VOYAGE"
	voyage_header.add_theme_font_size_override("font_size", 14)
	voyage_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	if mono_font:
		voyage_header.add_theme_font_override("font", mono_font)
	voyage_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(voyage_header)

	var sep2 = HSeparator.new()
	var sep2_style = StyleBoxFlat.new()
	sep2_style.bg_color = Color(0.6, 0.6, 0.6)
	sep2_style.set_content_margin_all(0)
	sep2_style.content_margin_top = 1
	sep2_style.content_margin_bottom = 1
	sep2.add_theme_stylebox_override("separator", sep2_style)
	vbox.add_child(sep2)

	# Voyage buttons with risk info
	for tier in VoyageManager.VoyageTier.values():
		var data = VoyageManager.get_tier_data(tier)
		var btn = Button.new()
		var duration_str = "%ds" % int(data.duration)
		var risk_str = "%d%% risk" % int(data.break_chance * 100)
		var reward_str = "%d-%d minerals" % [data.min_minerals, data.max_minerals]
		btn.text = "%s (%s, %s)" % [duration_str, risk_str, reward_str]
		_apply_button_style(btn, mono_font, 12)
		btn.name = "VoyageBtn_" + str(tier)
		btn.pressed.connect(_on_voyage_pressed.bind(tier))
		vbox.add_child(btn)

	# Progress bar area (hidden until voyage starts)
	_voyage_progress_bar = _VoyageProgressBar.new()
	_voyage_progress_bar.visible = false
	vbox.add_child(_voyage_progress_bar)

	_voyage_progress_label = Label.new()
	_voyage_progress_label.text = ""
	_voyage_progress_label.add_theme_font_size_override("font_size", 12)
	_voyage_progress_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_voyage_progress_label.add_theme_font_override("font", mono_font)
	_voyage_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_voyage_progress_label)

	# Add to the right-side menu (stacked with expedition below)
	_voyage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_menu.add_child(_voyage_panel)

func _apply_button_style(btn: Button, font: Font, font_size: int) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.7))
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.35))
	if font:
		btn.add_theme_font_override("font", font)

	# Normal state: black bg, white border
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 1)
	normal.border_color = Color(0.6, 0.6, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)

	# Hover state: slightly lighter border
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.1, 0.1, 0.1, 1)
	hover.border_color = Color.WHITE
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(0)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed state: inverted — white bg, black text
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.2, 0.2, 0.2, 1)
	pressed.border_color = Color.WHITE
	pressed.set_border_width_all(1)
	pressed.set_corner_radius_all(0)
	pressed.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Disabled state: dim
	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.05, 0.05, 0.05, 1)
	disabled.border_color = Color(0.25, 0.25, 0.25)
	disabled.set_border_width_all(1)
	disabled.set_corner_radius_all(0)
	disabled.set_content_margin_all(6)
	btn.add_theme_stylebox_override("disabled", disabled)

	# No focus outline
	var focus = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", focus)

func _build_expedition_ui() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_expedition_panel = PanelContainer.new()
	_expedition_panel.name = "ExpeditionPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.4, 0.6, 0.8)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_expedition_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_expedition_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "EXPEDITIONS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	_style_separator(sep)
	vbox.add_child(sep)

	# Info label
	var info = Label.new()
	info.text = "Send drones to find exotic minerals"
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if mono_font:
		info.add_theme_font_override("font", mono_font)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info)

	# Buy expedition drone button
	_buy_expedition_drone_btn = Button.new()
	_buy_expedition_drone_btn.text = "Buy Expedition Drone (%dcr)" % GameState.DRONE_COST
	_apply_button_style(_buy_expedition_drone_btn, mono_font, 14)
	_buy_expedition_drone_btn.pressed.connect(_on_buy_expedition_drone_pressed)
	vbox.add_child(_buy_expedition_drone_btn)

	var sep2_exp = HSeparator.new()
	_style_separator(sep2_exp)
	vbox.add_child(sep2_exp)

	# Expedition tier buttons
	for tier in ExpeditionManager.ExpeditionTier.values():
		var data = ExpeditionManager.get_tier_data(tier)
		var btn = Button.new()
		var duration_str = "%ds" % int(data.duration)
		var risk_str = "%d%% risk" % int(data.break_chance * 100)
		var reward_str = "%d-%d exotic" % [data.min_minerals, data.max_minerals]
		btn.text = "%s (%s, %s)" % [duration_str, risk_str, reward_str]
		_apply_button_style(btn, mono_font, 12)
		btn.name = "ExpeditionBtn_" + str(tier)
		btn.pressed.connect(_on_expedition_pressed.bind(tier))
		vbox.add_child(btn)

	# Progress bar (hidden until expedition starts)
	_expedition_progress_bar = _VoyageProgressBar.new()
	_expedition_progress_bar.visible = false
	vbox.add_child(_expedition_progress_bar)

	_expedition_progress_label = Label.new()
	_expedition_progress_label.text = ""
	_expedition_progress_label.add_theme_font_size_override("font_size", 12)
	_expedition_progress_label.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		_expedition_progress_label.add_theme_font_override("font", mono_font)
	_expedition_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_expedition_progress_label)

	# Add to the right-side menu (stacked below voyage panel)
	_expedition_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_menu.add_child(_expedition_panel)

func _build_drone_upgrades_ui() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_upgrades_panel = PanelContainer.new()
	_upgrades_panel.name = "DroneUpgradesPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.6, 0.5, 0.8)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_upgrades_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_upgrades_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DRONE UPGRADES"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	_style_separator(sep)
	vbox.add_child(sep)

	# Exotic mineral inventory display
	var inv_header = Label.new()
	inv_header.text = "EXOTIC MINERALS"
	inv_header.add_theme_font_size_override("font_size", 12)
	inv_header.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	if mono_font:
		inv_header.add_theme_font_override("font", mono_font)
	vbox.add_child(inv_header)

	for mineral_type in GameState.ExoticMineralType.values():
		var row = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = GameState.EXOTIC_MINERAL_NAMES[mineral_type].capitalize()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		if mono_font:
			name_label.add_theme_font_override("font", mono_font)
		row.add_child(name_label)

		var count_label = Label.new()
		count_label.name = "ExoticCount_" + str(mineral_type)
		count_label.text = "0"
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.custom_minimum_size.x = 40
		if mono_font:
			count_label.add_theme_font_override("font", mono_font)
		row.add_child(count_label)
		_exotic_labels[mineral_type] = count_label

		vbox.add_child(row)

	var sep2 = HSeparator.new()
	_style_separator(sep2)
	vbox.add_child(sep2)

	# Upgrade buttons
	var upgrade_display = {
		"drone_armor": "Drone Armor",
		"mineral_scanners": "Mineral Scanners",
		"fiber_optics": "Fiber Optics",
		"infrared_scanner": "Infrared Scanner",
	}

	for upgrade_name in GameState.drone_upgrades:
		var data = GameState.drone_upgrades[upgrade_name]
		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		# Name + level
		var header_row = HBoxContainer.new()
		var name_label = Label.new()
		name_label.text = upgrade_display.get(upgrade_name, upgrade_name)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		if mono_font:
			name_label.add_theme_font_override("font", mono_font)
		header_row.add_child(name_label)

		var level_label = Label.new()
		level_label.name = "UpgradeLevel_" + upgrade_name
		level_label.add_theme_font_size_override("font_size", 12)
		if mono_font:
			level_label.add_theme_font_override("font", mono_font)
		header_row.add_child(level_label)
		row.add_child(header_row)

		# Description
		var desc_label = Label.new()
		desc_label.text = data.description
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		if mono_font:
			desc_label.add_theme_font_override("font", mono_font)
		row.add_child(desc_label)

		# Buy button
		var btn = Button.new()
		btn.name = "UpgradeBtn_" + upgrade_name
		_apply_button_style(btn, mono_font, 11)
		btn.pressed.connect(_on_drone_upgrade_pressed.bind(upgrade_name))
		row.add_child(btn)
		_upgrade_btns[upgrade_name] = btn

		vbox.add_child(row)

	# Add to the right-side menu (stacked below expedition panel)
	_upgrades_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_menu.add_child(_upgrades_panel)

	_refresh_drone_upgrades_ui()

func _build_mission_history_panel() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")
	var viewport_size = get_viewport_rect().size

	_history_panel = PanelContainer.new()
	_history_panel.name = "MissionHistoryPanel"

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0, 0, 0, 1)
	stylebox.border_color = Color(0.5, 0.7, 0.5)
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(0)
	stylebox.set_content_margin_all(12)
	_history_panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	_history_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "MISSION LOG"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	if mono_font:
		title.add_theme_font_override("font", mono_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	_style_separator(sep)
	vbox.add_child(sep)

	# Combine voyage and expedition history, show most recent first
	var all_history: Array[Dictionary] = []
	for entry in GameState.voyage_history:
		all_history.append(entry)
	for entry in GameState.expedition_history:
		all_history.append(entry)

	if all_history.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No missions completed yet"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		if mono_font:
			empty_label.add_theme_font_override("font", mono_font)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_label)
	else:
		# Show up to 10 most recent entries
		var count = mini(all_history.size(), 10)
		for i in range(count):
			var entry = all_history[i]
			var line = Label.new()
			var type_str = entry.get("tier", "Unknown")
			var survived = entry.get("drones_survived", 0)
			var sent = entry.get("drones_sent", 0)
			var minerals = entry.get("minerals_gained", 0)
			var lost = entry.get("drones_lost", 0)
			var is_expedition = entry.get("type", "voyage") == "expedition"

			var text = "%s | %d/%d drones" % [type_str, survived, sent]
			if lost > 0:
				text += " (%d lost)" % lost
			if is_expedition:
				text += " | +%d exotic" % minerals
			else:
				text += " | +%d minerals" % minerals

			line.text = text
			line.add_theme_font_size_override("font_size", 10)
			if is_expedition:
				line.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
			else:
				line.add_theme_color_override("font_color", Color.WHITE)
			if mono_font:
				line.add_theme_font_override("font", mono_font)
			vbox.add_child(line)

	# Position at bottom-left of the viewport
	_history_panel.position = Vector2(
		-viewport_size.x * 0.5 + 16,
		viewport_size.y * 0.5 - 300
	)
	_history_panel.custom_minimum_size.x = 300
	add_child(_history_panel)

func _style_separator(sep: HSeparator) -> void:
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.6, 0.6, 0.6)
	sep_style.set_content_margin_all(0)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)

func _refresh_drone_upgrades_ui() -> void:
	# Update exotic mineral counts
	for mineral_type in GameState.ExoticMineralType.values():
		if _exotic_labels.has(mineral_type):
			_exotic_labels[mineral_type].text = str(GameState.exotic_minerals.get(mineral_type, 0))

	# Update upgrade buttons
	for upgrade_name in GameState.drone_upgrades:
		var data = GameState.drone_upgrades[upgrade_name]
		var btn = _upgrade_btns.get(upgrade_name)
		if not btn:
			continue

		var level_label = _upgrades_panel.find_child("UpgradeLevel_" + upgrade_name, true, false)
		if level_label:
			if data.level >= data.max_level:
				level_label.text = "MAX"
				level_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			else:
				level_label.text = "Lv.%d" % data.level
				level_label.add_theme_color_override("font_color", Color.WHITE)

		if data.level >= data.max_level:
			btn.text = "MAXED"
			btn.disabled = true
		else:
			var cost = data.costs[data.level]
			var cost_parts := []
			for mineral_type in cost:
				var mineral_name = GameState.EXOTIC_MINERAL_NAMES[mineral_type].capitalize()
				cost_parts.append("%d %s" % [cost[mineral_type], mineral_name])
			btn.text = "Upgrade: " + ", ".join(cost_parts)
			btn.disabled = not GameState.can_afford_drone_upgrade(upgrade_name)

func _refresh_ui() -> void:
	if _voyage_drone_count_label:
		_voyage_drone_count_label.text = "Voyage: %d" % GameState.voyage_drone_count

	if _expedition_drone_count_label:
		_expedition_drone_count_label.text = "Expedition: %d" % GameState.expedition_drone_count

	if _buy_voyage_drone_btn:
		_buy_voyage_drone_btn.disabled = GameState.credits < GameState.DRONE_COST

	if _buy_expedition_drone_btn:
		_buy_expedition_drone_btn.disabled = GameState.credits < GameState.DRONE_COST

	# Update voyage buttons
	var can_voyage = GameState.voyage_drone_count > 0 and not VoyageManager.voyage_active
	for tier in VoyageManager.VoyageTier.values():
		var btn_name = "VoyageBtn_" + str(tier)
		var btn = _voyage_panel.find_child(btn_name, true, false)
		if btn:
			btn.disabled = not can_voyage
			btn.visible = not VoyageManager.voyage_active

	# Show/hide voyage progress bar
	if _voyage_progress_bar:
		_voyage_progress_bar.visible = VoyageManager.voyage_active
	if _voyage_progress_label:
		if VoyageManager.voyage_active:
			var remaining = VoyageManager.voyage_duration - VoyageManager.voyage_elapsed
			_voyage_progress_label.text = "Voyage in progress... %ds remaining" % ceili(remaining)
		elif _results_timer <= 0.0:
			_voyage_progress_label.text = ""

	# Update expedition buttons
	var can_expedition = GameState.expedition_drone_count > 0 and not ExpeditionManager.expedition_active
	if _expedition_panel:
		for tier in ExpeditionManager.ExpeditionTier.values():
			var btn_name = "ExpeditionBtn_" + str(tier)
			var btn = _expedition_panel.find_child(btn_name, true, false)
			if btn:
				btn.disabled = not can_expedition
				btn.visible = not ExpeditionManager.expedition_active

	# Show/hide expedition progress bar
	if _expedition_progress_bar:
		_expedition_progress_bar.visible = ExpeditionManager.expedition_active
	if _expedition_progress_label:
		if ExpeditionManager.expedition_active:
			var remaining = ExpeditionManager.expedition_duration - ExpeditionManager.expedition_elapsed
			_expedition_progress_label.text = "Expedition in progress... %ds remaining" % ceili(remaining)
		elif _expedition_results_timer <= 0.0:
			_expedition_progress_label.text = ""

	_refresh_drone_upgrades_ui()

# === CALLBACKS ===

func _on_buy_voyage_drone_pressed() -> void:
	GameState.buy_voyage_drone()
	_refresh_drone_visuals()
	_refresh_ui()

func _on_buy_expedition_drone_pressed() -> void:
	GameState.buy_expedition_drone()
	_refresh_drone_visuals()
	_refresh_ui()

func _on_voyage_pressed(tier: int) -> void:
	if VoyageManager.start_voyage(tier):
		_refresh_drone_visuals()
		_refresh_ui()

func _on_voyage_drones_changed(_count: int) -> void:
	_refresh_drone_visuals()
	_refresh_ui()

func _on_expedition_drones_changed(_count: int) -> void:
	_refresh_drone_visuals()
	_refresh_ui()

func _on_credits_changed(_credits: int) -> void:
	_refresh_wallet_display()
	_refresh_ui()

func _on_bank_balance_changed(_balance: int) -> void:
	_refresh_wallet_display()

func _on_voyage_started() -> void:
	_refresh_drone_visuals()
	_refresh_ui()

func _on_voyage_progress(progress: float) -> void:
	if _voyage_progress_bar:
		_voyage_progress_bar.progress = progress
		_voyage_progress_bar.queue_redraw()
	if _voyage_progress_label and VoyageManager.voyage_active:
		var remaining = VoyageManager.voyage_duration - VoyageManager.voyage_elapsed
		_voyage_progress_label.text = "Voyage in progress... %ds remaining" % ceili(remaining)

func _on_voyage_completed(results: Dictionary) -> void:
	_refresh_drone_visuals()
	_refresh_ui()

	# Show results
	var total_minerals := 0
	for type in results.minerals_gained:
		total_minerals += results.minerals_gained[type]

	var result_text = "Voyage complete!\n"
	result_text += "%d/%d drones returned\n" % [results.drones_survived, results.drones_sent]
	if results.drones_lost > 0:
		result_text += "%d drones lost!\n" % results.drones_lost
	result_text += "+%d minerals collected" % total_minerals

	if _voyage_results_label:
		_voyage_results_label.text = result_text
		_results_timer = RESULTS_DISPLAY_TIME

	if _voyage_progress_label:
		_voyage_progress_label.text = ""

# === EXPEDITION CALLBACKS ===

func _on_expedition_pressed(tier: int) -> void:
	if ExpeditionManager.start_expedition(tier):
		_refresh_drone_visuals()
		_refresh_ui()

func _on_expedition_started() -> void:
	_refresh_drone_visuals()
	_refresh_ui()

func _on_expedition_progress(progress: float) -> void:
	if _expedition_progress_bar:
		_expedition_progress_bar.progress = progress
		_expedition_progress_bar.queue_redraw()
	if _expedition_progress_label and ExpeditionManager.expedition_active:
		var remaining = ExpeditionManager.expedition_duration - ExpeditionManager.expedition_elapsed
		_expedition_progress_label.text = "Expedition in progress... %ds remaining" % ceili(remaining)

func _on_expedition_completed(results: Dictionary) -> void:
	_refresh_drone_visuals()
	_refresh_ui()

	# Show results
	var total_minerals := 0
	for type in results.minerals_gained:
		total_minerals += results.minerals_gained[type]

	var result_text = "Expedition complete!\n"
	result_text += "%d/%d drones returned\n" % [results.drones_survived, results.drones_sent]
	if results.drones_lost > 0:
		result_text += "%d drones lost!\n" % results.drones_lost
	result_text += "+%d exotic minerals collected" % total_minerals

	if _voyage_results_label:
		_voyage_results_label.text = result_text
		_results_timer = RESULTS_DISPLAY_TIME

	if _expedition_progress_label:
		_expedition_progress_label.text = ""

func _on_exotic_minerals_changed() -> void:
	_refresh_drone_upgrades_ui()

func _on_drone_upgrades_changed() -> void:
	_refresh_drone_upgrades_ui()

func _on_drone_upgrade_pressed(upgrade_name: String) -> void:
	GameState.buy_drone_upgrade(upgrade_name)

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
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_bank_button_pressed() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://Scenes/bank.tscn")
	

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


# Inner class that draws a small drone triangle (voyage drones - white)
class _DroneDrawer extends Node2D:
	func _draw() -> void:
		var points = PackedVector2Array([
			Vector2(30, 0),
			Vector2(-10, -8),
			Vector2(-10, 8),
			Vector2(30, 0)
		])
		draw_polyline(points, Color.WHITE, 1.5)


# Inner class that draws a small drone triangle (expedition drones - blue)
class _ExpeditionDroneDrawer extends Node2D:
	func _draw() -> void:
		var points = PackedVector2Array([
			Vector2(30, 0),
			Vector2(-10, -8),
			Vector2(-10, 8),
			Vector2(30, 0)
		])
		draw_polyline(points, Color(0.4, 0.7, 1.0), 1.5)
		

# Inner class for voyage progress bar (drawn via _draw for consistency with game style)
class _VoyageProgressBar extends Control:
	var progress: float = 0.0
	const BAR_WIDTH := 230.0
	const BAR_HEIGHT := 16.0

	func _get_minimum_size() -> Vector2:
		return Vector2(BAR_WIDTH + 4, BAR_HEIGHT + 4)

	func _draw() -> void:
		var x_start := 2.0
		var y_start := 2.0

		# Background
		draw_rect(Rect2(x_start, y_start, BAR_WIDTH, BAR_HEIGHT), Color(0.1, 0.1, 0.1), true)

		# Fill
		var fill_width = BAR_WIDTH * progress
		if fill_width > 0:
			draw_rect(Rect2(x_start, y_start, fill_width, BAR_HEIGHT), Color.WHITE, true)

		# Border
		draw_rect(Rect2(x_start, y_start, BAR_WIDTH, BAR_HEIGHT), Color(0.6, 0.6, 0.6), false, 1.0)

		# Percentage text
		var pct_text = "%d%%" % int(progress * 100)
		draw_string(ThemeDB.fallback_font, Vector2(x_start + BAR_WIDTH * 0.5 - 12, y_start + BAR_HEIGHT - 3), pct_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)
