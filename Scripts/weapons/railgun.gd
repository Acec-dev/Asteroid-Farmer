## Railgun weapon - Fires a powerful piercing shot that damages all asteroids in a line
## High single-shot damage with penetration, manual fire with cooldown
class_name Railgun
extends WeaponBase

## Weapon properties
@export var max_range: float = 2500.0  # Longer range than basic shots
@export var pierce_damage_falloff: float = 0.2  # 20% damage reduction per pierce
@export var max_pierce_count: int = 20  # Maximum asteroids to pierce through
@export var min_pierce_damage: float = 0.5  # Stop piercing below this damage

## Visual properties
@export var beam_width: float = 20.0  # Width of the railgun beam
@export var beam_duration: float = 0.15  # How long the beam visual persists
@export var beam_color: Color = Color(0.2, 0.8, 1.0, 1.0)  # Cyan/electric blue
@export var beam_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)  # White flash

## Visual nodes
var beam_line: Line2D = null

func _init() -> void:
	weapon_name = "Railgun"
	base_damage = 3.0
	base_cooldown = 2.0  # 2 second cooldown
	enabled = false  # Requires unlock

func _ready_weapon() -> void:
	# Create visual components
	beam_line = Line2D.new()
	beam_line.width = beam_width
	beam_line.default_color = beam_color
	beam_line.visible = false
	add_child(beam_line)

func _process(delta: float) -> void:
	# Fade out beam visual
	if beam_line and beam_line.visible:
		var alpha: float = beam_line.default_color.a
		alpha -= delta / beam_duration
		if alpha <= 0.0:
			beam_line.visible = false
		else:
			var color: Color = beam_line.default_color
			color.a = alpha
			beam_line.default_color = color

## Execute railgun shot
func _execute_fire() -> void:
	if not _owner_node:
		return

	var from_position = _owner_node.global_position
	var direction = Vector2.RIGHT.rotated(_owner_node.rotation)

	_fire_piercing_shot(from_position, direction)

## Fire a piercing shot that hits multiple targets
func _fire_piercing_shot(from_position: Vector2, direction: Vector2) -> void:
	# Perform piercing raycast
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var current_pierce_damage: float = current_damage
	var all_hits: Array = []

	# Cast ray to find all objects in line
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		from_position,
		from_position + direction * max_range
	)
	query.collision_mask = 0x7FFFFFFF  # All layers except layer 31 (minerals)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	# Collect all hits along the beam path
	var excluded_objects: Array = []
	var pierce_count: int = 0

	while pierce_count < max_pierce_count:
		# Exclude already hit objects
		if excluded_objects.size() > 0:
			query.exclude = excluded_objects.duplicate()

		var result: Dictionary = space_state.intersect_ray(query)

		if result.is_empty():
			break

		var hit_object: Object = result.collider
		all_hits.append({
			"object": hit_object,
			"position": result.position,
			"damage": current_pierce_damage
		})

		# Add to excluded list for next raycast
		excluded_objects.append(result.rid)

		# Reduce damage for next pierce
		current_pierce_damage *= (1.0 - pierce_damage_falloff)
		pierce_count += 1

		# If damage is too low, stop piercing
		if current_pierce_damage < min_pierce_damage:
			break

	# Apply damage to all hit objects
	for hit_data in all_hits:
		var hit_object: Object = hit_data.object
		_apply_railgun_damage(hit_object, hit_data.damage)

	# Visual feedback
	_show_beam_effect(from_position, from_position + direction * max_range, all_hits)

	# Play sound effect (if sound node exists in parent)
	if _owner_node and _owner_node.has_node("RailgunSound"):
		_owner_node.get_node("RailgunSound").play()

	print("Railgun fired! Hit ", all_hits.size(), " targets")

## Apply damage to a hit object
func _apply_railgun_damage(hit_object: Object, damage: float) -> void:
	# Don't damage off-screen targets
	if hit_object is Node2D and not ScreenUtils.is_node_on_screen(hit_object):
		return

	# Try railgun-specific damage method first
	if hit_object.has_method("hit_by_railgun"):
		hit_object.hit_by_railgun(self, damage)
	elif hit_object.has_method("hit_by_projectile"):
		# Fallback to standard damage method
		# Apply damage as multiple hits (asteroids expect integer hits)
		var hits_to_apply = int(damage)
		for i in hits_to_apply:
			hit_object.hit_by_projectile(_owner_node)
	else:
		# Try take_damage method
		if hit_object.has_method("take_damage"):
			hit_object.take_damage(damage)

## Show beam visual effect
func _show_beam_effect(start_pos: Vector2, end_pos: Vector2, hits: Array) -> void:
	if not beam_line:
		return

	# Show beam visual
	beam_line.clear_points()
	beam_line.add_point(to_local(start_pos))

	# If we hit something, end beam at last hit, otherwise full length
	if hits.size() > 0:
		var last_hit: Vector2 = hits[hits.size() - 1].position
		beam_line.add_point(to_local(last_hit))
	else:
		beam_line.add_point(to_local(end_pos))

	# Reset beam visual with white flash
	beam_line.default_color = beam_flash_color
	beam_line.visible = true

	# Fade to cyan over time (handled in _process)
	await get_tree().create_timer(beam_duration * 0.2).timeout
	if beam_line:
		beam_line.default_color = beam_color

## Override activation - railgun fires once per activation
func _on_activated() -> void:
	# Railgun is manual fire - it will fire once when can_fire() returns true
	pass

func _on_deactivated() -> void:
	# Nothing special on deactivation
	pass

## Apply railgun-specific upgrades
func _apply_custom_upgrade(stats: Dictionary) -> void:
	if stats.has("range"):
		max_range = stats.range
	if stats.has("pierce_falloff"):
		pierce_damage_falloff = stats.pierce_falloff
	if stats.has("max_pierce"):
		max_pierce_count = stats.max_pierce

	print("Railgun upgraded - Damage: ", current_damage, " Cooldown: ", current_cooldown, "s, Pierce falloff: ", pierce_damage_falloff * 100, "%")

## Get weapon status for UI
func get_status_text() -> String:
	if can_fire():
		return "RAILGUN: READY"
	else:
		var percent: int = int((1.0 - (_cooldown_timer / current_cooldown)) * 100)
		return "RAILGUN: %d%%" % percent

## Get cooldown progress (0.0 to 1.0)
func get_cooldown_progress() -> float:
	if can_fire():
		return 1.0
	return 1.0 - (_cooldown_timer / current_cooldown)
