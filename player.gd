extends Node2D

# --- Movement (left stick / WASD) ---
@export var max_speed: float = 600.0
@export var acceleration: float = 2400.0
@export var friction: float = 1800.0

# --- Firing ---
@export var projectile_scene: PackedScene
@export var muzzle_separation: float = 16.0
@export var rocket_scene: PackedScene

# --- Aiming (right stick / mouse/trackpad) ---
@export var aim_deadzone: float = 0.02
@export var turn_speed := 15.0             # max turn rate (radians per second)

var aim := Vector2.ZERO

var FloatingText2D := preload("res://Scenes/floating_text_2d.tscn")
var _vel: Vector2 = Vector2.ZERO
var _fire_timer: Timer

@export var mouse_move_threshold := 0.5  # pixels per frame

var _mouse_delta := Vector2.ZERO

# Shield system
var current_shield: float = 0.0
var _shield_regen_timer: float = 0.0
var _can_regenerate: bool = true

func _draw() -> void:
	var points = PackedVector2Array([
		Vector2(60, 0),
		Vector2(-20, -16),
		Vector2(-20, 16),
		Vector2(60, 0)
	])
	#draw_colored_polygon(points, Color.WHITE)
	draw_polyline(points, Color.WHITE)

@export var invert_x: bool = false
@export var invert_y: bool = true   # true because screen Y+ is down

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative


func _ready() -> void:
	_fire_timer = Timer.new()
	_fire_timer.one_shot = false
	add_child(_fire_timer)
	_fire_timer.timeout.connect(_on_fire_timeout)
	_fire_timer.wait_time = 1.0 / max(GameState.fire_rate, 0.01)
	_fire_timer.start()
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Initialize shield to maximum
	current_shield = GameState.max_shield
	GameState.emit_signal("shield_changed", current_shield, GameState.max_shield)
	
	
func _physics_process(delta: float) -> void:
	_handle_move(delta)
	_handle_aim(delta)
	_handle_shield_regeneration(delta)
	_mouse_delta = Vector2.ZERO  # reset every physics tick

func _handle_move(delta: float) -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input != Vector2.ZERO:
		_vel = _vel.move_toward(move_input.normalized() * max_speed, acceleration * delta)
	else:
		_vel = _vel.move_toward(Vector2.ZERO, friction * delta)
	global_position += _vel * delta

func _handle_aim(delta: float) -> void:
	if _mouse_delta.length() > mouse_move_threshold:
		var mpos := get_global_mouse_position()
		var target_angle := (mpos - global_position).angle()
		var t = clamp(turn_speed * delta, 0.0, 1.0)
		rotation = lerp_angle(rotation, target_angle, t)
	# if no mouse movement → do nothing (hold heading)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PHYSICS_PROCESS:
	# Keep timer rate in sync if an upgrade changed mid-run
		_set_fire_rate(GameState.fire_rate)

func _set_fire_rate(rps: float) -> void:
	var period: float = (1.0 / max(rps, 0.01))
	if is_instance_valid(_fire_timer):
		_fire_timer.wait_time = period
		if _fire_timer.is_stopped():
			_fire_timer.start()

func _on_fire_timeout() -> void:
	if projectile_scene == null:
		return
# Spawn two shots, offset left/right from the ship's forward axis
	var forward := Vector2.RIGHT.rotated(rotation) # Node2D right is local +X
	var left_offset := Vector2(0, -muzzle_separation).rotated(rotation)
	var right_offset := Vector2(0, muzzle_separation).rotated(rotation)
	_emit_projectile(global_position + left_offset, forward)
	_emit_projectile(global_position + right_offset, forward)

func _emit_projectile(spawn_pos: Vector2, dir: Vector2) -> void:
	var p = projectile_scene.instantiate()
	p.global_position = spawn_pos
	p.rotation = dir.angle()
	if p.has_method("configure_speed"):
		p.configure_speed(GameState.projectile_speed)
	get_tree().current_scene.add_child(p)
	
func popup_mineral(mineral_name: String) -> void:
	var ft := FloatingText2D.instantiate()
	get_tree().current_scene.add_child(ft)  # add to world

	# start position just above the player, with tiny x jitter
	var start := global_position
	ft.show_text(mineral_name, start)
	
func enable_rockets():
	print("enabling rockets")
	$RocketTimer.start()

func _on_rocket_timer_timeout() -> void:
	spawn_rocket()
	print("Timer timeout - spawning rocket")
	
func spawn_rocket():
	if not rocket_scene:
		print("ERROR: No rocket scene assigned!")
		return

	var rocket = rocket_scene.instantiate()
	rocket.global_position = global_position
	rocket.rotation = rotation

	# Add to the scene tree
	get_parent().add_child(rocket)  # Or get_tree().root.add_child(rocket)

	print("Rocket spawned at: ", rocket.global_position)

# === Shield System Functions ===

func _handle_shield_regeneration(delta: float) -> void:
	"""Regenerate shield over time after the regen delay"""
	if current_shield < GameState.max_shield:
		if _can_regenerate:
			_shield_regen_timer += delta
			if _shield_regen_timer >= GameState.shield_regen_delay:
				# Start regenerating
				current_shield = min(current_shield + GameState.shield_regen_rate * delta, GameState.max_shield)
				GameState.emit_signal("shield_changed", current_shield, GameState.max_shield)

func take_damage(amount: float) -> void:
	"""Damage the shield and reset regeneration timer"""
	current_shield = max(0.0, current_shield - amount)
	_shield_regen_timer = 0.0  # Reset regen timer
	_can_regenerate = true
	GameState.emit_signal("shield_changed", current_shield, GameState.max_shield)

	# Visual feedback - flash the ship
	modulate = Color(1.5, 0.5, 0.5)  # Red flash
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

	if current_shield <= 0:
		_on_shield_depleted()

func _on_shield_depleted() -> void:
	"""Called when shield reaches zero - handle player death/respawn"""
	print("Shield depleted! Game Over!")
	# You can add death/respawn logic here
	# For now, just respawn the shield after a delay
	await get_tree().create_timer(2.0).timeout
	current_shield = GameState.max_shield
	GameState.emit_signal("shield_changed", current_shield, GameState.max_shield)
