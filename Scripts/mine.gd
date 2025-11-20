# Mine.gd - Placeable mine that explodes after a timer and damages nearby asteroids
extends Area2D

@export var explosion_delay: float = 3.0  # Time before mine explodes
@export var explosion_radius: float = 150.0  # Damage radius
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
	# Blink faster as we get closer to explosion
	var time_left = explosion_delay - _age
	if time_left < 1.0:
		# Increase blink speed in the last second
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
	print("Mine exploded at position: ", global_position)

	# Spawn explosion particle effect
	if _explosion_particle_scene:
		var particles = _explosion_particle_scene.instantiate()
		get_tree().current_scene.add_child(particles)
		particles.global_position = global_position

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
	var hit_count = 0
	for result in results:
		var obj = result.collider
		if obj and obj != self and obj.has_method("hit_by_projectile"):
			print("  Mine explosion hit: ", obj.name)
			obj.hit_by_projectile(self)
			hit_count += 1

	print("  Total asteroids damaged: ", hit_count)

	# Remove the mine
	queue_free()
