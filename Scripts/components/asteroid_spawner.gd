## Asteroid spawning component that spawns asteroids at screen edges
## Configurable spawn rates, asteroid stats, and difficulty scaling
class_name AsteroidSpawner
extends Node

## Emitted when an asteroid is spawned
signal asteroid_spawned(asteroid: Asteroid)

## References
var camera: Camera2D = null
var player: Node2D = null
var asteroid_scene: PackedScene = null

## Spawn configuration (can be set by GameState upgrades)
var spawn_interval: float = 2.0  # Seconds between spawns
var spawn_count: int = 1  # Asteroids per spawn
var spawn_edge_buffer: float = 100.0  # How far beyond camera to spawn

## Asteroid configuration
var asteroid_speed_min: float = 150.0
var asteroid_speed_max: float = 300.0
var asteroid_health: int = 2  # Hit points for spawned asteroids
var asteroid_radius: float = 28.0  # Size of asteroids

## Trajectory mode
enum TrajectoryMode {
	RANDOM_ACROSS,  # Random direction across screen
	TOWARD_PLAYER,  # Original behavior (toward player area)
	TOWARD_CENTER,  # Toward screen center
	MIXED  # Mix of all modes
}
var trajectory_mode: TrajectoryMode = TrajectoryMode.RANDOM_ACROSS

## Internal state
var _spawn_timer: Timer = null
var _difficulty_level: int = 0

func _ready() -> void:
	# Find camera and player
	_find_camera()
	_find_player()

	# Load asteroid scene
	if ResourceLoader.exists("res://Scenes/asteroid.tscn"):
		asteroid_scene = load("res://Scenes/asteroid.tscn")
	else:
		push_error("AsteroidSpawner: Asteroid scene not found!")

	# Setup spawn timer
	_setup_spawn_timer()

	# Connect to GameState for difficulty updates
	if GameState.has_signal("upgrades_changed"):
		GameState.upgrades_changed.connect(_on_difficulty_changed)

	# Sync initial configuration
	sync_with_game_state()

	print("AsteroidSpawner: Initialized - Interval: ", spawn_interval, "s, Speed: ", asteroid_speed_min, "-", asteroid_speed_max)

func _setup_spawn_timer() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	_spawn_timer.start()

func _find_camera() -> void:
	# Try to find camera in player
	if player:
		camera = player.get_node_or_null("PlayerCam")

	# Search in scene tree
	if not camera:
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			camera = cameras[0] as Camera2D

	# Last resort - recursive search
	if not camera:
		camera = _find_camera_recursive(get_tree().root)

	if camera:
		print("AsteroidSpawner: Found camera - ", camera.name)
	else:
		push_warning("AsteroidSpawner: No camera found!")

func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result = _find_camera_recursive(child)
		if result:
			return result
	return null

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node2D
		print("AsteroidSpawner: Found player - ", player.name)
	else:
		push_warning("AsteroidSpawner: No player found!")

## Called when spawn timer times out
func _on_spawn_timer_timeout() -> void:
	_spawn_asteroids(spawn_count)

## Spawn a batch of asteroids
func _spawn_asteroids(count: int) -> void:
	for i in range(count):
		_spawn_single_asteroid()

## Spawn a single asteroid
func _spawn_single_asteroid() -> void:
	if not asteroid_scene:
		return

	# Get spawn position and direction
	var spawn_data = _get_spawn_data()
	if spawn_data == null:
		return

	var spawn_pos: Vector2 = spawn_data.position
	var direction: Vector2 = spawn_data.direction
	var speed: float = randf_range(asteroid_speed_min, asteroid_speed_max)

	# Instantiate asteroid
	var asteroid: Asteroid = asteroid_scene.instantiate()

	# Configure asteroid stats
	asteroid.hit_points = asteroid_health
	asteroid.radius = asteroid_radius
	asteroid.global_position = spawn_pos

	# Randomly assign mineral type (IRON, NICKEL, or SILICA)
	#asteroid.mineral_kind = GameState.MineralType.values()[randi() % 3]

	# Set motion
	if asteroid.has_method("setup_motion"):
		# Calculate target point based on direction
		var target_point = spawn_pos + direction * 5000.0  # Far point in that direction
		asteroid.setup_motion(spawn_pos, target_point, speed)

	# Add to scene
	get_tree().current_scene.add_child(asteroid)

	# Emit signal
	asteroid_spawned.emit(asteroid)

## Get spawn position and direction based on camera bounds
func _get_spawn_data() -> Dictionary:
	if not camera:
		return {}

	# Get camera viewport size and zoom
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom = camera.zoom.x  # Assuming uniform zoom

	# Calculate visible area in world space
	var visible_width = viewport_size.x / zoom
	var visible_height = viewport_size.y / zoom

	# Camera world position
	var cam_pos = camera.get_screen_center_position()

	# Calculate screen bounds
	var left = cam_pos.x - visible_width / 2.0
	var right = cam_pos.x + visible_width / 2.0
	var top = cam_pos.y - visible_height / 2.0
	var bottom = cam_pos.y + visible_height / 2.0

	# Choose random edge (0=top, 1=right, 2=bottom, 3=left)
	var edge = randi() % 4
	var spawn_pos = Vector2.ZERO
	var direction = Vector2.ZERO

	match edge:
		0:  # Top edge
			spawn_pos.x = randf_range(left, right)
			spawn_pos.y = top - spawn_edge_buffer
			direction = _get_direction_for_edge("top", spawn_pos, cam_pos, visible_width, visible_height)
		1:  # Right edge
			spawn_pos.x = right + spawn_edge_buffer
			spawn_pos.y = randf_range(top, bottom)
			direction = _get_direction_for_edge("right", spawn_pos, cam_pos, visible_width, visible_height)
		2:  # Bottom edge
			spawn_pos.x = randf_range(left, right)
			spawn_pos.y = bottom + spawn_edge_buffer
			direction = _get_direction_for_edge("bottom", spawn_pos, cam_pos, visible_width, visible_height)
		3:  # Left edge
			spawn_pos.x = left - spawn_edge_buffer
			spawn_pos.y = randf_range(top, bottom)
			direction = _get_direction_for_edge("left", spawn_pos, cam_pos, visible_width, visible_height)

	return {
		"position": spawn_pos,
		"direction": direction
	}

## Get direction vector based on edge and trajectory mode
func _get_direction_for_edge(edge: String, spawn_pos: Vector2, cam_pos: Vector2, visible_width: float, visible_height: float) -> Vector2:
	match trajectory_mode:
		TrajectoryMode.RANDOM_ACROSS:
			return _get_random_across_direction(edge, spawn_pos, cam_pos, visible_width, visible_height)
		TrajectoryMode.TOWARD_PLAYER:
			if player:
				return (player.global_position - spawn_pos).normalized()
			else:
				return _get_random_across_direction(edge, spawn_pos, cam_pos, visible_width, visible_height)
		TrajectoryMode.TOWARD_CENTER:
			return (cam_pos - spawn_pos).normalized()
		TrajectoryMode.MIXED:
			var rand = randf()
			if rand < 0.6:  # 60% random across
				return _get_random_across_direction(edge, spawn_pos, cam_pos, visible_width, visible_height)
			elif rand < 0.8 and player:  # 20% toward player
				return (player.global_position - spawn_pos).normalized()
			else:  # 20% toward center
				return (cam_pos - spawn_pos).normalized()

	return Vector2.RIGHT  # Fallback

## Get random direction that crosses the screen
func _get_random_across_direction(edge: String, spawn_pos: Vector2, cam_pos: Vector2, visible_width: float, visible_height: float) -> Vector2:
	# Pick a random point on the opposite side of the screen
	var target_pos = Vector2.ZERO

	match edge:
		"top":
			# Spawn from top, aim toward bottom half (with some variation to sides)
			target_pos.x = cam_pos.x + randf_range(-visible_width * 0.6, visible_width * 0.6)
			target_pos.y = cam_pos.y + randf_range(visible_height * 0.3, visible_height * 0.7)
		"bottom":
			# Spawn from bottom, aim toward top half
			target_pos.x = cam_pos.x + randf_range(-visible_width * 0.6, visible_width * 0.6)
			target_pos.y = cam_pos.y + randf_range(-visible_height * 0.7, -visible_height * 0.3)
		"left":
			# Spawn from left, aim toward right half
			target_pos.x = cam_pos.x + randf_range(visible_width * 0.3, visible_width * 0.7)
			target_pos.y = cam_pos.y + randf_range(-visible_height * 0.6, visible_height * 0.6)
		"right":
			# Spawn from right, aim toward left half
			target_pos.x = cam_pos.x + randf_range(-visible_width * 0.7, -visible_width * 0.3)
			target_pos.y = cam_pos.y + randf_range(-visible_height * 0.6, visible_height * 0.6)

	return (target_pos - spawn_pos).normalized()

## Sync spawner settings with GameState
func sync_with_game_state() -> void:
	if not GameState:
		return

	# Check if spawner config exists in GameState
	if "upgrades" in GameState and GameState.upgrades.has("spawner"):
		var spawner_config = GameState.upgrades.spawner

		# Difficulty level
		if spawner_config.has("difficulty"):
			var diff_data = spawner_config.difficulty
			if diff_data.has("level"):
				_difficulty_level = diff_data.level
				_apply_difficulty_level(_difficulty_level)

	print("AsteroidSpawner: Synced with GameState - Difficulty: ", _difficulty_level)

## Apply difficulty level to spawner settings
func _apply_difficulty_level(level: int) -> void:
	# Scale spawn rate (more asteroids at higher difficulty)
	match level:
		0:  # Easy
			spawn_interval = 3.0
			spawn_count = 1
			asteroid_health = 2
			asteroid_speed_min = 150.0
			asteroid_speed_max = 250.0
		1:  # Normal
			spawn_interval = 2.0
			spawn_count = 1
			asteroid_health = 2
			asteroid_speed_min = 200.0
			asteroid_speed_max = 300.0
		2:  # Hard
			spawn_interval = 1.5
			spawn_count = 1
			asteroid_health = 3
			asteroid_speed_min = 250.0
			asteroid_speed_max = 400.0
		3:  # Very Hard
			spawn_interval = 1.0
			spawn_count = 2
			asteroid_health = 3
			asteroid_speed_min = 300.0
			asteroid_speed_max = 500.0
		_:  # Extreme
			spawn_interval = 0.8
			spawn_count = 2
			asteroid_health = 4
			asteroid_speed_min = 350.0
			asteroid_speed_max = 600.0

	# Update timer
	if _spawn_timer:
		_spawn_timer.wait_time = spawn_interval

## Called when GameState difficulty changes
func _on_difficulty_changed() -> void:
	sync_with_game_state()

## Manually set difficulty (for testing)
func set_difficulty(level: int) -> void:
	_difficulty_level = level
	_apply_difficulty_level(level)

## Pause/resume spawning
func set_spawning_enabled(enabled: bool) -> void:
	if _spawn_timer:
		if enabled:
			_spawn_timer.start()
		else:
			_spawn_timer.stop()

## Manually trigger spawn (for testing)
func spawn_now(count: int = 1) -> void:
	_spawn_asteroids(count)
