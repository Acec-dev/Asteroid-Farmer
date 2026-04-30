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
	var time_left = explosion_delay - _age
	if time_left < 1.0:
		queue_redraw()

func _draw() -> void:
	# Draw a mine shape - circular with spikes
	var time_left = explosion_delay - _age
	var color = Color.WHITE

	# Blink red when close to explosion
	if time_left < 1.0:
		var blink_factor = sin(_age * blink_speed * PI * 2.0) * 0.5 + 0.5
		color = Color.WHITE.lerp(Color.RED, blink_factor)

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

	# Spawn blast radius annulus visual
	var blast_ring = _BlastRadiusRing.new()
	blast_ring.radius = explosion_radius
	blast_ring.global_position = global_position
	var scene_root = owner if owner else get_tree().current_scene
	scene_root.add_child(blast_ring)

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


class _BlastRadiusRing extends Node2D:
	var radius: float = 1750.0
	var _squares: Array[Vector2] = []
	var _sizes: Array[float] = []
	var _alpha: float = 0.8
	const FADE_DURATION := 0.6

	func _ready() -> void:
		# Generate scattered squares around the blast radius edge
		var num_squares := 120
		for i in range(num_squares):
			var angle = randf() * TAU
			var r = radius + randf_range(-2.5, 2.5)
			_squares.append(Vector2(cos(angle), sin(angle)) * r)
			_sizes.append(1.0 if randf() > 0.4 else 2.0)
		# Auto-remove after fade
		var tween = create_tween()
		tween.tween_property(self, "_alpha", 0.0, FADE_DURATION)
		tween.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var sq_color = Color(1.0, 1.0, 1.0, _alpha)
		for i in range(_squares.size()):
			var pos = _squares[i]
			var sz = _sizes[i]
			draw_rect(Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), sq_color)
