## Radar component that controls camera zoom based on radar upgrade level
## Higher radar levels = wider view (zoomed out camera)
class_name RadarComponent
extends Node

## Camera reference
var camera: Camera2D = null

## Radar stats
var radar_level: int = 0
var zoom_values: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.6]  # Lower = more zoomed out

## Base zoom level (set when radar upgrades, not updated every frame)
var base_zoom: float = 1.0

func _ready() -> void:
	# Find camera in the scene
	_find_camera()

	# Sync with GameState
	sync_with_game_state()

	# Connect to GameState for upgrade updates
	if GameState.has_signal("upgrades_changed"):
		GameState.upgrades_changed.connect(_on_upgrades_changed)

	# Apply initial zoom
	_apply_base_zoom()

## Get target zoom based on radar level
func _get_target_zoom() -> float:
	if radar_level < zoom_values.size():
		return zoom_values[radar_level]
	return zoom_values[-1]  # Max zoom

## Apply the base zoom level to camera (called only when radar upgrades)
func _apply_base_zoom() -> void:
	base_zoom = _get_target_zoom()
	if camera:
		# Directly set camera zoom - lower values = more zoomed out
		camera.zoom = Vector2(base_zoom, base_zoom)
		print("RadarComponent: Set base zoom to ", base_zoom, " (camera.zoom = ", camera.zoom, ")")

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
	var old_level = radar_level
	sync_with_game_state()

	# Only update zoom if level actually changed
	if old_level != radar_level:
		_apply_base_zoom()

## Manually set radar level (for testing)
func set_radar_level(level: int) -> void:
	radar_level = clamp(level, 0, zoom_values.size() - 1)
	print("RadarComponent: Radar level set to ", radar_level)
	_apply_base_zoom()  # Apply new zoom when level changes

## Set custom zoom values
func set_zoom_values(values: Array[float]) -> void:
	zoom_values = values