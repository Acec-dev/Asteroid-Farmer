## Mine layer weapon that places explosive mines
## Automatic placement - mines are deployed at regular intervals
class_name MineLayer
extends WeaponBase

var mine_scene: PackedScene

func _init() -> void:
	weapon_name = "Mine Layer"
	base_damage = 1.0
	base_cooldown = 3.0  # 3 seconds between mine placements (configurable)
	enabled = false  # Requires unlock

func _ready_weapon() -> void:
	# Try to load mine scene
	if ResourceLoader.exists("res://Scenes/mine.tscn"):
		mine_scene = load("res://Scenes/mine.tscn")
	else:
		push_warning("MineLayer: Mine scene not found at res://Scenes/mine.tscn")

	# Auto-activate so mines are placed automatically
	activate()

func _execute_fire() -> void:
	if not _owner_node:
		return

	_place_mine()

func _place_mine() -> void:
	if not mine_scene:
		push_error("MineLayer: No mine scene loaded!")
		return

	var mine = mine_scene.instantiate()
	mine.global_position = _owner_node.global_position

	# Apply damage upgrade to mine if it has the property
	if "damage" in mine:
		mine.damage = int(current_damage)

	# Add to owner's scene root (works with SubViewport)
	var scene_root = _owner_node.owner if _owner_node.owner else _owner_node.get_tree().current_scene
	scene_root.add_child(mine)
	print("Mine placed at: ", mine.global_position)

func _apply_custom_upgrade(stats: Dictionary) -> void:
	# Apply mine-specific upgrades
	if stats.has("explosion_radius"):
		# We could store this and pass it to mines when spawned
		pass
