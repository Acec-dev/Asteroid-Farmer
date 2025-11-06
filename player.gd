extends CharacterBody2D

# --- Movement (left stick / WASD) ---
@export var max_speed: float = 600.0
@export var acceleration: float = 2400.0
@export var friction: float = 1800.0

# --- Firing ---
@export var muzzle_separation: float = 16.0
var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")
var rocket_scene: PackedScene = preload("res://Scenes/rocket.tscn")

# --- Hitscan settings ---
@export var fire_interval: float = 0.5  # seconds between shots
@export var max_range: float = 2000.0   # maximum shooting range
@export var visual_projectile_speed: float = 2500.0  # purely visual
@export var damage_per_shot: int = 1  # damage dealt per hitscan shot

var FloatingText2D := preload("res://Scenes/floating_text_2d.tscn")
var _vel: Vector2 = Vector2.ZERO
var _fire_timer: Timer

var _mouse_delta := Vector2.ZERO

# Shield system
var current_shield: float = 0.0
var _shield_regen_timer: float = 0.0
var _can_regenerate: bool = true

@export var mouse_move_threshold := 0.5  # pixels per frame

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative

func _draw() -> void:
	var points = PackedVector2Array([
		Vector2(60, 0),
		Vector2(-20, -16),
		Vector2(-20, 16),
		Vector2(60, 0)
	])
	draw_polyline(points, Color.WHITE)

func _ready() -> void:
	_fire_timer = Timer.new()
	_fire_timer.one_shot = false
	add_child(_fire_timer)
	_fire_timer.timeout.connect(_on_fire_timeout)
	_fire_timer.wait_time = fire_interval
	_fire_timer.start()
	
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Initialize shield to full
	current_shield = GameState.max_shield
	GameState.shield_changed.emit(current_shield, GameState.max_shield)
	
func _physics_process(delta: float) -> void:
	_handle_move(delta)
	_handle_aim()
	_handle_shield_regeneration(delta)
	_mouse_delta = Vector2.ZERO  # Reset after processing

func _handle_move(delta: float) -> void:
	# WASD movement - completely independent of aiming
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input != Vector2.ZERO:
		_vel = _vel.move_toward(move_input.normalized() * max_speed, acceleration * delta)
	else:
		_vel = _vel.move_toward(Vector2.ZERO, friction * delta)
	global_position += _vel * delta

func _handle_aim() -> void:
	# Ship only rotates when you MOVE the mouse, not constantly
	if _mouse_delta.length() > 0.1:  # Only if mouse actually moved
		var mouse_pos := get_global_mouse_position()
		var direction := (mouse_pos - global_position).normalized()
		rotation = direction.angle()

func _on_fire_timeout() -> void:
	# Perform hitscan from both muzzle positions
	var forward := Vector2.RIGHT.rotated(rotation)
	var left_offset := Vector2(0, -muzzle_separation).rotated(rotation)
	var right_offset := Vector2(0, muzzle_separation).rotated(rotation)
	
	_hitscan_shot(global_position + left_offset, forward)
	_hitscan_shot(global_position + right_offset, forward)

func _hitscan_shot(spawn_pos: Vector2, direction: Vector2) -> void:
	# Create the raycast
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		spawn_pos,
		spawn_pos + direction * max_range
	)
	
	# Try all collision layers to ensure we hit asteroids
	query.collision_mask = 0xFFFFFFFF  # Check all layers
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	# Spawn visual projectile
	_spawn_visual_projectile(spawn_pos, direction, result)
	
	# Apply damage if we hit something
	if result and result.collider:
		var hit_object = result.collider
		if hit_object.has_method("hit_by_projectile"):
			# Apply damage multiple times if needed to match old behavior
			for i in damage_per_shot:
				hit_object.hit_by_projectile(self)

func _spawn_visual_projectile(spawn_pos: Vector2, direction: Vector2, raycast_result: Dictionary) -> void:
	if projectile_scene == null:
		return
	
	var p = projectile_scene.instantiate()
	p.global_position = spawn_pos
	p.rotation = direction.angle()
	
	# Configure as visual-only
	if p.has_method("configure_as_visual"):
		var target_distance: float
		if raycast_result and raycast_result.collider:
			# Stop at hit point
			target_distance = spawn_pos.distance_to(raycast_result.position)
		else:
			# Travel max range
			target_distance = max_range
		
		p.configure_as_visual(visual_projectile_speed, target_distance)
	
	get_tree().current_scene.add_child(p)

func popup_mineral(mineral_name: String) -> void:
	var ft := FloatingText2D.instantiate()
	get_tree().current_scene.add_child(ft)
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
	# Rocket should face the same direction as the ship
	rocket.rotation = rotation
	
	get_parent().add_child(rocket)
	print("Rocket spawned at: ", rocket.global_position, " with rotation: ", rad_to_deg(rocket.rotation))

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
