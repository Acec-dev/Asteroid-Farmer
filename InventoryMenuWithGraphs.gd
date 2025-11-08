extends Control
## Enhanced InventoryMenu with integrated price graphs
## This is an example of how to add MineralPriceGraph to your existing InventoryMenu

@onready var sell_btn := $Panel/VBox/HBox/SellAll
@onready var iron_label := $Panel/VBox/IronLabel
@onready var nickel_label := $Panel/VBox/NickelLabel
@onready var silica_label := $Panel/VBox/SilicaLabel
@onready var credit_label := $Panel/VBox/CreditLabel
@onready var iron_price_label = $Panel/VBox/HBox/VBoxContainer/IronPriceLabel
@onready var nickel_price_label = $Panel/VBox/HBox/VBoxContainer/NickelPriceLabel
@onready var silica_price_label = $Panel/VBox/HBox/VBoxContainer/SilicaPriceLabel

# References to dynamically created graphs
var _graphs: Dictionary = {}


func _ready() -> void:
	visible = true # set to true for debug
	GameState.inventory_changed.connect(_refresh)
	GameState.credits_changed.connect(_refresh)
	GameState.prices_changed.connect(_price_refresh)
	sell_btn.pressed.connect(_on_sell)
	_refresh()
	_price_refresh()

	# Add price graphs below the existing UI
	_create_price_graphs()


func _create_price_graphs() -> void:
	# Find or create a container for graphs
	# This assumes your scene has $Panel/VBox - adjust path as needed
	var vbox = $Panel/VBox

	# Add a separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

	# Add title label
	var title = Label.new()
	title.text = "Price History (Last 10 Updates)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Create horizontal container for graphs
	var graph_container = HBoxContainer.new()
	graph_container.add_theme_constant_override("separation", 10)
	vbox.add_child(graph_container)

	# Create a graph for each mineral
	var minerals = ["iron", "nickel", "silica"]
	var colors = {
		"iron": Color.STEEL_BLUE,
		"nickel": Color.DARK_SEA_GREEN,
		"silica": Color.LIGHT_CORAL
	}

	for mineral in minerals:
		var graph = preload("res://MineralPriceGraph.gd").new()
		graph.mineral_type = mineral
		graph.line_color = colors[mineral]
		graph.custom_minimum_size = Vector2(250, 180)
		graph.show_labels = true
		graph.show_grid = true

		graph_container.add_child(graph)
		_graphs[mineral] = graph

	print("Price graphs added to InventoryMenu")


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
