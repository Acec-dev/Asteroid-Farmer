extends Node2D

# Decorative background data
var _asteroids: Array = []
var _stars: Array = []
var _ship_rotation: float = 0.0
var _fade_timer: float = 0.0

# UI references (from scene nodes)
@onready var _continue_holder: CenterContainer = $CanvasLayer/Center/ContinueHolder
@onready var _continue_btn: Button = $CanvasLayer/Center/ContinueHolder/ContinueBtn
@onready var _new_game_btn: Button = $CanvasLayer/Center/NewGameHolder/NewGameBtn
@onready var _options_btn: Button = $CanvasLayer/Center/OptionsHolder/OptionsBtn

# Options panel (built in code for show/hide behavior)
var _options_panel: PanelContainer
var _volume_slider: HSlider
var _volume_label: Label


func _ready() -> void:
	_generate_stars()
	_generate_decorative_asteroids()
	_setup_ui()


func _setup_ui() -> void:
	# Hide continue button if no save exists
	if not SaveManager.save_exists():
		_continue_holder.visible = false

	# Apply button styles
	_style_button(_continue_btn)
	_style_button(_new_game_btn)
	_style_button(_options_btn)

	# Build options panel
	_build_options_panel()


func _process(delta: float) -> void:
	_fade_timer += delta
	_ship_rotation += delta * 0.3

	# Drift asteroids
	for asteroid in _asteroids:
		asteroid.pos += asteroid.vel * delta
		if asteroid.pos.x < -100:
			asteroid.pos.x = 2020
		if asteroid.pos.x > 2020:
			asteroid.pos.x = -100
		if asteroid.pos.y < -100:
			asteroid.pos.y = 1180
		if asteroid.pos.y > 1180:
			asteroid.pos.y = -100
		asteroid.rot += asteroid.rot_speed * delta

	queue_redraw()


func _draw() -> void:
	var title_alpha = clampf(_fade_timer / 1.0, 0.0, 1.0)

	# Stars
	for star in _stars:
		var alpha = star.alpha * title_alpha
		draw_circle(star.pos, star.size, Color(1, 1, 1, alpha))

	# Asteroids
	for asteroid in _asteroids:
		_draw_asteroid(asteroid, title_alpha)

	# Ship above title area
	_draw_ship(Vector2(960, 300), _ship_rotation, title_alpha)


func _draw_ship(pos: Vector2, rot: float, alpha: float) -> void:
	var s := 40.0
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
	for i in range(50):
		_stars.append({
			"pos": Vector2(randf_range(0, 1920), randf_range(0, 1080)),
			"size": randf_range(0.5, 1.5),
			"alpha": randf_range(0.15, 0.5),
		})


func _generate_decorative_asteroids() -> void:
	for i in range(10):
		_asteroids.append({
			"pos": Vector2(randf_range(0, 1920), randf_range(0, 1080)),
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


func _style_button(btn: Button) -> void:
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


# === OPTIONS PANEL ===

func _build_options_panel() -> void:
	var mono_font = load("res://Assets/DMMono-Regular.ttf")

	_options_panel = PanelContainer.new()
	_options_panel.visible = false

	# Centered below the buttons
	_options_panel.anchor_left = 0.5
	_options_panel.anchor_right = 0.5
	_options_panel.anchor_top = 0.5
	_options_panel.anchor_bottom = 0.5
	_options_panel.offset_left = -200
	_options_panel.offset_right = 200
	_options_panel.offset_top = -80
	_options_panel.offset_bottom = 80

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.04, 0.04, 0.95)
	panel_style.border_color = Color(0.6, 0.6, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	panel_style.set_content_margin_all(20)
	_options_panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_options_panel.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "OPTIONS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color.WHITE)
	if mono_font:
		header.add_theme_font_override("font", mono_font)
	vbox.add_child(header)

	# Sound volume row
	var sound_row = VBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 6)
	vbox.add_child(sound_row)

	_volume_label = Label.new()
	_volume_label.text = "Sound Volume: 100%"
	_volume_label.add_theme_font_size_override("font_size", 16)
	_volume_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	if mono_font:
		_volume_label.add_theme_font_override("font", mono_font)
	sound_row.add_child(_volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	# Convert current Master bus dB to a percentage (0 dB = 100%, -30 dB = 0%)
	var current_db = AudioServer.get_bus_volume_db(0)
	_volume_slider.value = clampf(db_to_linear(current_db) * 100.0, 0.0, 100.0)
	_volume_slider.custom_minimum_size = Vector2(0, 20)

	# Style the slider grabber
	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = Color.WHITE
	grabber_style.set_corner_radius_all(0)
	grabber_style.custom_minimum_size = Vector2(12, 20)
	_volume_slider.add_theme_stylebox_override("grabber_area", grabber_style)

	_volume_slider.value_changed.connect(_on_volume_changed)
	sound_row.add_child(_volume_slider)

	# Update label to match initial value
	_volume_label.text = "Sound Volume: %d%%" % int(_volume_slider.value)

	# Close button
	var close_holder = CenterContainer.new()
	vbox.add_child(close_holder)

	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(120, 0)
	_style_button(close_btn)
	close_btn.pressed.connect(_on_options_close)
	close_holder.add_child(close_btn)

	$CanvasLayer.add_child(_options_panel)


func _on_volume_changed(value: float) -> void:
	var linear = value / 100.0
	# Convert linear 0-1 to dB, mute at 0
	if linear <= 0.0:
		AudioServer.set_bus_volume_db(0, -80.0)
	else:
		AudioServer.set_bus_volume_db(0, linear_to_db(linear))
	_volume_label.text = "Sound Volume: %d%%" % int(value)


# === BUTTON CALLBACKS ===

func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://Scenes/main.tscn")
	else:
		# Save was corrupt or missing — fall back to new game
		_on_new_game_pressed()


func _on_new_game_pressed() -> void:
	GameState.reset_to_defaults()
	Market.reset_market()
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_options_pressed() -> void:
	_options_panel.visible = true


func _on_options_close() -> void:
	_options_panel.visible = false
