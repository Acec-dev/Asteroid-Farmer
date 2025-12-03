## Primary dual-cannon hitscan weapon
## Fires two simultaneous raycast shots from muzzle positions
class_name PrimaryCannon
extends WeaponBase

@export var muzzle_separation: float = 16.0
@export var max_range: float = 2000.0
@export var visual_projectile_speed: float = 2500.0

var projectile_scene: PackedScene = preload("res://Scenes/projectile.tscn")

func _init() -> void:
	weapon_name = "Primary Cannon"
	base_damage = 1.0
	base_cooldown = 0.5
	enabled = true  # Primary weapon is always enabled

func _ready_weapon() -> void:
	# Auto-activate so it fires continuously
	activate()

func _execute_fire() -> void:
	if not _owner_node:
		return

	var forward := Vector2.RIGHT.rotated(_owner_node.rotation)
	var left_offset := Vector2(0, -muzzle_separation).rotated(_owner_node.rotation)
	var right_offset := Vector2(0, muzzle_separation).rotated(_owner_node.rotation)

	_hitscan_shot(_owner_node.global_position + left_offset, forward)
	_hitscan_shot(_owner_node.global_position + right_offset, forward)

func _hitscan_shot(spawn_pos: Vector2, direction: Vector2) -> void:
	# Create the raycast
	var space_state = _owner_node.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		spawn_pos,
		spawn_pos + direction * max_range
	)

	# Try all collision layers to ensure we hit asteroids
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	# Spawn visual projectile
	_spawn_visual_projectile(spawn_pos, direction, result)

	# Apply damage if we hit something
	if result and result.collider:
		var hit_object = result.collider
		if hit_object.has_method("hit_by_projectile"):
			# Apply damage multiple times to match damage_per_shot
			for i in int(current_damage):
				hit_object.hit_by_projectile(_owner_node)

func _spawn_visual_projectile(spawn_pos: Vector2, direction: Vector2, raycast_result: Dictionary) -> void:
	if projectile_scene == null:
		return

	var p = projectile_scene.instantiate()
	p.global_position = spawn_pos
	p.rotation = direction.angle()

	# Configure as visual-only
	if p.has_method("configure_as_visual"):
		var target_distance: float
		if raycast_result and raycast_result.collider:
			# Stop at hit point
			target_distance = spawn_pos.distance_to(raycast_result.position)
		else:
			# Travel max range
			target_distance = max_range

		p.configure_as_visual(visual_projectile_speed, target_distance)

	# Add to owner's scene root (works with SubViewport)
	var scene_root = _owner_node.owner if _owner_node.owner else _owner_node.get_tree().current_scene
	scene_root.add_child(p)

func _apply_custom_upgrade(stats: Dictionary) -> void:
	# Apply primary cannon specific upgrades
	if stats.has("range"):
		max_range = stats.range
	if stats.has("projectile_speed"):
		visual_projectile_speed = stats.projectile_speed
