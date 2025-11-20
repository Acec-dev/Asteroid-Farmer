extends Node2D

@onready var purchased_silo = false
@onready var purchased_drill = false
@onready var base_sprite = $BaseSprite
@onready var camera = $Camera2D
@onready var drill_timer = $DrillTimer
@onready var fuel_capacity = 0


func _ready() -> void:
	pass

func _on_silo_button_pressed() -> void:
	if purchased_drill == true:
		base_sprite.texture = load("res://Assets/complete planet.png")
	else:
		base_sprite.texture = load("res://Assets/planet+fuel.png")
	purchased_silo = true


func _on_drill_button_pressed() -> void:
	if purchased_silo == true:
		base_sprite.texture = load("res://Assets/complete planet.png")
	else:
		base_sprite.texture = load("res://Assets/planet+drill.png")
	purchased_drill = true
	drill_timer.start()
	
	

func _on_drill_timer_timeout() -> void:
	if fuel_capacity < 100:
		fuel_capacity += 1
		print("Fuel at " + fuel_capacity + "%")


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
