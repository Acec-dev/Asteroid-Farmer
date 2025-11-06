extends ProgressBar

## Shield Bar UI Component
## Displays the player's current shield as a progress bar with color feedback
##
## Usage: Add this script to a ProgressBar node in your UI
## The bar will automatically sync with GameState.shield_changed signal

@export var color_full: Color = Color(0.2, 0.8, 1.0)  # Cyan
@export var color_medium: Color = Color(1.0, 0.8, 0.2)  # Yellow
@export var color_low: Color = Color(1.0, 0.3, 0.3)  # Red
@export var color_depleted: Color = Color(0.5, 0.5, 0.5)  # Gray

func _ready() -> void:
	# Connect to GameState shield signal
	if GameState.has_signal("shield_changed"):
		GameState.shield_changed.connect(_on_shield_changed)

	# Initialize bar
	max_value = GameState.max_shield
	value = GameState.max_shield
	_update_color(1.0)

func _on_shield_changed(current: float, maximum: float) -> void:
	"""Update the progress bar when shield changes"""
	max_value = maximum
	value = current

	# Calculate percentage for color feedback
	var percentage = current / maximum if maximum > 0 else 0.0
	_update_color(percentage)

func _update_color(percentage: float) -> void:
	"""Change bar color based on shield percentage"""
	var bar_color: Color

	if percentage <= 0.0:
		bar_color = color_depleted
	elif percentage <= 0.25:
		bar_color = color_low
	elif percentage <= 0.50:
		bar_color = color_medium
	else:
		bar_color = color_full

	# Apply color to the progress bar fill
	add_theme_color_override("fill_color", bar_color)
