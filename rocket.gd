extends Area2D

@export var explosion_scene: PackedScene
@onready var particles = $rocket_particles
var explosion_delay: float = 0.1

# Bézier movement
var target_asteroid: Node2D = null
var start_position: Vector2
var control_point: Vector2
var travel_time: float = 1.5
var current_time: float = 0.0
var is_locked: bool = false
var is_exploding: bool = false

# Rocket properties
var base_speed: float = 200.0
var detection_range: float = 500.0
var detection_angle: float = 60.0
var rotation_speed: float = 5.0

func _ready():
	body_entered.connect(_on_body_entered)
	add_to_group("rockets")
	
	# Fix particle rotation
	if particles:
		particles.local_coords = true
		particles.emitting = true

func _process(delta):
	if is_exploding:
		return
		
	if not is_locked:
		find_nearest_asteroid()
		
		# Move forward - sprite points up, so use UP
		var velocity = Vector2.UP.rotated(rotation) * base_speed
		global_position += velocity * delta
	else:
		if target_asteroid and is_instance_valid(target_asteroid):
			current_time += delta
			var t = clamp(current_time / travel_time, 0.0, 1.0)
			
			var end_position = target_asteroid.global_position
			var current_pos = quadratic_bezier(start_position, control_point, end_position, t)
			
			var next_t = clamp(t + 0.01, 0.0, 1.0)
			var next_pos = quadratic_bezier(start_position, control_point, end_position, next_t)
			
			global_position = current_pos
			
			# Calculate direction of travel
			var direction = (next_pos - current_pos).normalized()
			if direction.length() > 0:
				# For upward-facing sprite, subtract 90 degrees (PI/2)
				var target_rotation = direction.angle() + deg_to_rad(90)
				rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
		else:
			unlock_target()

func find_nearest_asteroid():
	"""Find the best asteroid in front of the rocket"""
	var asteroids = get_tree().get_nodes_in_group("asteroids")
	var best_target = null
	var best_score = -1.0
	
	for asteroid in asteroids:
		var distance = global_position.distance_to(asteroid.global_position)
		
		# Skip if out of range
		if distance > detection_range:
			continue
		
		# Check if asteroid is in front cone
		var direction_to = (asteroid.global_position - global_position).normalized()
		# For upward-facing sprite, forward is UP rotated by current rotation
		var forward = Vector2.UP.rotated(rotation)
		var dot_product = forward.dot(direction_to)
		
		# Only consider targets in front cone
		var angle_threshold = cos(deg_to_rad(detection_angle / 2.0))
		
		if dot_product > angle_threshold:
			# Score: prioritize closer targets that are more centered
			var score = dot_product / (distance * 0.01)
			
			if score > best_score:
				best_score = score
				best_target = asteroid
	
	if best_target:
		lock_onto_target(best_target)

func lock_onto_target(asteroid: Node2D):
	"""Lock onto an asteroid and start Bézier movement"""
	target_asteroid = asteroid
	is_locked = true
	start_position = global_position
	current_time = 0.0
	
	# Calculate control point for arc
	var end_position = asteroid.global_position
	var midpoint = (start_position + end_position) / 2.0
	var direction = (end_position - start_position).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)
	
	# Randomize arc direction and height for variety
	var arc_direction = 1 if randf() > 0.5 else -1
	var arc_height = randf_range(50.0, 150.0)
	control_point = midpoint + perpendicular * arc_height * arc_direction

func unlock_target():
	"""Unlock from target and resume searching"""
	target_asteroid = null
	is_locked = false
	current_time = 0.0

func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	"""Calculate position on quadratic Bézier curve"""
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func hit_asteroid():
	"""Called when rocket hits asteroid"""
	
	_spawn_particles()

	if target_asteroid and is_instance_valid(target_asteroid):
		target_asteroid.queue_free()
	
	# Hide rocket and disable collision immediately
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Destroy rocket after delay
	await get_tree().create_timer(explosion_delay).timeout
	queue_free()

# Collision detection
func _on_body_entered(body):
	if body.is_in_group("asteroids"):
		hit_asteroid()

func _spawn_particles() -> void:
	if explosion_scene == null:
		return
	var fx = explosion_scene.instantiate()
	fx.global_position = global_position
	fx.global_rotation = rotation

	# Ensure it cleans up by itself
	if fx is GPUParticles2D:
		fx.one_shot = true
		fx.emitting = true
		fx.finished.connect(fx.queue_free)
	else:
		var p := fx.get_node_or_null("GPUParticles2D")
		if p:
			p.one_shot = true
			p.emitting = true
			p.finished.connect(fx.queue_free)
		else:
			var t := Timer.new()
			t.one_shot = true
			t.wait_time = 2.0
			fx.add_child(t)
			t.timeout.connect(fx.queue_free)
			t.start()

	get_tree().current_scene.add_child(fx)
