# FILE: res://scripts/Projectile.gd
extends Area2D

@export var speed: float = 1000.0
@export var lifetime: float = 1.0

var _age: float = 0.0


func _ready() -> void:
	# Visual: simple white line bullet
	queue_redraw()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	draw_line(Vector2(-2, 0), Vector2(6, 0), Color.WHITE, 2.0)


func configure_speed(new_speed: float) -> void:
	speed = new_speed


func _on_area_entered(a: Area2D) -> void:
	if a.has_method("hit_by_projectile"):
		a.hit_by_projectile(self)
		queue_free()


func _on_body_entered(b: Node) -> void:
	if b.has_method("hit_by_projectile"):
		b.hit_by_projectile(self)
		queue_free()
