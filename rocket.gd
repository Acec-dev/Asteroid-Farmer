# Rocket.gd - Projectile that damages asteroids properly
extends Area2D

@export var speed: float = 400.0
@export var lifetime: float = 3.0
@export var damage: int = 1  # Damage per hit (asteroids have 3 HP)
@export var explosion_radius: float = 80.0

var _age: float = 0.0

func _ready() -> void:
	queue_redraw()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
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
	if body.has_method("hit_by_projectile"):
		print("Rocket hit body: ", body.name)
		# Apply damage - asteroid needs multiple hits
		body.hit_by_projectile(self)
		_explode()

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("hit_by_projectile"):
		print("Rocket hit area: ", area.name)
		area.hit_by_projectile(self)
		_explode()

func _explode() -> void:
	# TODO: Add explosion visual/particles here
	print("Rocket exploded!")
	
	# Damage nearby asteroids in explosion radius
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
			print("  Explosion hit: ", obj.name)
			obj.hit_by_projectile(self)
	
	queue_free()
