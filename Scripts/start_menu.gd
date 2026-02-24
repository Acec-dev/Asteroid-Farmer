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
