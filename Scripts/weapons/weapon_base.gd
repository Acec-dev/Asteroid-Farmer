## Base class for all weapons in the game
## Provides common interface and functionality that all weapons share
class_name WeaponBase
extends Node2D

## Emitted when the weapon fires
signal weapon_fired

## Emitted when weapon stats are updated
signal stats_updated

## Weapon configuration
@export var weapon_name: String = "Unnamed Weapon"
@export var base_damage: float = 1.0
@export var base_cooldown: float = 1.0
@export var energy_cost: float = 0.0
@export var enabled: bool = false

## Current weapon stats (modified by upgrades)
var current_damage: float = 1.0
var current_cooldown: float = 1.0
var upgrade_level: int = 0

## Internal state
var _cooldown_timer: float = 0.0
var _is_active: bool = false
var _owner_node: Node2D = null

## Called when weapon is added to the weapon manager
func initialize(owner: Node2D) -> void:
	_owner_node = owner
	current_damage = base_damage
	current_cooldown = base_cooldown
	_ready_weapon()

## Override this in child classes for weapon-specific setup
func _ready_weapon() -> void:
	pass

## Called every frame by WeaponManager
func update_weapon(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta

	if _is_active and can_fire():
		_execute_fire()
		_cooldown_timer = current_cooldown
		weapon_fired.emit()

## Activate the weapon (e.g., button pressed)
func activate() -> void:
	_is_active = true
	_on_activated()

## Deactivate the weapon (e.g., button released)
func deactivate() -> void:
	_is_active = false
	_on_deactivated()

## Check if weapon can fire right now
func can_fire() -> bool:
	if not enabled:
		return false
	if _cooldown_timer > 0:
		return false
	return _can_fire_custom()

## Override this for custom firing conditions
func _can_fire_custom() -> bool:
	return true

## Override this to implement weapon firing logic
func _execute_fire() -> void:
	push_warning("WeaponBase._execute_fire() not implemented in " + weapon_name)

## Override for custom activation behavior
func _on_activated() -> void:
	pass

## Override for custom deactivation behavior
func _on_deactivated() -> void:
	pass

## Apply upgrade stats to this weapon
func apply_upgrade(level: int, stats: Dictionary) -> void:
	upgrade_level = level

	if stats.has("damage"):
		current_damage = stats.damage
	if stats.has("cooldown"):
		current_cooldown = stats.cooldown
	if stats.has("enabled"):
		enabled = stats.enabled

	_apply_custom_upgrade(stats)
	stats_updated.emit()

## Override this for weapon-specific upgrade handling
func _apply_custom_upgrade(stats: Dictionary) -> void:
	pass

## Get weapon info for UI
func get_weapon_info() -> Dictionary:
	return {
		"name": weapon_name,
		"damage": current_damage,
		"cooldown": current_cooldown,
		"level": upgrade_level,
		"enabled": enabled
	}

## Helper to get the player node
func get_owner() -> Node2D:
	return _owner_node
