extends Node


# Global, super-lightweight state. Autoload this as "GameState".

signal credits_changed(new_credits: int)
signal inventory_changed()
signal new_pickup
signal shield_changed(current: float, maximum: float)
signal prices_changed()

var credits: int = 0
var minerals := {
"iron": 0,
"nickel": 0,
"silica": 0,
}

# Market price system
const BASE_PRICES := {
	"iron": 1,
	"nickel": 2,
	"silica": 3
}

var market_prices := {
	"iron": 1,
	"nickel": 2,
	"silica": 3
}

# Market update timing
var _market_timer: float = 0.0
const MARKET_UPDATE_INTERVAL := 10.0
var _market_cycle: float = 0.0  # For sine wave calculation

# Upgrade hooks (read by Player/Spawner/etc.)
var fire_rate: float = 4.0 # shots per second (pairs)
var move_follow_strength: float = 12.0 # higher -> snappier cursor follow
var projectile_speed: float = 800.0

#Shield/Armor upgrade system
var max_shield: float = 100.0 # maximum shield capacity (upgradeable)
var current_shield: float = 100.0 # current shield value
var shield_regen_rate: float = 10.0 # shield points per second (upgradeable)
var shield_regen_delay: float = 3.0 # seconds before shield starts regenerating after damage



@export var current_mat: String = "iron"

func get_mat():
	return current_mat

func add_mat(kind):
	current_mat = kind
	return current_mat

func add_credits(amount: int) -> void:
	credits = max(0, credits + amount)
	emit_signal("credits_changed", credits)

func add_mineral(kind: StringName, amount: int = 1) -> void:
	if not minerals.has(kind):
		minerals[kind] = 0
	minerals[kind] += amount
	emit_signal("new_pickup")
	emit_signal("inventory_changed")

func sell_all() -> void:
	var total := 0
	for k in minerals.keys():
		var count: int = minerals[k]
		if count > 0:
			var price := _price_for(k)
			total += price * count
			minerals[k] = 0
	if total > 0:
		add_credits(total)
		emit_signal("inventory_changed")

func _price_for(kind: StringName) -> int:
	if market_prices.has(kind):
		return market_prices[kind]
	return 1

# Market price fluctuation system
func _process(delta: float) -> void:
	_market_timer += delta
	if _market_timer >= MARKET_UPDATE_INTERVAL:
		_market_timer = 0.0
		_update_market_prices()

func _update_market_prices() -> void:
	# Iron: Random walk with bounds (50% - 200% of base price)
	var iron_change = randi_range(-1, 1)  # -1, 0, or +1 credit change
	var new_iron_price = market_prices["iron"] + iron_change
	var iron_min = int(BASE_PRICES["iron"] * 0.5)
	var iron_max = int(BASE_PRICES["iron"] * 2.0)
	market_prices["iron"] = clampi(new_iron_price, max(1, iron_min), iron_max)

	# Nickel: Supply and demand based
	var nickel_inventory = minerals["nickel"]
	# More inventory = lower prices (each unit reduces price by 2%)
	var supply_factor = 1.0 - (nickel_inventory * 0.02)
	supply_factor = clamp(supply_factor, 0.5, 2.0)  # 50% - 200% range
	market_prices["nickel"] = max(1, int(BASE_PRICES["nickel"] * supply_factor))

	# Silica: Sine wave pattern (±30% fluctuation)
	_market_cycle += 1.0
	var wave = sin(_market_cycle * 0.5) * 0.3  # ±30%
	market_prices["silica"] = max(1, int(BASE_PRICES["silica"] * (1.0 + wave)))

	emit_signal("prices_changed")
