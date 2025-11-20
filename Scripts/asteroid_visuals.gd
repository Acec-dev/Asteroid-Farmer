extends Node2D

@export var radius: float = 28.0
@export var segments: int = 14

var _poly: PackedVector2Array

func _ready() -> void:
	_generate_shape()

func set_radius(new_radius: float) -> void:
	"""Update the asteroid's visual size"""
	radius = new_radius
	_generate_shape()
	queue_redraw()

func _generate_shape() -> void:
	"""Generate the irregular asteroid shape"""
	_poly = PackedVector2Array()
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		var r := radius * randf_range(0.85, 1.15)
		_poly.append(Vector2.RIGHT.rotated(ang) * r)
	# Close the loop
	_poly.append(_poly[0])
	queue_redraw()

func _draw() -> void:
	# White irregular outline
	draw_polyline(_poly, Color.WHITE, 2.0)
