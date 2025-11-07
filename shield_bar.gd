extends Control

## Simple white shield bar that shrinks left as shield depletes

var current_shield: float = 100.0
var max_shield: float = 100.0

@export var bar_width: float = 200.0
@export var bar_height: float = 20.0

func _ready() -> void:
	# Set size
	custom_minimum_size = Vector2(bar_width, bar_height)
	
	# Connect to GameState
	if GameState.has_signal("shield_changed"):
		GameState.shield_changed.connect(_on_shield_changed)
	
	# Initialize
	current_shield = GameState.max_shield
	max_shield = GameState.max_shield
	queue_redraw()

func _on_shield_changed(current: float, maximum: float) -> void:
	current_shield = current
	max_shield = maximum
	queue_redraw()

func _draw() -> void:
	# Calculate bar width based on shield percentage
	var percentage = current_shield / max_shield if max_shield > 0 else 0.0
	var fill_width = bar_width * percentage
	
	# Draw white rectangle (shrinks from right)
	if fill_width > 0:
		draw_rect(Rect2(0, 0, fill_width, bar_height), Color.WHITE, true)
	
	# Optional: Draw border outline
	draw_rect(Rect2(0, 0, bar_width, bar_height), Color.WHITE, false, 2.0)
