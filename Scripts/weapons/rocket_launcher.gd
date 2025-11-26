## Rocket launcher weapon that spawns homing rockets
## Fires automatically at intervals when enabled
class_name RocketLauncher
extends WeaponBase

var rocket_scene: PackedScene = preload("res://Scenes/rocket.tscn")

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

	# Apply damage upgrade to rocket if it has the property
	if "damage" in rocket:
		rocket.damage = int(current_damage)

	_owner_node.get_tree().current_scene.add_child(rocket)
	print("Rocket spawned at: ", rocket.global_position)

func _apply_custom_upgrade(stats: Dictionary) -> void:
	# Apply rocket-specific upgrades
	if stats.has("fire_rate"):
		current_cooldown = 1.0 / stats.fire_rate  # Convert rate to cooldown
