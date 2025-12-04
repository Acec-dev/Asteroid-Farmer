## Radar component that controls camera zoom based on radar upgrade level
## Higher radar levels = wider view (zoomed out camera)
class_name RadarComponent
extends Node

## Camera reference
var camera: Camera2D = null

## Radar stats
var radar_level: int = 0
var zoom_values: Array[float] = [1.0, 1.2, 1.5, 2.0, 2.5]  # Zoom levels per upgrade

## Current zoom (inverse of camera.zoom)
var current_zoom: float = 1.0

## Zoom multiplier for external effects (like UI panels)
var zoom_multiplier: float = 1.0

## Smooth transition
@export var zoom_transition_speed: float = 2.0

func _ready() -> void:
	# Find camera in the scene
	_find_camera()

	# Sync with GameState
	sync_with_game_state()

	# Connect to GameState for upgrade updates
	if GameState.has_signal("upgrades_changed"):
		GameState.upgrades_changed.connect(_on_upgrades_changed)

	# Apply initial zoom
	_apply_zoom()

func _process(delta: float) -> void:
	if not camera:
		return

	# Smoothly transition to target zoom
	var target_zoom = _get_target_zoom()
	current_zoom = lerp(current_zoom, target_zoom, zoom_transition_speed * delta)

	# Apply zoom multiplier for external effects (like UI panels)
	var final_zoom = current_zoom * zoom_multiplier

	# Camera zoom is inverse - higher value = more zoomed out
	# We want radar to zoom OUT, so we divide by final_zoom
	camera.zoom = Vector2.ONE / final_zoom

## Find the camera in the scene
func _find_camera() -> void:
	# Try to find camera as child of owner
	var owner_node = get_parent()
	if owner_node:
		camera = owner_node.get_node_or_null("Camera2D")

	# If not found, search in the scene tree
	if not camera:
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			camera = cameras[0] as Camera2D

	# Last resort - find any Camera2D
	if not camera:
		camera = _find_camera_recursive(get_tree().root)

	if camera:
		print("RadarComponent: Found camera - ", camera.name)
	else:
		push_warning("RadarComponent: No camera found in scene!")

func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result = _find_camera_recursive(child)
		if result:
			return result
	return null

## Get target zoom based on radar level
func _get_target_zoom() -> float:
	if radar_level < zoom_values.size():
		return zoom_values[radar_level]
	return zoom_values[-1]  # Max zoom

## Sync radar level with GameState
func sync_with_game_state() -> void:
	if not GameState:
		return

	# Read radar upgrades from GameState
	if "upgrades" in GameState and GameState.upgrades.has("radar"):
		var radar_upgrades = GameState.upgrades.radar

		if radar_upgrades.has("zoom_level"):
			var zoom_data = radar_upgrades.zoom_level
			if zoom_data.has("level"):
				radar_level = zoom_data.level

			# Override zoom values if provided
			if zoom_data.has("values"):
				zoom_values = []
				for value in zoom_data.values:
					zoom_values.append(float(value))

	print("RadarComponent: Synced - Level: ", radar_level, " Zoom: ", _get_target_zoom())

## Called when GameState upgrades change
func _on_upgrades_changed() -> void:
	sync_with_game_state()

## Apply zoom immediately (no transition)
func _apply_zoom() -> void:
	current_zoom = _get_target_zoom()
	if camera:
		var final_zoom = current_zoom * zoom_multiplier
		camera.zoom = Vector2.ONE / final_zoom

## Manually set radar level (for testing)
func set_radar_level(level: int) -> void:
	radar_level = clamp(level, 0, zoom_values.size() - 1)
	print("RadarComponent: Radar level set to ", radar_level)

## Set custom zoom values
func set_zoom_values(values: Array[float]) -> void:
	zoom_values = values