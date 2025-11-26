## Shield component that handles shield regeneration, damage, and capacity
## Automatically syncs with GameState upgrade values
class_name ShieldComponent
extends Node

## Emitted when shield value changes
signal shield_changed(current: float, maximum: float)

## Shield stats (synced from GameState)
var max_shield: float = 100.0
var current_shield: float = 100.0
var shield_regen_rate: float = 10.0  # points per second
var shield_regen_delay: float = 3.0  # seconds before regen starts

## Internal state
var _regen_timer: float = 0.0
var _can_regenerate: bool = true
var _owner_node: Node2D = null

func _ready() -> void:
	# Owner should be set before ready
	if not _owner_node:
		_owner_node = get_parent() as Node2D

	# Sync with GameState
	sync_with_game_state()

	# Connect to GameState for upgrade updates
	if GameState.has_signal("upgrades_changed"):
		GameState.upgrades_changed.connect(_on_upgrades_changed)

	# Initialize shield to full
	current_shield = max_shield
	_emit_shield_changed()

func _process(delta: float) -> void:
	_handle_shield_regeneration(delta)

## Regenerate shield over time after the regen delay
func _handle_shield_regeneration(delta: float) -> void:
	if current_shield < max_shield:
		if _can_regenerate:
			_regen_timer += delta
			if _regen_timer >= shield_regen_delay:
				# Start regenerating
				current_shield = min(current_shield + shield_regen_rate * delta, max_shield)
				_emit_shield_changed()

## Apply damage to the shield
func take_damage(amount: float) -> void:
	current_shield = max(0.0, current_shield - amount)
	_regen_timer = 0.0  # Reset regen timer
	_can_regenerate = true
	_emit_shield_changed()

	# Visual feedback - flash the owner node
	if _owner_node:
		_flash_damage()

	if current_shield <= 0:
		_on_shield_depleted()

## Visual damage feedback
func _flash_damage() -> void:
	if not _owner_node:
		return

	_owner_node.modulate = Color(1.5, 0.5, 0.5)  # Red flash
	await _owner_node.get_tree().create_timer(0.1).timeout
	_owner_node.modulate = Color.WHITE

## Called when shield reaches zero
func _on_shield_depleted() -> void:
	print("Shield depleted! Game Over!")
	_owner_node.get_tree().change_scene_to_file("res://Scenes/GameOver.tscn")

## Sync shield stats with GameState
func sync_with_game_state() -> void:
	if not GameState:
		return

	# Read shield upgrades from GameState legacy variables
	if "max_shield" in GameState:
		max_shield = GameState.max_shield
	if "shield_regen_rate" in GameState:
		shield_regen_rate = GameState.shield_regen_rate
	if "shield_regen_delay" in GameState:
		shield_regen_delay = GameState.shield_regen_delay

	# If we have an upgrade registry, use that instead
	if "upgrades" in GameState and GameState.upgrades.has("shield"):
		var shield_upgrades = GameState.upgrades.shield

		if shield_upgrades.has("max_capacity"):
			var capacity_data = shield_upgrades.max_capacity
			if capacity_data.has("level") and capacity_data.has("values"):
				var level = capacity_data.level
				if level < capacity_data.values.size():
					max_shield = capacity_data.values[level]

		if shield_upgrades.has("regen_rate"):
			var regen_data = shield_upgrades.regen_rate
			if regen_data.has("level") and regen_data.has("values"):
				var level = regen_data.level
				if level < regen_data.values.size():
					shield_regen_rate = regen_data.values[level]

	print("ShieldComponent: Synced - Max: ", max_shield, " Regen: ", shield_regen_rate, "/s")

## Called when GameState upgrades change
func _on_upgrades_changed() -> void:
	var old_max = max_shield
	sync_with_game_state()

	# If max shield increased, heal proportionally
	if max_shield > old_max:
		var heal_percent = current_shield / old_max
		current_shield = max_shield * heal_percent
		_emit_shield_changed()

## Emit shield changed signal to both this component and GameState
func _emit_shield_changed() -> void:
	shield_changed.emit(current_shield, max_shield)

	# Also update GameState for UI
	if GameState.has_signal("shield_changed"):
		GameState.shield_changed.emit(current_shield, max_shield)

## Set owner node (player)
func set_owner_node(owner: Node2D) -> void:
	_owner_node = owner

## Restore shield to full (for debugging/testing)
func restore_full() -> void:
	current_shield = max_shield
	_emit_shield_changed()
