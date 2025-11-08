extends Control

@onready var sell_btn := $Panel/VBox/HBox/SellAll
@onready var iron_label := $Panel/VBox/IronLabel
@onready var nickel_label := $Panel/VBox/NickelLabel
@onready var silica_label := $Panel/VBox/SilicaLabel
@onready var credit_label := $Panel/VBox/CreditLabel
@onready var iron_price_label = $Panel/VBox/HBox/VBoxContainer/IronPriceLabel
@onready var nickel_price_label = $Panel/VBox/HBox/VBoxContainer/NickelPriceLabel
@onready var silica_price_label = $Panel/VBox/HBox/VBoxContainer/SilicaPriceLabel

func _ready() -> void:
	visible = true # true for debugging


	GameState.inventory_changed.connect(_refresh)
	GameState.credits_changed.connect(_refresh)
	GameState.prices_changed.connect(_price_refresh)
	sell_btn.pressed.connect(_on_sell)
	_refresh()
	_price_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		visible = not visible

func _refresh(_new_credits: int = 0) -> void:
	iron_label.text   = "Iron: %d"   % GameState.minerals["iron"]
	nickel_label.text = "Nickel: %d" % GameState.minerals["nickel"]
	silica_label.text = "Silica: %d" % GameState.minerals["silica"]
	credit_label.text = "Credits: %d" % GameState.credits
	
func _price_refresh():
	iron_price_label.text   = "Iron: $%d"   % GameState.market_prices["iron"]
	nickel_price_label.text = "Nickel: $%d" % GameState.market_prices["nickel"]
	silica_price_label.text = "Silica: $%d" % GameState.market_prices["silica"]

	
	

func _on_sell() -> void:
	GameState.sell_all()
