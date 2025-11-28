## Continuous beam weapon with ramping damage
## Hold to fire, damage increases the longer you focus on a target
class_name LaserBeam
extends WeaponBase

@export var max_range: float = 1200.0
@export var base_beam_damage: float = 2.0  # Damage per tick at minimum
@export var max_beam_damage: float = 50.0  # Maximum damage per tick
@export var ramp_time: float = 3.0  # Time to reach max damage (seconds)
@export var damage_tick_rate: float = 0.1  # How often to apply damage (seconds)
@export var beam_width: float = 3.0

# Tracking
var _current_target: Node = null
var _time_on_target: float = 0.0
var _damage_timer: float = 0.0

# Visual effects
var _beam_color: Color = Color(1.0, 0.3, 0.3)  # Red laser
var _beam_end_point: Vector2 = Vector2.ZERO
var _hit_point: Vector2 = Vector2.ZERO
var _hitting_something: bool = false

func _init() -> void:
	weapon_name = "Laser Beam"
	base_damage = 2.0
	base_cooldown = 0.0  # Continuous weapon, no cooldown
	enabled = false  # Requires unlock

func _ready_weapon() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if not _is_active or not enabled:
		_reset_target()
		queue_redraw()
		return
	
	# Update laser position and rotation to match owner (player)
	if _owner_node:
		global_position = _owner_node.global_position
		rotation = _owner_node.rotation

	# Perform raycast
	var space_state = get_world_2d().direct_space_state
	var forward = Vector2.RIGHT.rotated(_owner_node.rotation)
	var start_pos = _owner_node.global_position
	var end_pos = start_pos + forward * max_range

	var query = PhysicsRayQueryParameters2D.create(start_pos, end_pos)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	if result and result.collider:
		_hitting_something = true
		_hit_point = result.position
		_beam_end_point = to_local(result.position)

		var hit_target = result.collider

		# Check if we're still hitting the same target
		if hit_target == _current_target:
			_time_on_target += delta
		else:
			# New target - reset ramp
			_current_target = hit_target
			_time_on_target = 0.0

		# Apply damage at tick rate
		_damage_timer += delta
		if _damage_timer >= damage_tick_rate:
			_damage_timer = 0.0
			_apply_damage(hit_target)
	else:
		# Not hitting anything
		_hitting_something = false
		_beam_end_point = Vector2.RIGHT * max_range
		_reset_target()

	queue_redraw()

func _apply_damage(target: Node) -> void:
	if not target or not target.has_method("hit_by_projectile"):
		return

	# Calculate ramping damage
	var ramp_progress = min(_time_on_target / ramp_time, 1.0)
	var current_beam_damage = lerp(base_beam_damage, max_beam_damage, ramp_progress)

	# Apply damage (convert to hits - asteroids expect integer hits)
	if current_beam_damage >= 1.0:
		var hits_to_apply = int(current_beam_damage)
		for i in hits_to_apply:
			target.hit_by_projectile(_owner_node)

func _reset_target() -> void:
	_current_target = null
	_time_on_target = 0.0

func _draw() -> void:
	if not _is_active or not enabled:
		return

	# Calculate beam intensity based on ramp
	var ramp_progress = min(_time_on_target / ramp_time, 1.0)
	var beam_alpha = lerp(0.4, 1.0, ramp_progress)
	var beam_width_current = lerp(beam_width, beam_width * 2.0, ramp_progress)

	# Draw main beam
	var color_with_alpha = Color(_beam_color.r, _beam_color.g, _beam_color.b, beam_alpha)
	draw_line(Vector2.ZERO, _beam_end_point, color_with_alpha, beam_width_current)

	# Draw outer glow
	var glow_color = Color(_beam_color.r, _beam_color.g, _beam_color.b, beam_alpha * 0.3)
	draw_line(Vector2.ZERO, _beam_end_point, glow_color, beam_width_current + 4.0)

	# Draw impact effect if hitting something
	if _hitting_something:
		var impact_size = 8.0 + ramp_progress * 8.0
		draw_circle(_beam_end_point, impact_size, color_with_alpha)
		draw_circle(_beam_end_point, impact_size + 4.0, glow_color)

func _on_activated() -> void:
	queue_redraw()

func _on_deactivated() -> void:
	_reset_target()
	queue_redraw()

func get_ramp_percentage() -> float:
	"""Returns the current damage ramp percentage (0.0 to 1.0)"""
	return min(_time_on_target / ramp_time, 1.0)

func _apply_custom_upgrade(stats: Dictionary) -> void:
	# Apply laser-specific upgrades
	if stats.has("range"):
		max_range = stats.range
	if stats.has("max_damage"):
		max_beam_damage = stats.max_damage
	if stats.has("ramp_time"):
		ramp_time = stats.ramp_time

## Override can_fire for continuous weapons - always can fire when active
func _can_fire_custom() -> bool:
	return true

## Override update to use continuous firing logic
func update_weapon(delta: float) -> void:
	# Continuous weapon doesn't use the standard firing logic
	# Just update cooldown timer if needed
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
