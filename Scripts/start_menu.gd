extends Node2D

# Decorative background data
var _asteroids: Array = []
var _stars: Array = []
var _ship_rotation: float = 0.0
var _fade_timer: float = 0.0

# UI references
var _continue_btn: Button
var _new_game_btn: Button
var _canvas_layer: CanvasLayer


func _ready() -> void:
	_generate_stars()
	_generate_decorative_asteroids()
	_build_ui()


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


# === UI ===

func _build_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	add_child(_canvas_layer)

	var mono_font = load("res://Assets/DMMono-Regular.ttf")
	var mono_medium = load("res://Assets/DMMono-Medium.ttf")

	# Center container
	var center = VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.32
	center.anchor_bottom = 0.78
	center.offset_left = -220
	center.offset_right = 220
	center.add_theme_constant_override("separation", 0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_canvas_layer.add_child(center)

	# Title
	var title = Label.new()
	title.text = "ASTEROID  FARMER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color.WHITE)
	if mono_medium:
		title.add_theme_font_override("font", mono_medium)
	center.add_child(title)

	# Separator line
	var sep_holder = CenterContainer.new()
	sep_holder.custom_minimum_size = Vector2(0, 24)
	center.add_child(sep_holder)
	var sep_line = ColorRect.new()
	sep_line.custom_minimum_size = Vector2(360, 1)
	sep_line.color = Color(0.6, 0.6, 0.6)
	sep_holder.add_child(sep_line)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	center.add_child(spacer)

	# Continue button (only if a save exists)
	if SaveManager.save_exists():
		_continue_btn = Button.new()
		_continue_btn.text = "CONTINUE"
		_continue_btn.custom_minimum_size = Vector2(260, 0)
		_style_button(_continue_btn, mono_font, 22)
		_continue_btn.pressed.connect(_on_continue_pressed)

		var cont_center = CenterContainer.new()
		cont_center.custom_minimum_size = Vector2(0, 56)
		center.add_child(cont_center)
		cont_center.add_child(_continue_btn)

	# New Game button
	_new_game_btn = Button.new()
	_new_game_btn.text = "NEW GAME"
	_new_game_btn.custom_minimum_size = Vector2(260, 0)
	_style_button(_new_game_btn, mono_font, 22)
	_new_game_btn.pressed.connect(_on_new_game_pressed)

	var ng_center = CenterContainer.new()
	ng_center.custom_minimum_size = Vector2(0, 56)
	center.add_child(ng_center)
	ng_center.add_child(_new_game_btn)

	# Version / hint label at bottom
	var hint = Label.new()
	hint.text = "WASD to move  |  TAB for menus"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	if mono_font:
		hint.add_theme_font_override("font", mono_font)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -40
	hint.offset_bottom = -16
	_canvas_layer.add_child(hint)


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
