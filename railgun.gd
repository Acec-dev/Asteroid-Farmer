extends Node2D

# Railgun weapon - Fires a powerful piercing shot that damages all asteroids in a line
# Tactical role: High single-shot damage with penetration, manual fire with cooldown

# Weapon properties
var max_range: float = 2500.0  # Longer range than basic shots
var damage_per_hit: float = 3.0  # High damage per asteroid hit
var cooldown_time: float = 2.0  # 2 second cooldown between shots
var pierce_damage_falloff: float = 0.2  # 20% damage reduction per pierce
var beam_width: float = 20.0  # Width of the railgun beam for visuals

# Visual properties
var beam_duration: float = 0.15  # How long the beam visual persists
var beam_color: Color = Color(0.2, 0.8, 1.0, 1.0)  # Cyan/electric blue
var beam_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)  # White flash

# Internal state
var cooldown_remaining: float = 0.0
var is_ready_to_fire: bool = true

# Visual nodes
var beam_line: Line2D = null
var muzzle_flash: Sprite2D = null

func _ready() -> void:
	# Create visual components
	beam_line = Line2D.new()
	beam_line.width = beam_width
	beam_line.default_color = beam_color
	beam_line.visible = false
	add_child(beam_line)

	# Set process to handle cooldown
	set_process(true)

func _process(delta: float) -> void:
	# Handle cooldown
	if cooldown_remaining > 0.0:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0.0:
			is_ready_to_fire = true
			cooldown_remaining = 0.0

	# Fade out beam visual
	if beam_line.visible:
		var alpha: float = beam_line.default_color.a
		alpha -= delta / beam_duration
		if alpha <= 0.0:
			beam_line.visible = false
		else:
			var color: Color = beam_line.default_color
			color.a = alpha
			beam_line.default_color = color

func can_fire() -> bool:
	return is_ready_to_fire

func get_cooldown_progress() -> float:
	# Returns 0.0 to 1.0, where 1.0 is ready to fire
	if is_ready_to_fire:
		return 1.0
	return 1.0 - (cooldown_remaining / cooldown_time)

func fire(from_position: Vector2, direction: Vector2) -> void:
	if not is_ready_to_fire:
		return

	# Start cooldown
	is_ready_to_fire = false
	cooldown_remaining = cooldown_time

	# Perform piercing raycast
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var current_damage: float = damage_per_hit
	var all_hits: Array = []

	# Cast ray to find all objects in line
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		from_position,
		from_position + direction * max_range
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	# Collect all hits along the beam path
	var excluded_objects: Array = []
	var max_pierce_count: int = 20  # Prevent infinite loops
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
			"damage": current_damage
		})

		# Add to excluded list for next raycast
		excluded_objects.append(result.rid)

		# Reduce damage for next pierce
		current_damage *= (1.0 - pierce_damage_falloff)
		pierce_count += 1

		# If damage is too low, stop piercing
		if current_damage < 0.5:
			break

	# Apply damage to all hit objects
	for hit_data in all_hits:
		var hit_object: Object = hit_data.object
		if hit_object.has_method("hit_by_railgun"):
			hit_object.hit_by_railgun(self, hit_data.damage)
		elif hit_object.has_method("hit_by_projectile"):
			# Fallback to standard damage method
			# Create a temporary object with damage property
			var damage_carrier: Node = Node.new()
			damage_carrier.set_meta("damage", hit_data.damage)
			hit_object.hit_by_projectile(damage_carrier)
			damage_carrier.queue_free()

	# Visual feedback
	_show_beam_effect(from_position, from_position + direction * max_range, all_hits)

	# Play sound effect (if sound node exists in parent)
	var player: Node = get_parent()
	if player and player.has_node("RailgunSound"):
		player.get_node("RailgunSound").play()

func _show_beam_effect(start_pos: Vector2, end_pos: Vector2, hits: Array) -> void:
	# Show beam visual
	beam_line.clear_points()
	beam_line.add_point(to_local(start_pos))

	# If we hit something, end beam at last hit, otherwise full length
	if hits.size() > 0:
		var last_hit: Vector2 = hits[hits.size() - 1].position
		beam_line.add_point(to_local(last_hit))
	else:
		beam_line.add_point(to_local(end_pos))

	# Reset beam visual
	beam_line.default_color = beam_flash_color  # Start with white flash
	beam_line.visible = true

	# Fade to cyan over time (handled in _process)
	await get_tree().create_timer(beam_duration * 0.2).timeout
	if beam_line:
		beam_line.default_color = beam_color

func get_status_text() -> String:
	if is_ready_to_fire:
		return "RAILGUN: READY"
	else:
		var percent: int = int(get_cooldown_progress() * 100)
		return "RAILGUN: %d%%" % percent
