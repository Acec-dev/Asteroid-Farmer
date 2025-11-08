extends Control

@onready var restart_button = get_node("VBoxContainer/RestartButton")

func _ready() -> void:
	restart_button.visible = false
	await get_tree().create_timer(2.0).timeout
	restart_button.visible = true


func _on_button_pressed() -> void:
	
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
