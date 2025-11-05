extends RigidBody2D
class_name Asteroid

@export var radius: float = 28.0
@export var hit_points: int = 3
@export var child_scene: PackedScene # a smaller asteroid scene to spawn on split
@export var mineral_kind: StringName = "iron"
@export var mineral_drop_scene: PackedScene
@export var mineral_drop_count: int = 1
@export var debug_draw_path: bool = false
@export var particle_scene: PackedScene

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
		# Defer the break; don’t modify the tree/collision right now
		call_deferred("_break_safe")
	else:
		apply_central_impulse(Vector2(randf_range(-80, 80), randf_range(-80, 80)))

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
			# Fallback: timed self-destruct if you don’t have a GPUParticles2D under fx
			var t := Timer.new()
			t.one_shot = true
			t.wait_time = 2.0
			fx.add_child(t)
			t.timeout.connect(fx.queue_free)
			t.start()

	get_tree().current_scene.add_child(fx)

func _break_safe() -> void:
	_spawn_particles()
	
	# Drop minerals
	for i in mineral_drop_count:
		if mineral_drop_scene:
			var m = mineral_drop_scene.instantiate()
			m.global_position = global_position + Vector2(randf_range(-8,8), randf_range(-8,8))
			get_tree().current_scene.add_child(m)

	# Split into children (if any)
	if child_scene and radius > 10.0:
		for i in 2:
			var child: RigidBody2D = child_scene.instantiate()
			child.global_position = global_position + Vector2(randf_range(-12,12), randf_range(-12,12))
			# keep same straight path/speed if you store them
			if child.has_method("setup_motion"):
				child.setup_motion(child.global_position, child.global_position + _dir, _speed)
			else:
				child.linear_velocity = linear_velocity
			get_tree().current_scene.add_child(child)

	# Defer freeing too (extra safe), in case _break_safe was called from a non-deferred context
	call_deferred("queue_free")
