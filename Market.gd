extends Node
## Market system that handles price fluctuations and history tracking
## Emits signals when prices change, allowing UI and GameState to respond

signal prices_changed(new_prices: Dictionary)

## How often prices update (in seconds)
@export var update_interval: float = 3.0

## Base prices for each mineral
const BASE_PRICES := {
	"iron": 1,
	"nickel": 2,
	"silica": 3
}

## Current market prices
var market_prices := {
	"iron": 1,
	"nickel": 2,
	"silica": 3
}

## Price history - tracks last 10 prices for each mineral
var price_history := {
	"iron": [],
	"nickel": [],
	"silica": []
}

## Maximum number of historical prices to track
const MAX_HISTORY_LENGTH := 10

# Nickel pricing state (supply/demand model)
const NICKEL_SALES_DECAY_RATE := 0.15
var _nickel_recent_sales: float = 0.0

# Silica pricing state (sine wave model)
var _market_cycle: int = 0

# Timer node for price updates
var _timer: Timer


func _ready() -> void:
	# Initialize price history with starting prices
	for mineral in ["iron", "nickel", "silica"]:
		price_history[mineral].append(market_prices[mineral])

	# Create and configure timer
	_timer = Timer.new()
	_timer.wait_time = update_interval
	_timer.timeout.connect(_on_market_timer_timeout)
	_timer.autostart = true
	add_child(_timer)

	print("Market system initialized - prices update every %.1f seconds" % update_interval)


func _on_market_timer_timeout() -> void:
	_update_market_prices()


func _update_market_prices() -> void:
	# Update each mineral price based on its model
	_update_iron_price()
	_update_nickel_price()
	_update_silica_price()

	# Add current prices to history (limited to MAX_HISTORY_LENGTH)
	for mineral in ["iron", "nickel", "silica"]:
		price_history[mineral].append(market_prices[mineral])
		if price_history[mineral].size() > MAX_HISTORY_LENGTH:
			price_history[mineral].pop_front()

	# Notify listeners
	prices_changed.emit(market_prices)

	# Debug output
	print("Market Update - Iron: $%d  Nickel: $%d  Silica: $%d" % [
		market_prices["iron"],
		market_prices["nickel"],
		market_prices["silica"]
	])


## Iron uses a random walk model
func _update_iron_price() -> void:
	var change := randi() % 3 - 1  # -1, 0, or +1
	market_prices["iron"] = clampi(market_prices["iron"] + change, 1, 7)


## Nickel uses supply/demand based on player sales
func _update_nickel_price() -> void:
	# Sales pressure decays over time
	_nickel_recent_sales = max(0.0, _nickel_recent_sales - NICKEL_SALES_DECAY_RATE)

	# Calculate price based on sales pressure
	var base_price := 4
	var sales_impact := int(_nickel_recent_sales * 0.05 * base_price)
	market_prices["nickel"] = clampi(base_price - sales_impact, 1, 7)


## Silica uses a predictable sine wave pattern
func _update_silica_price() -> void:
	_market_cycle += 1
	var wave := sin(_market_cycle * 0.5) * 3
	market_prices["silica"] = clampi(4 + int(wave), 1, 7)


## Called when player sells nickel - affects future prices
func record_nickel_sale(amount: int) -> void:
	_nickel_recent_sales += amount


## Get current price for a mineral
func get_price(mineral: String) -> int:
	return market_prices.get(mineral, 0)


## Get price history for a mineral (returns array of last N prices)
func get_price_history(mineral: String) -> Array:
	return price_history.get(mineral, [])


## Reset market to initial state
func reset_market() -> void:
	market_prices = {
		"iron": 1,
		"nickel": 2,
		"silica": 3
	}
	price_history = {
		"iron": [1],
		"nickel": [2],
		"silica": [3]
	}
	_nickel_recent_sales = 0.0
	_market_cycle = 0
	prices_changed.emit(market_prices)
