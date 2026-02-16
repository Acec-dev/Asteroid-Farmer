## Manages all weapons attached to the player
## Handles weapon registration, activation, and upgrade synchronization
class_name WeaponManager
extends Node

## Reference to the player/owner
var owner_node: Node2D

## All registered weapons
var weapons: Array[WeaponBase] = []

## Weapon slots by type
var primary_weapon: WeaponBase = null
var secondary_weapons: Array[WeaponBase] = []

## Input mapping for weapons
var input_map: Dictionary = {}

func _ready() -> void:
	# Owner should be set before ready
	if not owner_node:
		owner_node = get_parent() as Node2D

	# Connect to GameState for upgrade updates
	if GameState.has_signal("upgrades_changed"):
		GameState.upgrades_changed.connect(_on_upgrades_changed)

func _process(delta: float) -> void:
	# Update all weapons each frame
	for weapon in weapons:
		if weapon.enabled:
			weapon.update_weapon(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Handle weapon input
	for input_action in input_map.keys():
		if event.is_action_pressed(input_action):
			activate_weapon(input_map[input_action])
		elif event.is_action_released(input_action):
			deactivate_weapon(input_map[input_action])

## Add a weapon to the manager
func add_weapon(weapon: WeaponBase, slot_type: String = "secondary") -> void:
	if weapon in weapons:
		push_warning("Weapon already registered: " + weapon.weapon_name)
		return

	add_child(weapon)
	weapon.initialize(owner_node)
	weapons.append(weapon)

	if slot_type == "primary":
		primary_weapon = weapon
	else:
		secondary_weapons.append(weapon)

	print("Weapon registered: " + weapon.weapon_name)

## Remove a weapon from the manager
func remove_weapon(weapon: WeaponBase) -> void:
	if weapon not in weapons:
		return

	weapons.erase(weapon)
	secondary_weapons.erase(weapon)
	if primary_weapon == weapon:
		primary_weapon = null

	weapon.queue_free()

## Get weapon by name
func get_weapon(weapon_name: String) -> WeaponBase:
	for weapon in weapons:
		if weapon.weapon_name == weapon_name:
			return weapon
	return null

## Activate a specific weapon
func activate_weapon(weapon_name: String) -> void:
	var weapon = get_weapon(weapon_name)
	if weapon and weapon.enabled:
		weapon.activate()

## Deactivate a specific weapon
func deactivate_weapon(weapon_name: String) -> void:
	var weapon = get_weapon(weapon_name)
	if weapon:
		weapon.deactivate()

## Map input action to weapon
func bind_input(action_name: String, weapon_name: String) -> void:
	input_map[action_name] = weapon_name

## Sync all weapon stats with GameState upgrades
func sync_upgrades() -> void:
	if not GameState:
		return

	# Sync weapon upgrades
	if GameState.upgrades.has("weapons"):
		for weapon_name in GameState.upgrades.weapons.keys():
			var weapon = get_weapon(weapon_name)
			if weapon:
				var upgrade_data = GameState.upgrades.weapons[weapon_name]
				var stats = _get_weapon_stats(weapon_name, upgrade_data)
				weapon.apply_upgrade(upgrade_data.get("level", 0), stats)

## Get weapon stats based on upgrade data
func _get_weapon_stats(weapon_name: String, upgrade_data: Dictionary) -> Dictionary:
	var stats = {
		"enabled": upgrade_data.get("unlocked", false),
		"level": upgrade_data.get("level", 0)
	}

	# Rocket Launcher uses formula-based infinite upgrades
	if weapon_name == "Rocket Launcher":
		stats["damage"] = GameState.get_rocket_damage()
		stats["cooldown"] = GameState.get_rocket_cooldown()
		stats["speed"] = GameState.get_rocket_speed()
		return stats

	# Mine Layer uses formula-based infinite upgrades
	if weapon_name == "Mine Layer":
		stats["cooldown"] = GameState.get_mine_cooldown()
		stats["explosion_radius"] = GameState.get_mine_blast_radius()
		return stats

	var level = upgrade_data.get("level", 0)

	# Generic handler for all "*_values" arrays
	for key in upgrade_data.keys():
		if key.ends_with("_values") and upgrade_data[key] is Array:
			var values_array = upgrade_data[key]
			if level < values_array.size():
				# Extract stat name (remove "_values" suffix)
				var stat_name = key.substr(0, key.length() - 7)
				stats[stat_name] = values_array[level]

	return stats

## Called when GameState upgrades change
func _on_upgrades_changed() -> void:
	sync_upgrades()

## Enable/disable all weapons
func set_weapons_enabled(enabled: bool) -> void:
	for weapon in weapons:
		if enabled:
			# Only enable if unlocked in GameState
			if GameState.upgrades.has("weapons"):
				var weapon_data = GameState.upgrades.weapons.get(weapon.weapon_name, {})
				weapon.enabled = weapon_data.get("unlocked", false)
		else:
			weapon.enabled = false
