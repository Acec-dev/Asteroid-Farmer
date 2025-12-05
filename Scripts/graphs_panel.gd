extends PanelContainer

# Animation settings
@export var slide_duration: float = 0.5
@export var start_hidden: bool = true
@export var zoom_amount: float = 0.75  # Zoom OUT when panel opens (< 1.0 = zoom out)

var panel_visible: bool = false
var original_anchor_left: float
var original_anchor_right: float
var original_anchor_top: float
var tween: Tween

# Component references
var radar_camera: Camera2D
var panel_height_pixels: int = 0  # How many pixels the panel takes up

func _ready() -> void:
	# Store the original anchor positions from the scene
	original_anchor_left = anchor_left
	original_anchor_right = anchor_right
	original_anchor_top = anchor_top

	# Get reference to the Radar camera for ScreenUtils initialization
	radar_camera = get_node("../../Radar") if has_node("../../Radar") else null

	# Initialize ScreenUtils with the camera
	if radar_camera:
		ScreenUtils.set_main_camera(radar_camera)

	# Calculate how much screen space the panel takes when visible
	if radar_camera:
		var viewport_height = get_viewport_rect().size.y
		# Panel starts at original_anchor_top (e.g., 0.72 = 72% down)
		# So it takes up the remaining portion (e.g., 28% = 300 pixels if viewport is 1080)
		panel_height_pixels = int(viewport_height * (1.0 - original_anchor_top))
		print("GraphsPanel: Panel will take ", panel_height_pixels, " pixels when open")

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

	# Adjust world boundaries through ScreenUtils
	# Only adjust the bottom boundary to prevent flying behind the panel
	# Don't restrict the top - let the zoom handle showing the same play area
	ScreenUtils.adjust_boundaries(
		0,                     # top_inset: no change to top boundary
		panel_height_pixels,   # bottom_inset: move bottom boundary UP to panel edge
		0, 0,                  # left/right: no change
		slide_duration
	)

	# Zoom the camera directly (both X and Y together)
	if radar_camera:
		var zoom_vector = Vector2(zoom_amount, zoom_amount)  # e.g., (0.75, 0.75)
		tween.tween_property(radar_camera, "zoom", zoom_vector, slide_duration)
		print("GraphsPanel: Zooming camera to ", zoom_vector)

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

	# Restore world boundaries through ScreenUtils
	ScreenUtils.restore_boundaries(slide_duration)

	# Restore camera zoom to normal (1.0, 1.0)
	if radar_camera:
		var zoom_vector = Vector2(1.0, 1.0)
		tween.tween_property(radar_camera, "zoom", zoom_vector, slide_duration)
		print("GraphsPanel: Restoring camera zoom to ", zoom_vector)

func toggle() -> void:
	"""Toggles the panel visibility with animation"""
	if panel_visible:
		slide_out()
	else:
		slide_in()