extends PanelContainer

# Signal emitted when camera bounds are changed
signal camera_bounds_changed()
signal panel_visibility_changed(is_visible: bool)

# Animation settings
@export var slide_duration: float = 0.5
@export var start_hidden: bool = true
@export var zoom_amount: float = 1.15  # How much to zoom out when panel is visible

var panel_visible: bool = false
var original_anchor_left: float
var original_anchor_right: float
var original_anchor_top: float
var tween: Tween

# Camera and component references
var radar_camera: Camera2D
var radar_component: Node  # RadarComponent that controls zoom

# Store the panel's screen position for bounds calculation
var panel_top_screen_y: float = 0.0

func _ready() -> void:
	# Add to group so player can find us
	add_to_group("graphs_panel")

	# Store the original anchor positions from the scene
	original_anchor_left = anchor_left
	original_anchor_right = anchor_right
	original_anchor_top = anchor_top

	# Get reference to the Radar camera (GraphsPanel is under CanvasLayer, Radar is sibling to CanvasLayer)
	radar_camera = get_node("../../Radar") if has_node("../../Radar") else null

	# Find the RadarComponent (it's attached to the player)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		radar_component = player.find_child("RadarComponent")
		if radar_component:
			print("GraphsPanel: Found RadarComponent")

	# Calculate the panel's top edge position in screen space when visible
	var viewport_height = get_viewport_rect().size.y
	panel_top_screen_y = viewport_height * original_anchor_top

	print("GraphsPanel: Panel will be at screen Y = ", panel_top_screen_y)

	# Start hidden if configured (moved off-screen to the left)
	if start_hidden:
		# Move the panel completely off-screen to the left
		var offset = anchor_right - anchor_left  # Width in anchor units
		anchor_left = -offset
		anchor_right = 0.0
		panel_visible = false

func slide_in() -> void:
	"""Slides the panel in from left to right"""
	if panel_visible:
		return

	panel_visible = true

	# Cancel any existing tween
	if tween:
		tween.kill()

	# Create new tween for smooth animation
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)  # Animate everything simultaneously

	# Animate panel position
	tween.tween_property(self, "anchor_left", original_anchor_left, slide_duration)
	tween.tween_property(self, "anchor_right", original_anchor_right, slide_duration)

	# Animate radar component zoom multiplier if available
	if radar_component:
		# Increase the multiplier to zoom out (higher multiplier = more zoom out)
		tween.tween_property(radar_component, "zoom_multiplier", zoom_amount, slide_duration)

	# Emit signals when tween finishes
	tween.finished.connect(func():
		camera_bounds_changed.emit()
		panel_visibility_changed.emit(true)
	)

func slide_out() -> void:
	"""Slides the panel out from right to left"""
	if not panel_visible:
		return

	panel_visible = false

	# Calculate the hidden position (off-screen to the left)
	var offset = original_anchor_right - original_anchor_left

	# Cancel any existing tween
	if tween:
		tween.kill()

	# Create new tween for smooth animation
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)  # Animate everything simultaneously

	# Animate panel position
	tween.tween_property(self, "anchor_left", -offset, slide_duration)
	tween.tween_property(self, "anchor_right", 0.0, slide_duration)

	# Restore radar component zoom multiplier if available
	if radar_component:
		# Reset multiplier back to 1.0 (normal zoom)
		tween.tween_property(radar_component, "zoom_multiplier", 1.0, slide_duration)

	# Emit signals when tween finishes
	tween.finished.connect(func():
		camera_bounds_changed.emit()
		panel_visibility_changed.emit(false)
	)

func toggle() -> void:
	"""Toggles the panel visibility with animation"""
	if panel_visible:
		slide_out()
	else:
		slide_in()

## Get the maximum Y position for the player in world coordinates
## This accounts for the panel's screen position and camera zoom
func get_player_max_y() -> float:
	if not panel_visible or not radar_camera:
		# Panel hidden or no camera - use default camera limit
		return radar_camera.limit_bottom if radar_camera else 1080.0

	# Convert screen space panel position to world space
	# Screen Y to world Y formula:
	# world_y = camera_y + (screen_y - viewport_height/2) / camera_zoom

	var viewport_height = get_viewport_rect().size.y
	var camera_zoom = radar_camera.zoom.y  # zoom is a Vector2, but usually uniform
	var camera_y = radar_camera.position.y

	# Calculate world Y position of panel's top edge
	var world_y = camera_y + (panel_top_screen_y - viewport_height / 2.0) / camera_zoom

	return world_y