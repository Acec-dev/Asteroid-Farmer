# res://Scripts/floating_text_2D.gd
extends Node2D

@onready var label := $Label
@onready var position_displacement = 0.0

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	position.y += -50 * delta
	position_displacement += -50 * delta

	
func show_text(kind, start):
	label.text = "+1 " + kind.to_lower()
	global_position = start


func _on_timer_timeout() -> void:
	queue_free()
