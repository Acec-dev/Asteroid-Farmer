extends Node2D

## Small shield bar that floats below the player in world space

var current_shield: float = 100.0
var max_shield: float = 100.0

@export var bar_width: float = 40.0
@export var bar_height: float = 4.0
@export var offset_y: float = 28.0  # How far below the player center

func _ready() -> void:
	# Connect to GameState
	if GameState.has_signal("shield_changed"):
		GameState.shield_changed.connect(_on_shield_changed)

	# Initialize
	current_shield = GameState.max_shield
	max_shield = GameState.max_shield
	queue_redraw()

func _process(_delta: float) -> void:
	# Stay below the player, ignoring parent rotation
	if get_parent():
		rotation = -get_parent().rotation
		position = Vector2(0, offset_y).rotated(-get_parent().rotation)

func _on_shield_changed(current: float, maximum: float) -> void:
	current_shield = current
	max_shield = maximum
	queue_redraw()

func _draw() -> void:
	var percentage = current_shield / max_shield if max_shield > 0 else 0.0
	var fill_width = bar_width * percentage
	var x_start = -bar_width * 0.5

	# Background (dark)
	draw_rect(Rect2(x_start, 0, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.6), true)

	# Fill
	if fill_width > 0:
		draw_rect(Rect2(x_start, 0, fill_width, bar_height), Color.WHITE, true)

	# Border
	draw_rect(Rect2(x_start, 0, bar_width, bar_height), Color(0.7, 0.7, 0.7, 0.8), false, 1.0)
