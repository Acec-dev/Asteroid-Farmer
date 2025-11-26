## Test script for weapon and upgrade system
## Attach this to a node in your scene to test upgrades
extends Node

## Set this to true to enable all weapons and upgrades on start
@export var enable_test_mode: bool = false

## Set this to true to print upgrade info to console
@export var print_debug_info: bool = true

func _ready() -> void:
	if enable_test_mode:
		_enable_all_upgrades()

	if print_debug_info:
		_print_upgrade_status()

## Enable all weapons and max out all upgrades
func _enable_all_upgrades() -> void:
	print("\n=== ENABLING ALL UPGRADES FOR TESTING ===\n")

	# Unlock all weapons
	GameState.unlock_weapon("Laser Beam")
	GameState.unlock_weapon("Rocket Launcher")
	GameState.unlock_weapon("Mine Layer")

	# Upgrade weapons to max
	for i in range(3):
		GameState.upgrade_weapon("Primary Cannon")
		GameState.upgrade_weapon("Laser Beam")
		GameState.upgrade_weapon("Rocket Launcher")
		GameState.upgrade_weapon("Mine Layer")

	# Upgrade shield to max
	for i in range(4):
		GameState.upgrade_system("shield", "max_capacity")
		GameState.upgrade_system("shield", "regen_rate")
		GameState.upgrade_system("shield", "regen_delay")

	# Upgrade radar to max
	for i in range(4):
		GameState.upgrade_system("radar", "zoom_level")

	print("All upgrades enabled!\n")

## Print current status of all upgrades
func _print_upgrade_status() -> void:
	print("\n=== CURRENT UPGRADE STATUS ===\n")

	print("WEAPONS:")
	for weapon_name in GameState.upgrades.weapons.keys():
		var weapon = GameState.upgrades.weapons[weapon_name]
		var status = "LOCKED" if not weapon.unlocked else "UNLOCKED (Level " + str(weapon.level) + ")"
		print("  " + weapon_name + ": " + status)

	print("\nSHIELD:")
	print("  Max Capacity: Level ", GameState.upgrades.shield.max_capacity.level, " = ", GameState.get_upgrade_value("shield", "max_capacity"))
	print("  Regen Rate: Level ", GameState.upgrades.shield.regen_rate.level, " = ", GameState.get_upgrade_value("shield", "regen_rate"))
	print("  Regen Delay: Level ", GameState.upgrades.shield.regen_delay.level, " = ", GameState.get_upgrade_value("shield", "regen_delay"))

	print("\nRADAR:")
	print("  Zoom Level: Level ", GameState.upgrades.radar.zoom_level.level, " = ", GameState.get_upgrade_value("radar", "zoom_level"))

	print("\n================================\n")

## Test individual weapon unlock
func test_unlock_weapon(weapon_name: String) -> void:
	print("Testing unlock: ", weapon_name)
	if GameState.unlock_weapon(weapon_name):
		print("  SUCCESS: ", weapon_name, " unlocked!")
	else:
		print("  FAILED: Could not unlock ", weapon_name)

## Test individual weapon upgrade
func test_upgrade_weapon(weapon_name: String) -> void:
	print("Testing upgrade: ", weapon_name)
	if GameState.upgrade_weapon(weapon_name):
		var level = GameState.upgrades.weapons[weapon_name].level
		print("  SUCCESS: ", weapon_name, " upgraded to level ", level)
	else:
		print("  FAILED: Could not upgrade ", weapon_name)

## Test system upgrade
func test_upgrade_system(system: String, upgrade: String) -> void:
	print("Testing upgrade: ", system, ".", upgrade)
	if GameState.upgrade_system(system, upgrade):
		var level = GameState.upgrades[system][upgrade].level
		var value = GameState.get_upgrade_value(system, upgrade)
		print("  SUCCESS: ", system, ".", upgrade, " upgraded to level ", level, " (value: ", value, ")")
	else:
		print("  FAILED: Could not upgrade ", system, ".", upgrade)

## Call this from console or button to test upgrades interactively
func _input(event: InputEvent) -> void:
	if not enable_test_mode:
		return

	# Press number keys to test different upgrades
	if event.is_action_pressed("ui_text_1"):  # 1 key
		test_unlock_weapon("Laser Beam")
	elif event.is_action_pressed("ui_text_2"):  # 2 key
		test_unlock_weapon("Rocket Launcher")
	elif event.is_action_pressed("ui_text_3"):  # 3 key
		test_unlock_weapon("Mine Layer")
	elif event.is_action_pressed("ui_text_4"):  # 4 key
		test_upgrade_system("shield", "max_capacity")
	elif event.is_action_pressed("ui_text_5"):  # 5 key
		test_upgrade_system("radar", "zoom_level")
	elif event.is_action_pressed("ui_page_up"):  # Page Up
		_print_upgrade_status()
