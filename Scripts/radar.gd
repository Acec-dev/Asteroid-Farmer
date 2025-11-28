extends Camera2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	make_current()


func _on_radar_button_pressed() -> void:
	# zoom.x -= 0.25
	# zoom.y -= 0.25
	GameState.upgrade_system("radar", "zoom_level")
