extends PanelContainer

# Animation settings
@export var slide_duration: float = 0.5
@export var start_hidden: bool = true
@export var zoom_amount: float = 1.15  # How much to zoom out when panel is visible

var panel_visible: bool = false
var original_anchor_left: float
var original_anchor_right: float
var original_anchor_top: float
var tween: Tween

# Component references
var radar_camera: Camera2D
var radar_component: Node  # RadarComponent that controls zoom
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

	# Find the RadarComponent (it's attached to the player)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		radar_component = player.find_child("RadarComponent")
		if radar_component:
			print("GraphsPanel: Found RadarComponent")

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
	# When panel opens, we lose panel_height_pixels at the bottom
	# So we need to expand upward by the same amount to compensate
	ScreenUtils.adjust_boundaries(
		-panel_height_pixels,  # top_inset: negative = move UP (in Godot Y coords)
		panel_height_pixels,   # bottom_inset: move bottom boundary UP by panel height
		0, 0,                  # left/right: no change
		slide_duration
	)

	# Animate radar component zoom multiplier if available
	if radar_component:
		# Increase the multiplier to zoom out (higher multiplier = more zoom out)
		tween.tween_property(radar_component, "zoom_multiplier", zoom_amount, slide_duration)

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

	# Restore radar component zoom multiplier if available
	if radar_component:
		# Reset multiplier back to 1.0 (normal zoom)
		tween.tween_property(radar_component, "zoom_multiplier", 1.0, slide_duration)

func toggle() -> void:
	"""Toggles the panel visibility with animation"""
	if panel_visible:
		slide_out()
	else:
		slide_in()