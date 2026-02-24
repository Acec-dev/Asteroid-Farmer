extends Node2D

# Decorative background data (right half only)
var _asteroids: Array = []
var _stars: Array = []
var _ship_rotation: float = 0.0
var _fade_timer: float = 0.0

# Right half bounds
const RIGHT_X := 960.0
const RIGHT_W := 960.0

# Cached stats from the run that just ended
var _stats: Dictionary = {}


func _ready() -> void:
	_capture_stats()
	_generate_stars()
	_generate_decorative_asteroids()
	_build_ui()


func _process(delta: float) -> void:
	_fade_timer += delta
	_ship_rotation += delta * 0.3

	for asteroid in _asteroids:
		asteroid.pos += asteroid.vel * delta
		# Wrap within right half
		if asteroid.pos.x < RIGHT_X - 50:
			asteroid.pos.x = RIGHT_X + RIGHT_W + 50
		if asteroid.pos.x > RIGHT_X + RIGHT_W + 50:
			asteroid.pos.x = RIGHT_X - 50
		if asteroid.pos.y < -50:
			asteroid.pos.y = 1130
		if asteroid.pos.y > 1130:
			asteroid.pos.y = -50
		asteroid.rot += asteroid.rot_speed * delta

	queue_redraw()


func _draw() -> void:
	var alpha = clampf(_fade_timer / 1.0, 0.0, 1.0)

	# Stars (right half only)
	for star in _stars:
		var a = star.alpha * alpha
		draw_circle(star.pos, star.size, Color(1, 1, 1, a))

	# Asteroids (right half only)
	for asteroid in _asteroids:
		_draw_asteroid(asteroid, alpha)

	# Ship in center of right half
	_draw_ship(Vector2(RIGHT_X + RIGHT_W * 0.5, 400), _ship_rotation, alpha)


func _draw_ship(pos: Vector2, rot: float, alpha: float) -> void:
	var s := 50.0
	var points = PackedVector2Array([
		Vector2(s, 0),
		Vector2(-s * 0.4, -s * 0.35),
		Vector2(-s * 0.4, s * 0.35),
		Vector2(s, 0),
	])
	var rotated = PackedVector2Array()
	for p in points:
		var rx = p.x * cos(rot) - p.y * sin(rot)
		var ry = p.x * sin(rot) + p.y * cos(rot)
		rotated.append(Vector2(rx, ry) + pos)
	draw_polyline(rotated, Color(1, 1, 1, alpha), 2.0)


func _draw_asteroid(asteroid: Dictionary, alpha: float) -> void:
	var points = asteroid.shape as PackedVector2Array
	var rotated = PackedVector2Array()
	for p in points:
		var rx = p.x * cos(asteroid.rot) - p.y * sin(asteroid.rot)
		var ry = p.x * sin(asteroid.rot) + p.y * cos(asteroid.rot)
		rotated.append(Vector2(rx, ry) + asteroid.pos)
	if rotated.size() > 0:
		rotated.append(rotated[0])
	draw_polyline(rotated, Color(0.3, 0.3, 0.3, 0.5 * alpha), 1.5)


func _generate_stars() -> void:
	for i in range(30):
		_stars.append({
			"pos": Vector2(randf_range(RIGHT_X, RIGHT_X + RIGHT_W), randf_range(0, 1080)),
			"size": randf_range(0.5, 1.5),
			"alpha": randf_range(0.15, 0.5),
		})


func _generate_decorative_asteroids() -> void:
	for i in range(6):
		_asteroids.append({
			"pos": Vector2(randf_range(RIGHT_X, RIGHT_X + RIGHT_W), randf_range(0, 1080)),
			"vel": Vector2(randf_range(-12, 12), randf_range(-8, 8)),
			"rot": randf_range(0, TAU),
			"rot_speed": randf_range(-0.2, 0.2),
			"shape": _make_asteroid_shape(randf_range(18, 50)),
		})


func _make_asteroid_shape(radius: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var num_verts = randi_range(6, 10)
	for i in range(num_verts):
		var angle = (float(i) / num_verts) * TAU
		var r = radius * randf_range(0.6, 1.0)
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts


# === STATS ===

func _capture_stats() -> void:
	var minutes := int(GameState.run_time) / 60
	var seconds := int(GameState.run_time) % 60
	_stats["run_time"] = "%d:%02d" % [minutes, seconds]
	_stats["credits"] = GameState.credits
	_stats["bank_balance"] = GameState.bank_balance

	var total_minerals := 0
	for count in GameState.minerals.values():
		total_minerals += count
	_stats["minerals_held"] = total_minerals

	var total_exotic := 0
	for count in GameState.exotic_minerals.values():
		total_exotic += count
	_stats["exotic_minerals"] = total_exotic

	_stats["voyage_drones"] = GameState.voyage_drone_count
	_stats["expedition_drones"] = GameState.expedition_drone_count

	# Count total upgrade levels purchased
	var upgrade_levels := 0
	for weapon_name in GameState.upgrades.weapons:
		var w = GameState.upgrades.weapons[weapon_name]
		if w.unlocked:
			upgrade_levels += w.level
	for system_name in ["shield", "radar", "cargo"]:
		if GameState.upgrades.has(system_name):
			for upgrade_name in GameState.upgrades[system_name]:
				upgrade_levels += GameState.upgrades[system_name][upgrade_name].level
	upgrade_levels += GameState.upgrades.tractor_beam.power.level
	for drone_upgrade in GameState.drone_upgrades:
		upgrade_levels += GameState.drone_upgrades[drone_upgrade].level
	_stats["upgrade_levels"] = upgrade_levels

	# Weapons unlocked
	var weapons := []
	for weapon_name in GameState.upgrades.weapons:
		if GameState.upgrades.weapons[weapon_name].unlocked:
			weapons.append(weapon_name)
	_stats["weapons"] = weapons

	# Net worth: credits + bank + gm100 + bond principals + mineral values
	var net_worth := GameState.credits + GameState.bank_balance + GameState.gm100_invested
	for bond in GameState.bank_bonds:
		net_worth += bond.principal
	for kind in GameState.minerals:
		net_worth += GameState.minerals[kind] * GameState.get_market_price(kind)
	_stats["net_worth"] = net_worth

	# Spawner difficulty reached
	_stats["difficulty"] = GameState.get_spawner_difficulty()


# === UI ===

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var mono_font = load("res://Assets/DMMono-Regular.ttf")
	var mono_medium = load("res://Assets/DMMono-Medium.ttf")

	# === LEFT HALF: Stats ===
	_build_stats_panel(canvas, mono_font, mono_medium)

	# === RIGHT HALF: "DEAD." label + buttons ===
	_build_dead_label(canvas, mono_medium)
	_build_buttons(canvas, mono_font)


func _build_stats_panel(canvas: CanvasLayer, font: Font, font_bold: Font) -> void:
	# Vertical divider line at center
	var divider = ColorRect.new()
	divider.anchor_left = 0.5
	divider.anchor_right = 0.5
	divider.anchor_top = 0.05
	divider.anchor_bottom = 0.95
	divider.offset_left = -1
	divider.offset_right = 1
	divider.color = Color(0.25, 0.25, 0.25)
	canvas.add_child(divider)

	# Stats container on the left half
	var stats_box = VBoxContainer.new()
	stats_box.anchor_left = 0.05
	stats_box.anchor_right = 0.45
	stats_box.anchor_top = 0.08
	stats_box.anchor_bottom = 0.92
	stats_box.add_theme_constant_override("separation", 8)
	canvas.add_child(stats_box)

	# Header
	var header = Label.new()
	header.text = "RUN STATS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", 32)
	header.add_theme_color_override("font_color", Color.WHITE)
	if font_bold:
		header.add_theme_font_override("font", font_bold)
	stats_box.add_child(header)

	# Separator
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.4, 0.4, 0.4)
	stats_box.add_child(sep)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	stats_box.add_child(spacer)

	# Stat rows
	var stat_entries = [
		["Survived", _stats.get("run_time", "0:00")],
		["Credits", str(_stats.get("credits", 0))],
		["Net Worth", str(_stats.get("net_worth", 0))],
		["Bank Balance", str(_stats.get("bank_balance", 0))],
		["Minerals Held", str(_stats.get("minerals_held", 0))],
		["Exotic Minerals", str(_stats.get("exotic_minerals", 0))],
		["Voyage Drones", str(_stats.get("voyage_drones", 0))],
		["Expedition Drones", str(_stats.get("expedition_drones", 0))],
		["Upgrade Levels", str(_stats.get("upgrade_levels", 0))],
		["Difficulty Reached", str(_stats.get("difficulty", 1))],
	]

	for entry in stat_entries:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		stats_box.add_child(row)

		var name_label = Label.new()
		name_label.text = entry[0]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		if font:
			name_label.add_theme_font_override("font", font)
		row.add_child(name_label)

		var value_label = Label.new()
		value_label.text = entry[1]
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 20)
		value_label.add_theme_color_override("font_color", Color.WHITE)
		if font:
			value_label.add_theme_font_override("font", font)
		row.add_child(value_label)

	# Weapons row
	var weapons_list = _stats.get("weapons", []) as Array
	if weapons_list.size() > 0:
		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(0, 8)
		stats_box.add_child(spacer2)

		var weapons_header = Label.new()
		weapons_header.text = "Weapons Unlocked"
		weapons_header.add_theme_font_size_override("font_size", 20)
		weapons_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		if font:
			weapons_header.add_theme_font_override("font", font)
		stats_box.add_child(weapons_header)

		for weapon_name in weapons_list:
			var weapon_label = Label.new()
			weapon_label.text = "  " + weapon_name
			weapon_label.add_theme_font_size_override("font_size", 18)
			weapon_label.add_theme_color_override("font_color", Color.WHITE)
			if font:
				weapon_label.add_theme_font_override("font", font)
			stats_box.add_child(weapon_label)


func _build_dead_label(canvas: CanvasLayer, font_bold: Font) -> void:
	var dead_label = Label.new()
	dead_label.text = "DEAD."
	dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_label.add_theme_font_size_override("font_size", 64)
	dead_label.add_theme_color_override("font_color", Color.WHITE)
	if font_bold:
		dead_label.add_theme_font_override("font", font_bold)

	# Position below the ship in the right half
	dead_label.anchor_left = 0.5
	dead_label.anchor_right = 1.0
	dead_label.anchor_top = 0.48
	dead_label.anchor_bottom = 0.58
	dead_label.offset_left = 0
	dead_label.offset_right = 0
	dead_label.offset_top = 0
	dead_label.offset_bottom = 0
	canvas.add_child(dead_label)


func _build_buttons(canvas: CanvasLayer, font: Font) -> void:
	var mono_font = font

	# Button container - bottom right corner of the right half
	var btn_box = HBoxContainer.new()
	btn_box.anchor_left = 0.65
	btn_box.anchor_right = 0.95
	btn_box.anchor_top = 0.85
	btn_box.anchor_bottom = 0.92
	btn_box.add_theme_constant_override("separation", 20)
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	canvas.add_child(btn_box)

	# New Game button
	var new_game_btn = Button.new()
	new_game_btn.text = "NEW GAME"
	new_game_btn.custom_minimum_size = Vector2(180, 0)
	_style_button(new_game_btn, mono_font, 20)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	btn_box.add_child(new_game_btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(140, 0)
	_style_button(back_btn, mono_font, 20)
	back_btn.pressed.connect(_on_back_pressed)
	btn_box.add_child(back_btn)


func _style_button(btn: Button, font: Font, font_size: int) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.7, 0.7))
	if font:
		btn.add_theme_font_override("font", font)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 1)
	normal.border_color = Color(0.6, 0.6, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(0)
	normal.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.08, 0.08, 0.08, 1)
	hover.border_color = Color.WHITE
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(0)
	hover.set_content_margin_all(14)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.15, 0.15, 0.15, 1)
	pressed.border_color = Color.WHITE
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(0)
	pressed.set_content_margin_all(14)
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", focus)


# === BUTTON CALLBACKS ===

func _on_new_game_pressed() -> void:
	GameState.reset_to_defaults()
	Market.reset_market()
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_back_pressed() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
