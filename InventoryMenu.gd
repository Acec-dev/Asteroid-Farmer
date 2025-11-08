extends Control

@onready var sell_btn := $Panel/VBox/HBox/SellAll
@onready var iron_label := $Panel/VBox/IronLabel
@onready var nickel_label := $Panel/VBox/NickelLabel
@onready var silica_label := $Panel/VBox/SilicaLabel

func _ready() -> void:
	visible = true
	GameState.inventory_changed.connect(_refresh)
	GameState.credits_changed.connect(_refresh)
	GameState.prices_changed.connect(_refresh)
	sell_btn.pressed.connect(_on_sell)
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		visible = not visible

func _refresh(_new_credits: int = 0) -> void:
	var iron_price = GameState.market_prices["iron"]
	var nickel_price = GameState.market_prices["nickel"]
	var silica_price = GameState.market_prices["silica"]

	iron_label.text   = "Iron: %d (@%dc)"   % [GameState.minerals["iron"], iron_price]
	nickel_label.text = "Nickel: %d (@%dc)" % [GameState.minerals["nickel"], nickel_price]
	silica_label.text = "Silica: %d (@%dc)" % [GameState.minerals["silica"], silica_price]

func _on_sell() -> void:
	GameState.sell_all()
