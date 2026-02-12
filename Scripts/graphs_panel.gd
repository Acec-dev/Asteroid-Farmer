extends PanelContainer

# Signal emitted when panel animation finishes
signal camera_bounds_changed()

# Animation settings
@export var slide_duration: float = 0.5
@export var start_hidden: bool = true

var panel_visible: bool = false
var original_anchor_left: float
var original_anchor_right: float
var original_anchor_top: float
var tween: Tween

func _ready() -> void:
	# Add to group so other nodes can find us
	add_to_group("graphs_panel")

	# Store the original anchor positions from the scene
	original_anchor_left = anchor_left
	original_anchor_right = anchor_right
	original_anchor_top = anchor_top

	# Start hidden (off-screen to the left)
	if start_hidden:
		var offset = anchor_right - anchor_left
		anchor_left = -offset
		anchor_right = 0.0
		panel_visible = false

func slide_in() -> void:
	if panel_visible:
		return

	panel_visible = true

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)

	tween.tween_property(self, "anchor_left", original_anchor_left, slide_duration)
	tween.tween_property(self, "anchor_right", original_anchor_right, slide_duration)

	tween.finished.connect(func(): camera_bounds_changed.emit())

func slide_out() -> void:
	if not panel_visible:
		return

	panel_visible = false

	var offset = original_anchor_right - original_anchor_left

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)

	tween.tween_property(self, "anchor_left", -offset, slide_duration)
	tween.tween_property(self, "anchor_right", 0.0, slide_duration)

	tween.finished.connect(func(): camera_bounds_changed.emit())

func toggle() -> void:
	if panel_visible:
		slide_out()
	else:
		slide_in()
