extends PanelContainer

# Animation settings
@export var slide_duration: float = 0.5
@export var start_hidden: bool = true
@export var zoom_amount: float = 1.15  # How much to zoom out when panel is visible

var is_visible: bool = false
var original_anchor_left: float
var original_anchor_right: float
var original_anchor_top: float
var tween: Tween

# Camera references
var radar_camera: Camera2D
var original_camera_limit_bottom: int
var original_camera_zoom: Vector2
var reduced_camera_limit_bottom: int

func _ready() -> void:
	# Store the original anchor positions from the scene
	original_anchor_left = anchor_left
	original_anchor_right = anchor_right
	original_anchor_top = anchor_top

	# Get reference to the Radar camera (GraphsPanel is under CanvasLayer, Radar is sibling to CanvasLayer)
	radar_camera = get_node("../../Radar") if has_node("../../Radar") else null

	# If we found the camera, store its original values
	if radar_camera:
		original_camera_limit_bottom = radar_camera.limit_bottom
		original_camera_zoom = radar_camera.zoom

		# Calculate where the panel will be when visible
		var viewport_height = get_viewport_rect().size.y
		reduced_camera_limit_bottom = int(viewport_height * original_anchor_top)

	# Start hidden if configured (moved off-screen to the left)
	if start_hidden:
		# Move the panel completely off-screen to the left
		var offset = anchor_right - anchor_left  # Width in anchor units
		anchor_left = -offset
		anchor_right = 0.0
		is_visible = false

func slide_in() -> void:
	"""Slides the panel in from left to right"""
	if is_visible:
		return

	is_visible = true

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
		# Zoom out slightly to give the effect that the screen shrank
		tween.tween_property(radar_camera, "zoom", original_camera_zoom / zoom_amount, slide_duration)

func slide_out() -> void:
	"""Slides the panel out from right to left"""
	if not is_visible:
		return

	is_visible = false

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
		# Zoom back in to original zoom level
		tween.tween_property(radar_camera, "zoom", original_camera_zoom, slide_duration)

func toggle() -> void:
	"""Toggles the panel visibility with animation"""
	if is_visible:
		slide_out()
	else:
		slide_in()