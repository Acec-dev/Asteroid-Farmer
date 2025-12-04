extends PanelContainer

# Signal emitted when camera bounds are changed
signal camera_bounds_changed()

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
var original_camera_limit_bottom: int
var reduced_camera_limit_bottom: int

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

	# If we found the camera, store its original values
	if radar_camera:
		original_camera_limit_bottom = radar_camera.limit_bottom

		# Calculate where the panel will be when visible
		var viewport_height = get_viewport_rect().size.y
		reduced_camera_limit_bottom = int(viewport_height * original_anchor_top)

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

	# Animate camera if available
	if radar_camera:
		# Reduce the play area by adjusting camera bottom limit
		tween.tween_property(radar_camera, "limit_bottom", reduced_camera_limit_bottom, slide_duration)

	# Animate radar component zoom multiplier if available
	if radar_component:
		# Increase the multiplier to zoom out (higher multiplier = more zoom out)
		tween.tween_property(radar_component, "zoom_multiplier", zoom_amount, slide_duration)

	# Emit signal when tween finishes to notify player of bounds change
	tween.finished.connect(func(): camera_bounds_changed.emit())

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

	# Restore camera to original state if available
	if radar_camera:
		# Restore the full play area
		tween.tween_property(radar_camera, "limit_bottom", original_camera_limit_bottom, slide_duration)

	# Restore radar component zoom multiplier if available
	if radar_component:
		# Reset multiplier back to 1.0 (normal zoom)
		tween.tween_property(radar_component, "zoom_multiplier", 1.0, slide_duration)

	# Emit signal when tween finishes to notify player of bounds change
	tween.finished.connect(func(): camera_bounds_changed.emit())

func toggle() -> void:
	"""Toggles the panel visibility with animation"""
	if panel_visible:
		slide_out()
	else:
		slide_in()