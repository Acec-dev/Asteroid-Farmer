## Rocket launcher weapon that spawns homing rockets
## Fires automatically at intervals when enabled
class_name RocketLauncher
extends WeaponBase

var rocket_scene: PackedScene = preload("res://Scenes/rocket.tscn")
var _rocket_speed: float = 400.0

func _init() -> void:
	weapon_name = "Rocket Launcher"
	base_damage = 1.0
	base_cooldown = 2.0  # Fire every 2 seconds
	enabled = false  # Requires unlock

func _ready_weapon() -> void:
	# Rocket launcher auto-fires, so activate it by default
	activate()

func _execute_fire() -> void:
	if not _owner_node:
		return

	_spawn_rocket()

func _spawn_rocket() -> void:
	if not rocket_scene:
		push_error("RocketLauncher: No rocket scene assigned!")
		return

	var rocket = rocket_scene.instantiate()
	rocket.global_position = _owner_node.global_position
	rocket.rotation = _owner_node.rotation

	# Apply damage upgrade to rocket
	if "damage" in rocket:
		rocket.damage = int(current_damage)

	# Apply speed upgrade to rocket
	if "speed" in rocket:
		rocket.speed = _rocket_speed

	# Add to owner's scene root (works with SubViewport)
	var scene_root = _owner_node.owner if _owner_node.owner else _owner_node.get_tree().current_scene
	scene_root.add_child(rocket)

func _apply_custom_upgrade(stats: Dictionary) -> void:
	if stats.has("speed"):
		_rocket_speed = stats.speed
