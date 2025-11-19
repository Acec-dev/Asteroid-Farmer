extends Node2D

@export var player_scene: PackedScene
@export var asteroid_scene: PackedScene
@export var floating_text: PackedScene

# Tunables for the new behavior
@export var spawn_ring_radius: float = 900.0  # how far from the player to spawn
@export var spawn_ring_jitter: float = 120.0  # randomize radius a bit
@export var band_half_size: Vector2 = Vector2(160, 120)  # "middle band" around screen center
@export var asteroid_speed_range: Vector2 = Vector2(220, 360) # min/max straight speed

# Countdown timer settings
@export var countdown_duration: float = 30.0  # Total countdown time in seconds
@export var initial_spawn_interval: float = 2.0  # Starting spawn interval
@export var min_spawn_interval: float = 0.3  # Fastest spawn interval at countdown end
@export var max_speed_multiplier: float = 2.0  # Speed multiplier at countdown end
@export var min_band_size: Vector2 = Vector2(40, 30)  # Tightest targeting at countdown end

@onready var _spawn_timer := $SpawnTimer as Timer
@onready var rocket_button = $CanvasLayer/InventoryMenu/RocketsButton

@onready var mineral_name = GameState.get_mat()
var _player: Node2D

# Countdown timer variables
var countdown_time: float = 0.0
var countdown_active: bool = true
var countdown_label: Label = null

# Store original values for scaling
var original_band_half_size: Vector2
var original_asteroid_speed_range: Vector2

signal spawn_text

func _ready() -> void:
	randomize()

	# Store original values
	original_band_half_size = band_half_size
	original_asteroid_speed_range = asteroid_speed_range

	# Initialize countdown
	countdown_time = countdown_duration

	# Setup spawn timer
	_spawn_timer.timeout.connect(_spawn_asteroid)
	_spawn_timer.wait_time = initial_spawn_interval
	_spawn_timer.start()

	_spawn_player()
	_create_countdown_ui()

	GameState.new_pickup.connect(Callable(self, "_spawn_text"))

func _spawn_player() -> void:
	_player = player_scene.instantiate()
	_player.global_position = get_viewport_rect().size * 0.5
	add_child(_player)

func _spawn_asteroid() -> void:
	if not asteroid_scene or _player == null:
		return

	# 1) Pick a spawn point in a ring AROUND THE PLAYER
	var ang := randf() * TAU
	var r := spawn_ring_radius + randf_range(-spawn_ring_jitter, spawn_ring_jitter)
	var spawn_pos := _player.global_position + Vector2.RIGHT.rotated(ang) * r

	# 2) Pick a target point inside a "middle band"
	var band_point := _player.global_position + Vector2(
		randf_range(-band_half_size.x, band_half_size.x),
		randf_range(-band_half_size.y, band_half_size.y)
	)

	# 3) Spawn and set its straight-line motion so the line passes through that band
	var a: RigidBody2D = asteroid_scene.instantiate()
	add_child(a)
	

	var speed := randf_range(asteroid_speed_range.x, asteroid_speed_range.y)
	# Call our new initializer on the asteroid
	a.setup_motion(spawn_pos, band_point, speed)
	
func _spawn_text():
	_player.popup_mineral(GameState.current_mat)
	emit_signal("spawn_text")
	
func _get_player_pos():
	return Vector2(_player.global_position)


func _on_rockets_button_pressed() -> void:
	print("Upgraded to rockets")
	_player.enable_rockets()

func _create_countdown_ui() -> void:
	"""Create a label to display the countdown timer"""
	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"

	# Position at top center of screen
	countdown_label.position = Vector2(get_viewport_rect().size.x / 2 - 100, 20)
	countdown_label.size = Vector2(200, 50)

	# Style the label
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Create a theme for larger, more visible text
	var label_settings = LabelSettings.new()
	label_settings.font_size = 32
	label_settings.font_color = Color.WHITE
	label_settings.outline_size = 4
	label_settings.outline_color = Color.BLACK
	countdown_label.label_settings = label_settings

	# Add to CanvasLayer for proper UI rendering
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.add_child(countdown_label)
	else:
		# Create a new CanvasLayer if one doesn't exist
		canvas_layer = CanvasLayer.new()
		add_child(canvas_layer)
		canvas_layer.add_child(countdown_label)

func _process(delta: float) -> void:
	if countdown_active and countdown_time > 0:
		countdown_time -= delta

		# Update UI
		if countdown_label:
			var minutes = int(countdown_time) / 60
			var seconds = int(countdown_time) % 60
			countdown_label.text = "Time: %02d:%02d" % [minutes, seconds]

			# Change color as time runs out
			var time_ratio = countdown_time / countdown_duration
			if time_ratio < 0.25:  # Last 25% - red
				countdown_label.label_settings.font_color = Color.RED
			elif time_ratio < 0.5:  # 25-50% - yellow
				countdown_label.label_settings.font_color = Color.YELLOW
			else:  # > 50% - white
				countdown_label.label_settings.font_color = Color.WHITE

		# Update difficulty based on remaining time
		_update_difficulty()

		# Stop countdown at zero
		if countdown_time <= 0:
			countdown_time = 0
			countdown_active = false
			if countdown_label:
				countdown_label.text = "MAXIMUM THREAT!"
				countdown_label.label_settings.font_color = Color.RED

func _update_difficulty() -> void:
	"""Adjust spawn rate and asteroid behavior based on countdown"""
	# Calculate progress (0 = start, 1 = end of countdown)
	var progress = 1.0 - (countdown_time / countdown_duration)
	progress = clamp(progress, 0.0, 1.0)

	# 1. Increase spawn rate (decrease spawn interval)
	var new_spawn_interval = lerp(initial_spawn_interval, min_spawn_interval, progress)
	_spawn_timer.wait_time = new_spawn_interval

	# 2. Increase asteroid speed
	var speed_mult = lerp(1.0, max_speed_multiplier, progress)
	asteroid_speed_range = original_asteroid_speed_range * speed_mult

	# 3. Make asteroids target player more directly (tighter band)
	band_half_size = original_band_half_size.lerp(min_band_size, progress)
