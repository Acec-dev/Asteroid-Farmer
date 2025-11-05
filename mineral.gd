extends Area2D

signal mineral_pickup

@export var value: int = 1
@export var drift: float = 40.0
var _life := 8.0

var minerals := ["iron", "nickel", "silica"]


@export var kind: StringName = minerals.pick_random()

func _get_kind():
	return kind

func _ready() -> void:
	add_to_group("mineral")
	
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)
	queue_redraw()

func _process(delta: float) -> void:
	position += Vector2(randf_range(-1,1), randf_range(-1,1)) * drift * delta
	_life -= delta
	if _life <= 0:
		queue_free()

func _draw() -> void:
	# Simple diamond glyph
	var s := 4.0
	var pts = [Vector2(0,-s), Vector2(s,0), Vector2(0,s), Vector2(-s,0), Vector2(0,-s)]
	draw_polyline(pts, Color.WHITE, 1.5)

func _collect() -> void:
	GameState.add_mat(kind)
	GameState.add_mineral(kind, value)
	queue_free()

func _on_area(a: Area2D) -> void:
	if a.is_in_group("player_pickup"):
		_collect()
		emit_signal("mineral_pickup")

func _on_body(_b: Node) -> void:
	# Not used, but kept for compatibility
	pass
