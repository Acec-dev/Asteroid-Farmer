# Rocket.gd - Projectile that damages asteroids properly
extends Area2D

@export var speed: float = 400.0
@export var lifetime: float = 3.0
@export var damage: int = 1  # Damage per hit
@export var explosion_radius: float = 80.0
@export var detection_radius: float = 500.0  # How far rockets can detect asteroids
@export var rotation_speed: float = 3.0  # How fast rockets turn (radians per second)

var _age: float = 0.0
var _target: Node = null  # Current asteroid target
var _has_exploded: bool = false  # Guard against double-explosion

func _ready() -> void:
	queue_redraw()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Find or update target
	if not _target or not is_instance_valid(_target):
		_target = _find_nearest_asteroid()

	# Home in on target if we have one
	if _target and is_instance_valid(_target):
		var target_direction = ((_target as Node2D).global_position - global_position).normalized()
		var current_direction = Vector2.RIGHT.rotated(rotation)

		# Calculate the angle to rotate toward the target
		var angle_to_target = current_direction.angle_to(target_direction)

		# Rotate toward target at rotation_speed
		var max_rotation = rotation_speed * delta
		if abs(angle_to_target) < max_rotation:
			rotation += angle_to_target
		else:
			rotation += sign(angle_to_target) * max_rotation

	# Move forward in current direction
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

	_age += delta
	if _age >= lifetime:
		queue_free()

func _draw() -> void:
	# Draw a rocket shape
	var points = PackedVector2Array([
		Vector2(8, 0),
		Vector2(-4, -3),
		Vector2(-4, 3),
		Vector2(8, 0)
	])
	draw_colored_polygon(points, Color.WHITE)
	# Tail fins
	draw_line(Vector2(-4, -3), Vector2(-8, -6), Color.WHITE, 1.0)
	draw_line(Vector2(-4, 3), Vector2(-8, 6), Color.WHITE, 1.0)

func _on_body_entered(body: Node) -> void:
	if _has_exploded:
		return
	# Only hit on-screen targets
	if body.has_method("hit_by_projectile") and ScreenUtils.is_node_on_screen(body):
		# Apply damage based on rocket's damage value
		for i in damage:
			body.hit_by_projectile(self)
		_explode(body)

func _on_area_entered(area: Area2D) -> void:
	if _has_exploded:
		return
	# Only hit on-screen targets
	if area.has_method("hit_by_projectile") and ScreenUtils.is_node_on_screen(area):
		for i in damage:
			area.hit_by_projectile(self)
		_explode(area)

func _explode(direct_hit_target: Node = null) -> void:
	if _has_exploded:
		return
	_has_exploded = true
	AudioManager.play_sfx("explode_rocket")

	# Damage nearby asteroids in explosion radius (splash damage)
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
		# Skip self and the direct-hit target (already damaged above)
		if obj and obj != self and obj != direct_hit_target and obj.has_method("hit_by_projectile") and ScreenUtils.is_node_on_screen(obj):
			for i in damage:
				obj.hit_by_projectile(self)

	queue_free()

func _find_nearest_asteroid() -> Node:
	# Query for nearby asteroids using physics
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results = space_state.intersect_shape(query, 32)

	# Find the closest asteroid that is on-screen
	var nearest: Node = null
	var nearest_distance: float = INF

	for result in results:
		var obj = result.collider
		# Check if it's an asteroid (has hit_by_projectile method) and is on screen
		if obj and obj.has_method("hit_by_projectile") and ScreenUtils.is_node_on_screen(obj):
			var distance = global_position.distance_to((obj as Node2D).global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = obj

	return nearest
