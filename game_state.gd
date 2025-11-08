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

# Market price system (updated by Market singleton)
var market_prices := {
	"iron": 1,
	"nickel": 2,
	"silica": 3
}

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
			if k == "nickel" and Market:
				Market.record_nickel_sale(count)

			minerals[k] = 0
	if total > 0:
		add_credits(total)
		emit_signal("inventory_changed")

func _price_for(kind: StringName) -> int:
	if market_prices.has(kind):
		return market_prices[kind]
	return 1


## Get price from Market singleton (convenience wrapper)
func get_market_price(mineral: String) -> int:
	if Market:
		return Market.get_price(mineral)
	return _price_for(mineral)
