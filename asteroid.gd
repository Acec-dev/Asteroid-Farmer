extends RigidBody2D
class_name Asteroid

@export var radius: float = 28.0
@export var hit_points: int = 2  # Big asteroids take 2 hits
@export var split_radius_factor: float = 0.5  # Child radius = parent radius * this factor
@export var min_split_radius: float = 14.0  # Don't split if radius would be smaller than this
@export var mineral_kind: StringName = "iron"
@export var mineral_drop_scene: PackedScene = preload("res://Scenes/mineral.tscn")
@export var mineral_drop_count: int = 1
@export var debug_draw_path: bool = false
@export var particle_scene: PackedScene = preload("res://Scenes/break_particles.tscn")

var _dir: Vector2 = Vector2.ZERO # for optional debug draw
var _speed: float = 0.0

@onready var visuals: Node2D = $Visuals

func _ready() -> void:
	# Space-y defaults
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	# Spin a little so they look alive, but motion stays straight
	freeze = false
	can_sleep = false
	sleeping = false
	angular_velocity = randf_range(-1.2, 1.2)
	
	# Update visuals to match radius
	if visuals and visuals.has_method("set_radius"):
		visuals.set_radius(radius)
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	
func _kick() -> void:
	linear_damp = 0.0
	angular_damp = 0.0
	gravity_scale = 0.0
	var desired_v := _dir * _speed
	var m := mass
	apply_central_impulse(desired_v * m)
	can_sleep = true

func setup_motion(from_pos: Vector2, band_point: Vector2, speed: float) -> void:
	"""initialize position and straight-line motion toward a band point"""
	global_position = from_pos
	_dir = (band_point - from_pos).normalized()
	_speed = speed
	if visuals:
		visuals.rotation = _dir.angle()

	# Optional debug: show local forward (path) arrow
	if debug_draw_path and _dir != Vector2.ZERO:
		draw_line(Vector2.ZERO, _dir * 60.0, Color.WHITE, 2.0)

func _physics_process(_delta: float) -> void:
	# Re-apply velocity every tick so physics never zeroes it out
	if _dir != Vector2.ZERO and _speed > 0.0:
		linear_velocity = _dir * _speed

func hit_by_projectile(_p: Node) -> void:
	hit_points -= 1
	
	if hit_points <= 0:
		# Defer the break; don't modify the tree/collision right now
		call_deferred("_break_safe")
	else:
		# Just nudge it a bit
		apply_central_impulse(Vector2(randf_range(-80, 80), randf_range(-80, 80)))

func _on_body_entered(body: Node) -> void:
	"""Damage player shield when asteroid collides with them"""
	# Check if the colliding body is the player
	if body.has_method("take_damage"):
		var damage_amount := 20.0  # Base damage per collision
		# Scale damage based on asteroid size (larger asteroids = more damage)
		var size_multiplier := radius / 28.0  # 28.0 is the default big radius
		var total_damage := damage_amount * size_multiplier

		body.take_damage(total_damage)

		# Apply knockback to both asteroid and player
		var collision_normal = (global_position - body.global_position).normalized()
		apply_central_impulse(collision_normal * 100.0 * mass)

		# Reduce asteroid health from the impact
		hit_points = max(0, hit_points - 1)
		if hit_points <= 0:
			call_deferred("_break_safe")

func _spawn_particles() -> void:
	if particle_scene == null:
		return
	var fx := particle_scene.instantiate()
	fx.global_position = global_position
	fx.global_rotation = rotation

	# Ensure it cleans up by itself
	if fx is GPUParticles2D:
		fx.one_shot = true
		fx.emitting = true
		fx.finished.connect(fx.queue_free) # Godot 4 signal
	else:
		var p := fx.get_node_or_null("GPUParticles2D")
		if p:
			p.one_shot = true
			p.emitting = true
			p.finished.connect(fx.queue_free)
		else:
			# Fallback: timed self-destruct if you don't have a GPUParticles2D under fx
			var t := Timer.new()
			t.one_shot = true
			t.wait_time = 2.0
			fx.add_child(t)
			t.timeout.connect(fx.queue_free)
			t.start()

	get_tree().current_scene.add_child(fx)

func _break_safe() -> void:
	_spawn_particles()
	
	# Calculate child radius
	var child_radius = radius * split_radius_factor
	
	# Check if this asteroid will split
	var will_split = child_radius >= min_split_radius
	
	# Drop minerals (always drops, whether splitting or not)
	for i in mineral_drop_count:
		if mineral_drop_scene:
			var m = mineral_drop_scene.instantiate()
			m.global_position = global_position + Vector2(randf_range(-8,8), randf_range(-8,8))
			get_tree().current_scene.add_child(m)
	
	# Only split if child would be large enough
	if will_split:
		# Split into 2 smaller versions of itself
		for i in 2:
			# Create a copy of this asteroid scene
			var child_asteroid = duplicate(DUPLICATE_USE_INSTANTIATION)
			
			# Set smaller radius
			child_asteroid.radius = child_radius
			
			# Small asteroids only need 1 hit
			child_asteroid.hit_points = 1
			
			# Position with some offset
			child_asteroid.global_position = global_position + Vector2(randf_range(-12,12), randf_range(-12,12))
			
			# Keep same direction and speed
			if child_asteroid.has_method("setup_motion"):
				child_asteroid.setup_motion(child_asteroid.global_position, child_asteroid.global_position + _dir, _speed)
			
			# Add to scene
			get_tree().current_scene.call_deferred("add_child", child_asteroid)

	# Defer freeing too (extra safe)
	call_deferred("queue_free")
