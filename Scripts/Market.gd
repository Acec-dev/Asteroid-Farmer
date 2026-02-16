extends Node
## Market system that handles price fluctuations and history tracking
## Emits signals when prices change, allowing UI and GameState to respond

signal prices_changed(new_prices: Dictionary)

## How often prices update (in seconds)
@export var update_interval: float = 3.0

## Base prices for each mineral
const BASE_PRICES := {
	GameState.MineralType.IRON: 1,
	GameState.MineralType.NICKEL: 2,
	GameState.MineralType.SILICA: 3,
	GameState.MineralType.PLATINUM: 5
}

## Current market prices
var market_prices := {
	GameState.MineralType.IRON: 1,
	GameState.MineralType.NICKEL: 2,
	GameState.MineralType.SILICA: 3,
	GameState.MineralType.PLATINUM: 5
}

## Price history - tracks last 10 prices for each mineral
var price_history := {
	GameState.MineralType.IRON: [],
	GameState.MineralType.NICKEL: [],
	GameState.MineralType.SILICA: [],
	GameState.MineralType.PLATINUM: []
}

## Maximum number of historical prices to track
const MAX_HISTORY_LENGTH := 10

# === FUEL PRICE SYSTEM ===
# Fuel uses a mean-reverting model with occasional volatility spikes
const FUEL_BASE_PRICE := 50
const FUEL_MIN_PRICE := 15
const FUEL_MAX_PRICE := 95
const FUEL_MEAN_REVERSION := 0.08  # How strongly price pulls back toward base
const FUEL_VOLATILITY := 4.0       # Normal price change magnitude
const FUEL_SPIKE_CHANCE := 0.12    # Chance of a volatility spike per tick
const FUEL_SPIKE_MAGNITUDE := 12.0 # Extra change during a spike

var fuel_price: int = FUEL_BASE_PRICE
var _fuel_drift: float = 0.0  # Accumulated fractional drift
var fuel_price_history: Array = []

# Nickel pricing state (supply/demand model with time appreciation)
const NICKEL_SALES_DECAY_RATE := 0.15
const NICKEL_APPRECIATION_RATE := 0.12  # How fast price rises when not selling
const NICKEL_MAX_APPRECIATION := 3.0    # Max bonus above base price from holding
var _nickel_recent_sales: float = 0.0
var _nickel_appreciation: float = 0.0   # Accumulated price bonus from not selling

# Silica pricing state (sine wave model)
var _market_cycle: int = 0

# Platinum pricing state (boom and bust model)
var _platinum_pressure: float = 0.0  # Builds up over time, resets on bust

# Timer node for price updates
var _timer: Timer


func _ready() -> void:
	# Initialize price history with starting prices
	for mineral in [GameState.MineralType.IRON, GameState.MineralType.NICKEL, GameState.MineralType.SILICA, GameState.MineralType.PLATINUM]:
		price_history[mineral].append(market_prices[mineral])
	fuel_price_history.append(fuel_price)

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
	_update_platinum_price()
	_update_fuel_price()

	# Add current prices to history (limited to MAX_HISTORY_LENGTH)
	for mineral in [GameState.MineralType.IRON, GameState.MineralType.NICKEL, GameState.MineralType.SILICA, GameState.MineralType.PLATINUM]:
		price_history[mineral].append(market_prices[mineral])
		if price_history[mineral].size() > MAX_HISTORY_LENGTH:
			price_history[mineral].pop_front()

	fuel_price_history.append(fuel_price)
	if fuel_price_history.size() > MAX_HISTORY_LENGTH:
		fuel_price_history.pop_front()

	# Notify listeners
	prices_changed.emit(market_prices)

	# --- Debug output ---
	#print("Market Update - Iron: $%d  Nickel: $%d  Silica: $%d" % [
		#market_prices[GameState.MineralType.IRON],
		#market_prices[GameState.MineralType.NICKEL],
		#market_prices[GameState.MineralType.SILICA]
	#])


## Iron uses a random walk model
func _update_iron_price() -> void:
	var change := randi() % 3 - 1  # -1, 0, or +1
	market_prices[GameState.MineralType.IRON] = clampi(market_prices[GameState.MineralType.IRON] + change, 1, 7)


## Nickel uses supply/demand based on player sales, with price appreciation over time
func _update_nickel_price() -> void:
	# Sales pressure decays over time
	_nickel_recent_sales = max(0.0, _nickel_recent_sales - NICKEL_SALES_DECAY_RATE)

	# Price appreciates when player isn't flooding the market
	if _nickel_recent_sales < 1.0:
		_nickel_appreciation = min(_nickel_appreciation + NICKEL_APPRECIATION_RATE, NICKEL_MAX_APPRECIATION)

	# Calculate price based on appreciation and sales pressure
	var base_price := 4
	var appreciation_bonus := int(_nickel_appreciation)
	var sales_impact := int(_nickel_recent_sales * 0.05 * base_price)
	market_prices[GameState.MineralType.NICKEL] = clampi(base_price + appreciation_bonus - sales_impact, 1, 7)


## Silica uses a predictable sine wave pattern
func _update_silica_price() -> void:
	_market_cycle += 1
	var wave := sin(_market_cycle * 0.5) * 3
	market_prices[GameState.MineralType.SILICA] = clampi(4 + int(wave), 1, 7)


## Platinum uses a boom-and-bust model - price slowly climbs, then randomly crashes
func _update_platinum_price() -> void:
	_platinum_pressure += randf_range(0.1, 0.4)
	# Random chance of a bust that increases as pressure builds
	var bust_chance := _platinum_pressure * 0.03
	if randf() < bust_chance:
		# Bust! Price crashes back down
		_platinum_pressure = 0.0
	var bonus := int(_platinum_pressure)
	market_prices[GameState.MineralType.PLATINUM] = clampi(5 + bonus, 2, 10)


## Fuel uses a mean-reverting random walk with occasional volatility spikes
func _update_fuel_price() -> void:
	# Mean reversion: pull price toward base
	var reversion = (FUEL_BASE_PRICE - fuel_price) * FUEL_MEAN_REVERSION

	# Random walk component
	var noise = randf_range(-FUEL_VOLATILITY, FUEL_VOLATILITY)

	# Occasional volatility spike
	if randf() < FUEL_SPIKE_CHANCE:
		noise += randf_range(-FUEL_SPIKE_MAGNITUDE, FUEL_SPIKE_MAGNITUDE)

	_fuel_drift += reversion + noise
	var change = int(_fuel_drift)
	_fuel_drift -= change
	fuel_price = clampi(fuel_price + change, FUEL_MIN_PRICE, FUEL_MAX_PRICE)


## Get current fuel price
func get_fuel_price() -> int:
	return fuel_price


## Get fuel price history
func get_fuel_price_history() -> Array:
	return fuel_price_history


## Called when player sells nickel - affects future prices and resets appreciation
func record_nickel_sale(amount: int) -> void:
	_nickel_recent_sales += amount
	# Selling resets the appreciation buildup
	_nickel_appreciation = 0.0


## Get current price for a mineral
func get_price(mineral: GameState.MineralType) -> int:
	return market_prices.get(mineral, 0)


## Get price history for a mineral (returns array of last N prices)
func get_price_history(mineral: GameState.MineralType) -> Array:
	return price_history.get(mineral, [])


## Reset market to initial state
func reset_market() -> void:
	market_prices = {
		GameState.MineralType.IRON: 1,
		GameState.MineralType.NICKEL: 2,
		GameState.MineralType.SILICA: 3,
		GameState.MineralType.PLATINUM: 5
	}
	price_history = {
		GameState.MineralType.IRON: [1],
		GameState.MineralType.NICKEL: [2],
		GameState.MineralType.SILICA: [3],
		GameState.MineralType.PLATINUM: [5]
	}
	_nickel_recent_sales = 0.0
	_nickel_appreciation = 0.0
	_market_cycle = 0
	_platinum_pressure = 0.0
	fuel_price = FUEL_BASE_PRICE
	_fuel_drift = 0.0
	fuel_price_history = [FUEL_BASE_PRICE]
	prices_changed.emit(market_prices)
