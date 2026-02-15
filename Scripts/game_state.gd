extends Node

# Mineral type enum for type-safe mineral handling
enum MineralType {
	IRON,
	NICKEL,
	SILICA,
	PLATINUM
}

# Helper dictionaries for enum/string conversion
const MINERAL_NAMES = {
	MineralType.IRON: "iron",
	MineralType.NICKEL: "nickel",
	MineralType.SILICA: "silica",
	MineralType.PLATINUM: "platinum"
}

const STRING_TO_MINERAL = {
	"iron": MineralType.IRON,
	"nickel": MineralType.NICKEL,
	"silica": MineralType.SILICA,
	"platinum": MineralType.PLATINUM
}

# Global, super-lightweight state. Autoload this as "GameState".

signal credits_changed(new_credits: int)
signal inventory_changed()
signal new_pickup
signal shield_changed(current: float, maximum: float)
signal prices_changed()
signal upgrades_changed()  # Emitted when any upgrade is purchased/modified
signal cargo_full()  # Emitted when cargo hold is at capacity
signal drones_changed(new_count: int)
signal voyage_started()
signal voyage_completed(results: Dictionary)
signal voyage_progress_updated(progress: float)

var credits: int = 0

# Drone system
var drone_count: int = 0
const DRONE_COST: int = 75
var minerals = {
	MineralType.IRON: 0,
	MineralType.NICKEL: 0,
	MineralType.SILICA: 0,
	MineralType.PLATINUM: 0,
}

# Market price system (updated by Market singleton)
var market_prices = {
	MineralType.IRON: 1,
	MineralType.NICKEL: 2,
	MineralType.SILICA: 3,
	MineralType.PLATINUM: 5
}

# Upgrade hooks (read by Player/Spawner/etc.)
var fire_rate: float = 4.0 # shots per second (pairs)
var move_follow_strength: float = 12.0 # higher -> snappier cursor follow
var projectile_speed: float = 800.0

# Cargo hold system
var cargo_capacity: int = 40  # max total minerals player can carry (upgradeable)

#Shield/Armor upgrade system
var max_shield: float = 100.0 # maximum shield capacity (upgradeable)
var current_shield: float = 100.0 # current shield value
var shield_regen_rate: float = 10.0 # shield points per second (upgradeable)
var shield_regen_delay: float = 3.0 # seconds before shield starts regenerating after damage

# Centralized upgrade registry - all upgrades are tracked here
var upgrades = {
	"weapons": {
		"Primary Cannon": {
			"unlocked": true,  # Primary weapon is always unlocked
			"level": 0,
			"damage_values": [1.0, 2.0, 3.0, 5.0],
			"cooldown_values": [0.5, 0.4, 0.3, 0.2]
		},
		"Laser Beam": {
			"unlocked": false,
			"level": 0,
			"max_damage_values": [50.0, 75.0, 100.0, 150.0]
		},
		"Rocket Launcher": {
			"unlocked": false,
			"level": 0,
			"damage_values": [1.0, 2.0, 3.0, 5.0],
			"cooldown_values": [2.0, 1.5, 1.0, 0.75]
		},
		"Mine Layer": {
			"unlocked": false,
			"level": 0,
			"damage_values": [1.0, 2.0, 3.0, 5.0],
			"cooldown_values": [3.0, 2.5, 2.0, 1.5]  # Auto-placement interval (seconds)
		},
		"Railgun": {
			"unlocked": false,
			"level": 0,
			"damage_values": [3.0, 4.0, 5.0, 7.0],
			"cooldown_values": [2.0, 1.75, 1.5, 1.25],
			"pierce_falloff_values": [0.2, 0.15, 0.1, 0.05]  # Less falloff = more damage retention
		}
	},
	"shield": {
		"max_capacity": {
			"level": 0,
			"values": [100.0, 150.0, 200.0, 300.0, 500.0]
		},
		"regen_rate": {
			"level": 0,
			"values": [10.0, 15.0, 20.0, 30.0, 50.0]
		},
		"regen_delay": {
			"level": 0,
			"values": [3.0, 2.5, 2.0, 1.5, 1.0]
		}
	},
	"radar": {
		"zoom_level": {
			"level": 0,
			"values": [1.0, 1.2, 1.5, 2.0, 2.5]
		}
	},
	"cargo": {
		"capacity": {
			"level": 0,
			"values": [40, 60, 80, 120, 170]
		}
	},
	"spawner": {
		"difficulty": {
			"level": 1,  # Start at normal difficulty (level 1)
			"max_level": 4
		}
	}
}

@export var current_mat: MineralType = MineralType.IRON


func _ready() -> void:
	# Connect to Market singleton for price updates
	if Market:
		Market.prices_changed.connect(_on_market_prices_changed)
		# Sync initial prices
		market_prices = Market.market_prices.duplicate()


func _on_market_prices_changed(new_prices: Dictionary) -> void:
	market_prices = new_prices.duplicate()
	emit_signal("prices_changed")


func get_mat():
	return current_mat

func add_mat(kind: MineralType):
	current_mat = kind
	return current_mat

func add_credits(amount: int) -> void:
	credits = max(0, credits + amount)
	emit_signal("credits_changed", credits)

func get_total_minerals() -> int:
	var total := 0
	for count in minerals.values():
		total += count
	return total

func add_mineral(kind: MineralType, amount: int = 1) -> void:
	if not minerals.has(kind):
		minerals[kind] = 0
	var space_left := cargo_capacity - get_total_minerals()
	if space_left <= 0:
		emit_signal("cargo_full")
		return
	var to_add := mini(amount, space_left)
	minerals[kind] += to_add
	emit_signal("new_pickup")
	emit_signal("inventory_changed")
	if get_total_minerals() >= cargo_capacity:
		emit_signal("cargo_full")

func sell_all() -> void:
	var total := 0
	for k in minerals.keys():
		var count: int = minerals[k]
		if count > 0:
			var price := _price_for(k)
			total += price * count

			# Track nickel sales for market pressure
			if k == MineralType.NICKEL and Market:
				Market.record_nickel_sale(count)

			minerals[k] = 0
	if total > 0:
		add_credits(total)
		emit_signal("inventory_changed")

func _price_for(kind: MineralType) -> int:
	if market_prices.has(kind):
		return market_prices[kind]
	return 1


## Get price from Market singleton (convenience wrapper)
func get_market_price(mineral: MineralType) -> int:
	if Market:
		return Market.get_price(mineral)
	return _price_for(mineral)


# === UPGRADE SYSTEM FUNCTIONS ===

## Unlock a weapon upgrade
func unlock_weapon(weapon_name: String) -> bool:
	if not upgrades.weapons.has(weapon_name):
		push_error("Unknown weapon: " + weapon_name)
		return false

	if upgrades.weapons[weapon_name].unlocked:
		print("Weapon already unlocked: " + weapon_name)
		return false

	upgrades.weapons[weapon_name].unlocked = true
	emit_signal("upgrades_changed")
	print("Weapon unlocked: " + weapon_name)
	return true

## Upgrade a weapon to the next level
func upgrade_weapon(weapon_name: String) -> bool:
	if not upgrades.weapons.has(weapon_name):
		push_error("Unknown weapon: " + weapon_name)
		return false

	var weapon_data = upgrades.weapons[weapon_name]
	if not weapon_data.unlocked:
		print("Cannot upgrade locked weapon: " + weapon_name)
		return false

	weapon_data.level += 1
	emit_signal("upgrades_changed")
	print("Weapon upgraded: " + weapon_name + " to level " + str(weapon_data.level))
	return true

## Upgrade a non-weapon system (shield, radar, etc.)
func upgrade_system(system_name: String, upgrade_name: String) -> bool:
	if not upgrades.has(system_name):
		push_error("Unknown system: " + system_name)
		return false

	if not upgrades[system_name].has(upgrade_name):
		push_error("Unknown upgrade: " + upgrade_name + " in system " + system_name)
		return false

	var upgrade_data = upgrades[system_name][upgrade_name]
	if upgrade_data.level >= upgrade_data.values.size() - 1:
		print("Upgrade already at max level: " + system_name + "." + upgrade_name)
		return false

	upgrade_data.level += 1
	emit_signal("upgrades_changed")
	print("System upgraded: " + system_name + "." + upgrade_name + " to level " + str(upgrade_data.level))

	# Update legacy variables for backward compatibility
	_sync_legacy_variables()

	return true

## Sync legacy variables with upgrade registry (for backward compatibility)
func _sync_legacy_variables() -> void:
	# Sync shield variables
	if upgrades.shield.max_capacity.level < upgrades.shield.max_capacity.values.size():
		max_shield = upgrades.shield.max_capacity.values[upgrades.shield.max_capacity.level]

	if upgrades.shield.regen_rate.level < upgrades.shield.regen_rate.values.size():
		shield_regen_rate = upgrades.shield.regen_rate.values[upgrades.shield.regen_rate.level]

	if upgrades.shield.regen_delay.level < upgrades.shield.regen_delay.values.size():
		shield_regen_delay = upgrades.shield.regen_delay.values[upgrades.shield.regen_delay.level]

	# Sync cargo capacity
	if upgrades.has("cargo") and upgrades.cargo.has("capacity"):
		var cargo_data = upgrades.cargo.capacity
		if cargo_data.level < cargo_data.values.size():
			cargo_capacity = cargo_data.values[cargo_data.level]

## Get current value of a system upgrade
func get_upgrade_value(system_name: String, upgrade_name: String) -> Variant:
	if not upgrades.has(system_name):
		return null
	if not upgrades[system_name].has(upgrade_name):
		return null

	var upgrade_data = upgrades[system_name][upgrade_name]
	if upgrade_data.level < upgrade_data.values.size():
		return upgrade_data.values[upgrade_data.level]
	return null

## Check if a weapon is unlocked
func is_weapon_unlocked(weapon_name: String) -> bool:
	if not upgrades.weapons.has(weapon_name):
		return false
	return upgrades.weapons[weapon_name].unlocked

## Set spawner difficulty level
func set_spawner_difficulty(level: int) -> void:
	if not upgrades.has("spawner"):
		return

	var max_level = upgrades.spawner.difficulty.get("max_level", 4)
	upgrades.spawner.difficulty.level = clamp(level, 0, max_level)
	emit_signal("upgrades_changed")
	print("Spawner difficulty set to level ", upgrades.spawner.difficulty.level)

## Increase spawner difficulty (for progression)
func increase_spawner_difficulty() -> bool:
	if not upgrades.has("spawner"):
		return false

	var current = upgrades.spawner.difficulty.level
	var max_level = upgrades.spawner.difficulty.get("max_level", 4)

	if current >= max_level:
		print("Spawner already at max difficulty")
		return false

	upgrades.spawner.difficulty.level += 1
	emit_signal("upgrades_changed")
	print("Spawner difficulty increased to level ", upgrades.spawner.difficulty.level)
	return true

## Get current spawner difficulty level
func get_spawner_difficulty() -> int:
	if upgrades.has("spawner") and upgrades.spawner.has("difficulty"):
		return upgrades.spawner.difficulty.level
	return 0

# === DRONE SYSTEM ===

func buy_drone() -> bool:
	if credits < DRONE_COST:
		return false
	add_credits(-DRONE_COST)
	drone_count += 1
	emit_signal("drones_changed", drone_count)
	return true

func remove_drones(amount: int) -> void:
	drone_count = max(0, drone_count - amount)
	emit_signal("drones_changed", drone_count)
