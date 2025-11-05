extends Control

@onready var sell_btn := $Panel/VBox/HBox/SellAll
@onready var iron_label := $Panel/VBox/IronLabel
@onready var nickel_label := $Panel/VBox/NickelLabel
@onready var silica_label := $Panel/VBox/SilicaLabel

func _ready() -> void:
	visible = true
	GameState.inventory_changed.connect(_refresh)
	GameState.credits_changed.connect(_refresh)
	sell_btn.pressed.connect(_on_sell)
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		visible = not visible

func _refresh() -> void:
	iron_label.text   = "Iron: %d"   % GameState.minerals["iron"]
	nickel_label.text = "Nickel: %d" % GameState.minerals["nickel"]
	silica_label.text = "Silica: %d" % GameState.minerals["silica"]

func _on_sell() -> void:
	GameState.sell_all()
