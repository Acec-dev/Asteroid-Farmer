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
const MARKET_UPDATE_INTERVAL := 3.0
var _market_cycle: float = 0.0  # For sine wave calculation

# Nickel sales tracking for supply/demand
var _nickel_recent_sales: float = 0.0  # Tracks recent nickel sales
const NICKEL_SALES_DECAY_RATE := 0.15  # How fast sales pressure decays per tick

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

			# Track nickel sales for market pressure
			if k == "nickel":
				_nickel_recent_sales += count

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
	# Iron: Random walk with bounds (1-7 credits)
	var iron_change = randi_range(-1, 1)  # -1, 0, or +1 credit change
	var new_iron_price = market_prices["iron"] + iron_change
	market_prices["iron"] = clampi(new_iron_price, 1, 7)

	# Nickel: Supply and demand based on recent sales (1-7 credits)
	# Decay recent sales pressure over time
	_nickel_recent_sales = max(0.0, _nickel_recent_sales - NICKEL_SALES_DECAY_RATE)

	# Price decreases with recent sales (each unit sold reduces price)
	var sales_pressure = 1.0 - (_nickel_recent_sales * 0.05)  # 5% reduction per unit sold
	sales_pressure = clamp(sales_pressure, 0.14, 1.71)  # Range to produce 1-7 when multiplied by 4
	var base_price = 4  # Middle of 1-7 range
	market_prices["nickel"] = clampi(int(base_price * sales_pressure), 1, 7)

	# Silica: Sine wave pattern (1-7 credits)
	_market_cycle += 1.0
	var wave = sin(_market_cycle * 0.5) * 3.0  # Amplitude of 3
	var center_price = 4  # Center of 1-7 range
	market_prices["silica"] = clampi(int(center_price + wave), 1, 7)

	emit_signal("prices_changed")

# Debug function to simulate and display price changes over N ticks
func simulate_market_ticks(num_ticks: int, nickel_sale_at_tick: int = -1, nickel_sale_amount: int = 0) -> void:
	print("\n=== Market Price Simulation (%d ticks) ===" % num_ticks)
	print("Tick | Iron | Nickel | Silica | Nickel Sales Pressure")
	print("-----|------|--------|--------|---------------------")

	# Reset to initial state
	market_prices = {"iron": 1, "nickel": 4, "silica": 4}
	_market_cycle = 0.0
	_nickel_recent_sales = 0.0

	for tick in range(num_ticks):
		# Simulate a nickel sale at specific tick if requested
		if tick == nickel_sale_at_tick and nickel_sale_amount > 0:
			_nickel_recent_sales += nickel_sale_amount
			print(">>> SELLING %d NICKEL AT TICK %d <<<" % [nickel_sale_amount, tick])

		_update_market_prices()
		print("%4d | %4d | %6d | %6d | %.2f" % [
			tick + 1,
			market_prices["iron"],
			market_prices["nickel"],
			market_prices["silica"],
			_nickel_recent_sales
		])
