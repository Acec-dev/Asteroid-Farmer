extends Node2D

@export var radius: float = 28.0
@export var segments: int = 14

var _poly: PackedVector2Array

func _ready() -> void:
	_poly = PackedVector2Array()
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		var r := radius * randf_range(0.85, 1.15)
		_poly.append(Vector2.RIGHT.rotated(ang) * r)
	# Close the loop
	_poly.append(_poly[0])
	queue_redraw()
		#scale = Vector2(0.5, 0.5)

func _draw() -> void:
	# White irregular outline (same as before)
	draw_polyline(_poly, Color.WHITE, 2.0)
