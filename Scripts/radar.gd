extends Camera2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	make_current()

	# Automatically set camera limits to match the viewport size
	# This ensures player bounds work correctly whether in SubViewport or standalone
	var viewport_size = get_viewport().get_visible_rect().size
	limit_left = 0
	limit_top = 0
	limit_right = int(viewport_size.x)
	limit_bottom = int(viewport_size.y)


func _on_radar_button_pressed() -> void:
	# zoom.x -= 0.25
	# zoom.y -= 0.25
	GameState.upgrade_system("radar", "zoom_level")
