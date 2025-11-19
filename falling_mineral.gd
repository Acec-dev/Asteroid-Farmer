extends Area2D
class_name FallingMineral

## Mineral dropped by player that falls into deposit box

@export var kind: GameState.MineralType = GameState.MineralType.IRON
@export var fall_speed: float = 200.0
@export var fall_gravity: float = 400.0  # Renamed to avoid conflict with Area2D.gravity
@export var lifetime: float = 5.0  # Auto-delete if not collected

var _velocity: Vector2 = Vector2.ZERO
var _life_remaining: float = 5.0

# Colors matching the deposit box
const MINERAL_COLORS = {
	GameState.MineralType.IRON: Color(0.7, 0.7, 0.7),
	GameState.MineralType.NICKEL: Color(0.9, 0.9, 0.6),
	GameState.MineralType.SILICA: Color(0.6, 0.8, 1.0),
}

func _ready() -> void:
	add_to_group("falling_mineral")
	_life_remaining = lifetime

	# Small collision shape
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 4.0
	collision.shape = circle
	add_child(collision)

func _process(delta: float) -> void:
	# Apply gravity
	_velocity.y += fall_gravity * delta

	# Move
	global_position += _velocity * delta

	# Lifetime management
	_life_remaining -= delta
	if _life_remaining <= 0:
		queue_free()

func set_initial_velocity(vel: Vector2) -> void:
	"""Set initial velocity (e.g., inherit some player velocity)"""
	_velocity = vel

func _draw() -> void:
	# Draw diamond shape (same as regular minerals)
	var s := 4.0
	var pts = PackedVector2Array([
		Vector2(0, -s),
		Vector2(s, 0),
		Vector2(0, s),
		Vector2(-s, 0),
		Vector2(0, -s)
	])

	var color = MINERAL_COLORS.get(kind, Color.WHITE)
	draw_polyline(pts, color, 1.5)
