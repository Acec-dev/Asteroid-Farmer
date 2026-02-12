## ScreenUtils - Autoload singleton for viewport/screen utilities
## Provides functions to check if positions or nodes are visible on screen
## AND manages world boundaries (camera limits) for UI panels
## This is accessible globally as ScreenUtils from any script
extends Node

## Margin in pixels to allow hitting objects slightly off-screen
## This prevents objects at the edge from being ignored
const SCREEN_MARGIN: float = 50.0

## World boundary management
var _main_camera: Camera2D = null
var _original_limit_top: int = 0
var _original_limit_bottom: int = 0
var _original_limit_left: int = 0
var _original_limit_right: int = 0
var _boundary_tween: Tween = null

## Check if a world position is visible within the current viewport
## @param node: Any node in the scene tree (used to get viewport/camera)
## @param world_pos: The global position to check
## @return: true if position is on screen (with margin), false otherwise
static func is_position_on_screen(node: Node, world_pos: Vector2) -> bool:
	if not node:
		return true  # Default to allowing if no node provided

	var viewport = node.get_viewport()
	if not viewport:
		return true  # No viewport, allow by default

	var camera = viewport.get_camera_2d()
	if not camera:
		return true  # No camera, allow by default

	# Get viewport size
	var viewport_size = viewport.get_visible_rect().size

	# Transform world position to screen space
	var camera_transform = camera.get_canvas_transform()
	var screen_pos = camera_transform * world_pos

	# Check if position is within viewport bounds (with margin)
	return screen_pos.x >= -SCREEN_MARGIN and screen_pos.x <= viewport_size.x + SCREEN_MARGIN and \
		   screen_pos.y >= -SCREEN_MARGIN and screen_pos.y <= viewport_size.y + SCREEN_MARGIN

## Check if a Node2D is visible within the current viewport
## @param node: The Node2D to check (must have global_position)
## @return: true if node is on screen (with margin), false otherwise
static func is_node_on_screen(node: Node2D) -> bool:
	if not node:
		return false
	return is_position_on_screen(node, node.global_position)

## Get the screen bounds in world space for a given viewport
## @param node: Any node in the scene tree (used to get viewport/camera)
## @return: Rect2 representing the screen bounds in world coordinates, or Rect2() if no camera
static func get_screen_bounds_world(node: Node) -> Rect2:
	if not node:
		return Rect2()

	var viewport = node.get_viewport()
	if not viewport:
		return Rect2()

	var camera = viewport.get_camera_2d()
	if not camera:
		return Rect2()

	# Get viewport size
	var viewport_size = viewport.get_visible_rect().size

	# Transform viewport corners to world space
	var camera_transform = camera.get_canvas_transform()
	var inverse_transform = camera_transform.affine_inverse()

	var top_left = inverse_transform * Vector2.ZERO
	var bottom_right = inverse_transform * viewport_size

	return Rect2(top_left, bottom_right - top_left)

## ========================================
## WORLD BOUNDARY MANAGEMENT
## ========================================

## Initialize the world boundary system with the main camera
## Call this once during game startup (e.g., from main scene)
func set_main_camera(camera: Camera2D) -> void:
	_main_camera = camera
	if _main_camera:
		_original_limit_top = _main_camera.limit_top
		_original_limit_bottom = _main_camera.limit_bottom
		_original_limit_left = _main_camera.limit_left
		_original_limit_right = _main_camera.limit_right
		print("ScreenUtils: World boundaries initialized")
		print("  Top: ", _original_limit_top, ", Bottom: ", _original_limit_bottom)
		print("  Left: ", _original_limit_left, ", Right: ", _original_limit_right)

## Adjust world boundaries (typically called when UI panels open)
## @param top_inset: How many pixels to move the top boundary DOWN (positive = down in Godot Y)
## @param bottom_inset: How many pixels to move the bottom boundary UP (negative = up in Godot Y)
## @param duration: Animation duration in seconds (0 = instant)
func adjust_boundaries(top_inset: int = 0, bottom_inset: int = 0, left_inset: int = 0, right_inset: int = 0, duration: float = 0.5) -> void:
	if not _main_camera:
		push_warning("ScreenUtils: No camera set, call set_main_camera() first")
		return

	# Calculate new limits
	var new_top = _original_limit_top + top_inset
	var new_bottom = _original_limit_bottom - bottom_inset
	var new_left = _original_limit_left + left_inset
	var new_right = _original_limit_right - right_inset

	print("ScreenUtils: Adjusting boundaries")
	print("  Top: ", _original_limit_top, " → ", new_top, " (inset: +", top_inset, ")")
	print("  Bottom: ", _original_limit_bottom, " → ", new_bottom, " (inset: -", bottom_inset, ")")

	if duration <= 0:
		# Instant change
		_main_camera.limit_top = new_top
		_main_camera.limit_bottom = new_bottom
		_main_camera.limit_left = new_left
		_main_camera.limit_right = new_right
	else:
		# Animate change
		if _boundary_tween:
			_boundary_tween.kill()

		_boundary_tween = create_tween()
		_boundary_tween.set_parallel(true)
		_boundary_tween.set_ease(Tween.EASE_OUT)
		_boundary_tween.set_trans(Tween.TRANS_CUBIC)

		_boundary_tween.tween_property(_main_camera, "limit_top", new_top, duration)
		_boundary_tween.tween_property(_main_camera, "limit_bottom", new_bottom, duration)
		_boundary_tween.tween_property(_main_camera, "limit_left", new_left, duration)
		_boundary_tween.tween_property(_main_camera, "limit_right", new_right, duration)

## Restore world boundaries to original values
## @param duration: Animation duration in seconds (0 = instant)
func restore_boundaries(duration: float = 0.5) -> void:
	if not _main_camera:
		push_warning("ScreenUtils: No camera set, call set_main_camera() first")
		return

	print("ScreenUtils: Restoring boundaries to original values")

	if duration <= 0:
		# Instant restore
		_main_camera.limit_top = _original_limit_top
		_main_camera.limit_bottom = _original_limit_bottom
		_main_camera.limit_left = _original_limit_left
		_main_camera.limit_right = _original_limit_right
	else:
		# Animate restore
		if _boundary_tween:
			_boundary_tween.kill()

		_boundary_tween = create_tween()
		_boundary_tween.set_parallel(true)
		_boundary_tween.set_ease(Tween.EASE_IN)
		_boundary_tween.set_trans(Tween.TRANS_CUBIC)

		_boundary_tween.tween_property(_main_camera, "limit_top", _original_limit_top, duration)
		_boundary_tween.tween_property(_main_camera, "limit_bottom", _original_limit_bottom, duration)
		_boundary_tween.tween_property(_main_camera, "limit_left", _original_limit_left, duration)
		_boundary_tween.tween_property(_main_camera, "limit_right", _original_limit_right, duration)

