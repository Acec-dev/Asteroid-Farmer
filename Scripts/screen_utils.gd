## ScreenUtils - Autoload singleton for viewport/screen utilities
## Provides functions to check if positions or nodes are visible on screen
## This is accessible globally as ScreenUtils from any script
extends Node

## Margin in pixels to allow hitting objects slightly off-screen
## This prevents objects at the edge from being ignored
const SCREEN_MARGIN: float = 50.0

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
