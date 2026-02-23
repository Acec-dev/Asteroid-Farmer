## Mine layer weapon that places explosive mines
## Automatic placement - mines are deployed at regular intervals
class_name MineLayer
extends WeaponBase

var mine_scene: PackedScene
var _mine_explosion_radius: float = 1750.0
var _mine_damage: int = 1

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

	# Apply explosion radius and damage upgrades to mine
	if "explosion_radius" in mine:
		mine.explosion_radius = _mine_explosion_radius
	if "damage" in mine:
		mine.damage = _mine_damage

	# Add to owner's scene root (works with SubViewport)
	var scene_root = _owner_node.owner if _owner_node.owner else _owner_node.get_tree().current_scene
	scene_root.add_child(mine)

func _apply_custom_upgrade(stats: Dictionary) -> void:
	if stats.has("explosion_radius"):
		_mine_explosion_radius = stats.explosion_radius
	if stats.has("damage"):
		_mine_damage = stats.damage
