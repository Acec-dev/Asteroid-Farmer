# Mine.gd - Placeable mine that explodes after a timer and damages nearby asteroids
extends Area2D

@export var explosion_delay: float = 2.0  # Time before mine explodes
@export var explosion_radius: float = 1750.0  # Damage radius
@export var damage: int = 1  # Damage dealt to each asteroid hit
@export var blink_speed: float = 5.0  # How fast the mine blinks before exploding

var _age: float = 0.0
var _explosion_particle_scene: PackedScene = preload("res://Scenes/rocket_explode_particle.tscn")

func _ready() -> void:
	queue_redraw()
	# Start the explosion timer
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = explosion_delay
	timer.timeout.connect(_explode)
	add_child(timer)
	timer.start()

func _process(delta: float) -> void:
	_age += delta
	# Redraw every frame for blast radius fade-in and blink effect
	queue_redraw()

func _draw() -> void:
	# Draw a mine shape - circular with spikes
	var time_left = explosion_delay - _age
	var color = Color.WHITE

	# Blink red when close to explosion
	if time_left < 1.0:
		var blink_factor = sin(_age * blink_speed * PI * 2.0) * 0.5 + 0.5
		color = Color.WHITE.lerp(Color.RED, blink_factor)

	# Draw blast radius indicator
	var radius_alpha = 0.06 + 0.04 * (1.0 - time_left / explosion_delay)
	if time_left < 1.0:
		radius_alpha = 0.12
	var radius_color = Color(1.0, 0.3, 0.2, radius_alpha)
	draw_circle(Vector2.ZERO, explosion_radius, radius_color)
	# Draw blast radius ring
	var ring_alpha = 0.15 + 0.15 * (1.0 - time_left / explosion_delay)
	if time_left < 1.0:
		ring_alpha = 0.4
	var ring_color = Color(1.0, 0.3, 0.2, ring_alpha)
	draw_arc(Vector2.ZERO, explosion_radius, 0, TAU, 64, ring_color, 1.5)

	# Draw main circle
	draw_circle(Vector2.ZERO, 8.0, color)

	# Draw spikes around the mine
	for i in range(8):
		var angle = i * PI / 4.0
		var inner = Vector2.RIGHT.rotated(angle) * 8.0
		var outer = Vector2.RIGHT.rotated(angle) * 12.0
		draw_line(inner, outer, color, 2.0)

func _explode() -> void:
	AudioManager.play_sfx("mine_explode")

	# Spawn explosion particle effect
	if _explosion_particle_scene:
		var fx = _explosion_particle_scene.instantiate()
		fx.global_position = global_position
		fx.global_rotation = rotation
		#Ensure it cleans up by itself
		if fx is GPUParticles2D:
			fx.one_shot = true
			fx.emitting = true
			fx.finished.connect(fx.queue_free)
		else:
			var p = fx.get_node_or_null("GPUParticles2D")
			if p:
				p.one_shot = true
				p.emitting = true
				p.finished.connect(fx.queue_free)
			else:
				#Fallback: timed self-destruct if you dont have GPUParticles under fx
				var t = Timer.new()
				t.one_shot = true
				t.wait_time = 2.0
				fx.add_child(t)
				t.timeout.connect(fx.queue_free)
				t.start()
		# Add to owner's scene root (works with SubViewport)
		var scene_root = owner if owner else get_tree().current_scene
		scene_root.add_child(fx)


	# Damage all nearby asteroids in explosion radius
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var results = space_state.intersect_shape(query, 32)
	for result in results:
		var obj = result.collider
		if obj and obj != self and obj.has_method("hit_by_projectile"):
			# Apply damage multiple times based on mine damage level
			for _hit in range(damage):
				obj.hit_by_projectile(self)

	# Remove the mine
	queue_free()
