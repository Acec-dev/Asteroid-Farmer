extends Node

# Mineral type enum for type-safe mineral handling
enum MineralType {
	IRON,
	NICKEL,
	SILICA,
	PLATINUM
}

# Exotic mineral types (from expeditions)
enum ExoticMineralType {
	COBALT,
	TITANIUM,
	XENOCRYST,
	IRIDIUM
}

# Helper dictionaries for enum/string conversion
const MINERAL_NAMES = {
	MineralType.IRON: "iron",
	MineralType.NICKEL: "nickel",
	MineralType.SILICA: "silica",
	MineralType.PLATINUM: "platinum"
}

const EXOTIC_MINERAL_NAMES = {
	ExoticMineralType.COBALT: "cobalt",
	ExoticMineralType.TITANIUM: "titanium",
	ExoticMineralType.XENOCRYST: "xenocryst",
	ExoticMineralType.IRIDIUM: "iridium"
}

const STRING_TO_MINERAL = {
	"iron": MineralType.IRON,
	"nickel": MineralType.NICKEL,
	"silica": MineralType.SILICA,
	"platinum": MineralType.PLATINUM
}

const STRING_TO_EXOTIC = {
	"cobalt": ExoticMineralType.COBALT,
	"titanium": ExoticMineralType.TITANIUM,
	"xenocryst": ExoticMineralType.XENOCRYST,
	"iridium": ExoticMineralType.IRIDIUM
}

# Global, super-lightweight state. Autoload this as "GameState".

signal credits_changed(new_credits: int)
signal inventory_changed()
signal new_pickup
signal shield_changed(current: float, maximum: float)
signal prices_changed()
signal upgrades_changed()  # Emitted when any upgrade is purchased/modified
signal cargo_full()  # Emitted when cargo hold is at capacity
signal over_encumbered(is_encumbered: bool)  # Emitted when encumbrance state changes
signal drones_changed(new_count: int)
signal voyage_started()
signal voyage_completed(results: Dictionary)
signal voyage_progress_updated(progress: float)
signal expedition_started()
signal expedition_completed(results: Dictionary)
signal expedition_progress_updated(progress: float)
signal exotic_minerals_changed()
signal drone_upgrades_changed()
signal bank_balance_changed(new_balance: int)
signal bank_bond_changed()
signal bank_upgraded()

var credits: int = 0

# === BANK SYSTEM ===
var bank_balance: int = 0
var bank_interest_timer: float = 0.0
var bank_transaction_history: Array[Dictionary] = []
const MAX_TRANSACTION_HISTORY := 20

# Bank upgrades
var bank_upgrades = {
	"vault_capacity": {
		"level": 0,
		"max_level": 3,
		"values": [500, 2000, 5000, 15000],
		"costs": [0, 200, 500, 1500],
	},
	"interest_rate": {
		"level": 0,
		"max_level": 3,
		"values": [0.01, 0.02, 0.03, 0.05],
		"costs": [0, 300, 800, 2000],
	},
	"compound_speed": {
		"level": 0,
		"max_level": 3,
		"values": [30.0, 20.0, 15.0, 10.0],
		"costs": [0, 250, 600, 1800],
	},
}

# Bond system
var bank_bonds: Array[Dictionary] = []  # Active bonds
const BOND_TIERS = {
	"short": {
		"name": "Short Bond",
		"duration": 60.0,
		"rate": 0.08,
		"min_investment": 50,
	},
	"medium": {
		"name": "Medium Bond",
		"duration": 180.0,
		"rate": 0.20,
		"min_investment": 150,
	},
	"long": {
		"name": "Long Bond",
		"duration": 360.0,
		"rate": 0.40,
		"min_investment": 300,
	},
}

# Drone system
var drone_count: int = 0
const DRONE_COST: int = 75
var minerals = {
	MineralType.IRON: 0,
	MineralType.NICKEL: 0,
	MineralType.SILICA: 0,
	MineralType.PLATINUM: 0,
}

# Exotic minerals (earned from expeditions, spent on drone upgrades)
var exotic_minerals = {
	ExoticMineralType.COBALT: 0,
	ExoticMineralType.TITANIUM: 0,
	ExoticMineralType.XENOCRYST: 0,
	ExoticMineralType.IRIDIUM: 0,
}

# Drone upgrades (purchased with exotic minerals)
var drone_upgrades = {
	"drone_armor": {
		"level": 0,
		"max_level": 3,
		"description": "Reduces drone break chance",
		"values": [0.0, 0.25, 0.50, 0.75],  # Break chance reduction multiplier
		"costs": [
			{ExoticMineralType.COBALT: 5},
			{ExoticMineralType.COBALT: 10},
			{ExoticMineralType.COBALT: 20},
		],
	},
	"mineral_scanners": {
		"level": 0,
		"max_level": 3,
		"description": "Bonus minerals per surviving drone",
		"values": [0, 1, 2, 3],  # Bonus minerals per drone
		"costs": [
			{ExoticMineralType.TITANIUM: 5},
			{ExoticMineralType.TITANIUM: 10},
			{ExoticMineralType.TITANIUM: 20},
		],
	},
	"warp_drive": {
		"level": 0,
		"max_level": 3,
		"description": "Faster voyages and expeditions",
		"values": [1.0, 0.85, 0.70, 0.55],  # Duration multiplier
		"costs": [
			{ExoticMineralType.XENOCRYST: 3},
			{ExoticMineralType.XENOCRYST: 8},
			{ExoticMineralType.XENOCRYST: 15},
		],
	},
	"deep_probes": {
		"level": 0,
		"max_level": 3,
		"description": "Better exotic mineral yields",
		"values": [1.0, 1.5, 2.0, 2.5],  # Exotic yield multiplier
		"costs": [
			{ExoticMineralType.IRIDIUM: 2},
			{ExoticMineralType.IRIDIUM: 5},
			{ExoticMineralType.IRIDIUM: 10},
		],
	},
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
const ENCUMBRANCE_MIN_SPEED_MULT: float = 0.25  # Floor: never slower than 25% speed
var _was_over_encumbered: bool = false

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
			"cooldown_values": [5.0, 4.5, 4.0, 3.5],
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

func _process(delta: float) -> void:
	_bank_tick(delta)
	_bond_tick(delta)


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

func is_over_encumbered() -> bool:
	return get_total_minerals() > cargo_capacity

func get_speed_multiplier() -> float:
	var total := get_total_minerals()
	if total <= cargo_capacity:
		return 1.0
	# speed = capacity / total, floored at minimum
	return maxf(float(cargo_capacity) / float(total), ENCUMBRANCE_MIN_SPEED_MULT)

func add_mineral(kind: MineralType, amount: int = 1) -> void:
	if not minerals.has(kind):
		minerals[kind] = 0
	minerals[kind] += amount
	emit_signal("new_pickup")
	emit_signal("inventory_changed")
	var total := get_total_minerals()
	if total >= cargo_capacity:
		emit_signal("cargo_full")
	# Track encumbrance state transitions
	var is_over := total > cargo_capacity
	if is_over != _was_over_encumbered:
		_was_over_encumbered = is_over
		emit_signal("over_encumbered", is_over)

func sell_all() -> void:
	var was_over := is_over_encumbered()
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
		if was_over:
			_was_over_encumbered = false
			emit_signal("over_encumbered", false)

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

# === EXOTIC MINERAL SYSTEM ===

func add_exotic_mineral(kind: ExoticMineralType, amount: int = 1) -> void:
	if not exotic_minerals.has(kind):
		exotic_minerals[kind] = 0
	exotic_minerals[kind] += amount
	emit_signal("exotic_minerals_changed")

func get_total_exotic_minerals() -> int:
	var total := 0
	for count in exotic_minerals.values():
		total += count
	return total

# === DRONE UPGRADE SYSTEM ===

func get_drone_upgrade_level(upgrade_name: String) -> int:
	if drone_upgrades.has(upgrade_name):
		return drone_upgrades[upgrade_name].level
	return 0

func get_drone_upgrade_value(upgrade_name: String) -> Variant:
	if not drone_upgrades.has(upgrade_name):
		return null
	var data = drone_upgrades[upgrade_name]
	if data.level < data.values.size():
		return data.values[data.level]
	return data.values[-1]

func get_break_chance_reduction() -> float:
	return get_drone_upgrade_value("drone_armor") if get_drone_upgrade_value("drone_armor") != null else 0.0

func get_mineral_bonus() -> int:
	return get_drone_upgrade_value("mineral_scanners") if get_drone_upgrade_value("mineral_scanners") != null else 0

func get_duration_multiplier() -> float:
	return get_drone_upgrade_value("warp_drive") if get_drone_upgrade_value("warp_drive") != null else 1.0

func get_exotic_yield_multiplier() -> float:
	return get_drone_upgrade_value("deep_probes") if get_drone_upgrade_value("deep_probes") != null else 1.0

func can_afford_drone_upgrade(upgrade_name: String) -> bool:
	if not drone_upgrades.has(upgrade_name):
		return false
	var data = drone_upgrades[upgrade_name]
	if data.level >= data.max_level:
		return false
	var cost = data.costs[data.level]
	for mineral_type in cost:
		if exotic_minerals.get(mineral_type, 0) < cost[mineral_type]:
			return false
	return true

func buy_drone_upgrade(upgrade_name: String) -> bool:
	if not can_afford_drone_upgrade(upgrade_name):
		return false
	var data = drone_upgrades[upgrade_name]
	var cost = data.costs[data.level]
	# Deduct exotic minerals
	for mineral_type in cost:
		exotic_minerals[mineral_type] -= cost[mineral_type]
	data.level += 1
	emit_signal("drone_upgrades_changed")
	emit_signal("exotic_minerals_changed")
	print("Drone upgrade purchased: %s to level %d" % [upgrade_name, data.level])
	return true

# === BANK SYSTEM ===

func get_bank_capacity() -> int:
	var data = bank_upgrades["vault_capacity"]
	return data.values[data.level]

func get_bank_interest_rate() -> float:
	var data = bank_upgrades["interest_rate"]
	return data.values[data.level]

func get_bank_compound_interval() -> float:
	var data = bank_upgrades["compound_speed"]
	return data.values[data.level]

func bank_deposit(amount: int) -> bool:
	var capacity = get_bank_capacity()
	var space = capacity - bank_balance
	if space <= 0 or amount <= 0 or credits < amount:
		return false
	var actual = mini(amount, mini(credits, space))
	add_credits(-actual)
	bank_balance += actual
	_add_transaction("deposit", actual)
	emit_signal("bank_balance_changed", bank_balance)
	return true

func bank_withdraw(amount: int) -> bool:
	if amount <= 0 or bank_balance <= 0:
		return false
	var actual = mini(amount, bank_balance)
	bank_balance -= actual
	add_credits(actual)
	_add_transaction("withdraw", actual)
	emit_signal("bank_balance_changed", bank_balance)
	return true

func _bank_tick(delta: float) -> void:
	if bank_balance <= 0:
		return
	bank_interest_timer += delta
	var interval = get_bank_compound_interval()
	if bank_interest_timer >= interval:
		bank_interest_timer -= interval
		var rate = get_bank_interest_rate()
		var interest = int(floor(bank_balance * rate))
		if interest > 0:
			var capacity = get_bank_capacity()
			interest = mini(interest, capacity - bank_balance)
			if interest > 0:
				bank_balance += interest
				_add_transaction("interest", interest)
				emit_signal("bank_balance_changed", bank_balance)

func _add_transaction(type: String, amount: int) -> void:
	bank_transaction_history.push_front({"type": type, "amount": amount, "balance": bank_balance})
	if bank_transaction_history.size() > MAX_TRANSACTION_HISTORY:
		bank_transaction_history.pop_back()

func can_afford_bank_upgrade(upgrade_name: String) -> bool:
	if not bank_upgrades.has(upgrade_name):
		return false
	var data = bank_upgrades[upgrade_name]
	if data.level >= data.max_level:
		return false
	var cost = data.costs[data.level + 1]
	return credits >= cost

func buy_bank_upgrade(upgrade_name: String) -> bool:
	if not can_afford_bank_upgrade(upgrade_name):
		return false
	var data = bank_upgrades[upgrade_name]
	var cost = data.costs[data.level + 1]
	add_credits(-cost)
	data.level += 1
	_add_transaction("upgrade", cost)
	emit_signal("bank_upgraded")
	return true

# === BOND SYSTEM ===

func buy_bond(tier_key: String) -> bool:
	if not BOND_TIERS.has(tier_key):
		return false
	var tier = BOND_TIERS[tier_key]
	if credits < tier.min_investment:
		return false
	var investment = tier.min_investment
	add_credits(-investment)
	var bond = {
		"tier": tier_key,
		"principal": investment,
		"payout": int(ceil(investment * (1.0 + tier.rate))),
		"duration": tier.duration,
		"elapsed": 0.0,
	}
	bank_bonds.append(bond)
	_add_transaction("bond_buy", investment)
	emit_signal("bank_bond_changed")
	return true

func _bond_tick(delta: float) -> void:
	var matured_indices := []
	for i in range(bank_bonds.size()):
		bank_bonds[i].elapsed += delta
		if bank_bonds[i].elapsed >= bank_bonds[i].duration:
			matured_indices.append(i)

	if matured_indices.size() > 0:
		# Process in reverse so indices stay valid
		matured_indices.reverse()
		for i in matured_indices:
			var bond = bank_bonds[i]
			add_credits(bond.payout)
			_add_transaction("bond_mature", bond.payout)
			bank_bonds.remove_at(i)
		emit_signal("bank_bond_changed")
