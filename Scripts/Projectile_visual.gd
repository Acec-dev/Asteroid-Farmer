# FILE: res://scripts/Projectile.gd
extends Area2D

@export var speed: float = 1000.0
@export var lifetime: float = 1.0

var _age: float = 0.0
var _is_visual_only: bool = false
var _visual_distance: float = 0.0
var _visual_traveled: float = 0.0

func _ready() -> void:
	# Visual: simple white line bullet
	queue_redraw()
	
	# Only connect signals if not visual-only
	if not _is_visual_only:
		area_entered.connect(_on_area_entered)
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var distance_this_frame = speed * delta
	position += Vector2.RIGHT.rotated(rotation) * distance_this_frame
	
	_age += delta
	
	# Handle visual-only projectile lifetime
	if _is_visual_only:
		_visual_traveled += distance_this_frame
		if _visual_traveled >= _visual_distance:
			queue_free()
			return
	
	# Handle normal projectile lifetime
	if _age >= lifetime:
		queue_free()

func _draw() -> void:
	draw_line(Vector2(-2, 0), Vector2(6, 0), Color.WHITE, 2.0)

func configure_speed(new_speed: float) -> void:
	speed = new_speed

func configure_as_visual(projectile_speed: float, travel_distance: float) -> void:
	"""Configure this projectile as visual-only (no collision detection)"""
	_is_visual_only = true
	speed = projectile_speed
	_visual_distance = travel_distance
	_visual_traveled = 0.0
	
	# Disable collision detection for visual projectiles
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	monitoring = false
	monitorable = false

func _on_area_entered(a: Area2D) -> void:
	if _is_visual_only:
		return
	if a.has_method("hit_by_projectile"):
		a.hit_by_projectile(self)
		queue_free()

func _on_body_entered(b: Node) -> void:
	if _is_visual_only:
		return
	if b.has_method("hit_by_projectile"):
		b.hit_by_projectile(self)
		queue_free()
