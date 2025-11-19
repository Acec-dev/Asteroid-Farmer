extends CharacterBody2D
class_name Minion

## Minion character that waddles around the base
## Uses AnimatedSprite2D for animations (to be added)

# Movement parameters
@export var waddle_speed: float = 50.0  # Speed of waddling movement
@export var waddle_distance: float = 100.0  # How far to waddle before turning around
@export var direction_change_time: float = 3.0  # Time between direction changes (seconds)

# Animation states - add your animation names here
enum AnimState {
	IDLE,
	WALK_LEFT,
	WALK_RIGHT,
}

# Internal state
var current_anim_state: AnimState = AnimState.IDLE
var movement_direction: int = 1  # 1 for right, -1 for left
var spawn_position: Vector2 = Vector2.ZERO
var time_since_direction_change: float = 0.0
var is_active: bool = true

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Store initial spawn position
	spawn_position = global_position

	# Randomize initial direction
	movement_direction = 1 if randf() > 0.5 else -1

	# Randomize starting time offset so minions don't all sync up
	time_since_direction_change = randf_range(0.0, direction_change_time)

	print("Minion spawned at position: ", spawn_position)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Update direction change timer
	time_since_direction_change += delta

	# Check if we should change direction
	if time_since_direction_change >= direction_change_time:
		change_direction()
		time_since_direction_change = 0.0

	# Check if we've wandered too far from spawn point
	var distance_from_spawn = global_position.distance_to(spawn_position)
	if distance_from_spawn > waddle_distance:
		# Turn around if we've gone too far
		face_spawn_point()

	# Apply waddling movement
	waddle_move(delta)

	# Update animation based on movement
	update_animation()


func waddle_move(delta: float) -> void:
	"""Apply side-to-side waddling movement"""
	# Set horizontal velocity
	velocity.x = movement_direction * waddle_speed
	velocity.y = 0  # No vertical movement for now

	# Apply movement
	move_and_slide()


func change_direction() -> void:
	"""Change the waddle direction"""
	movement_direction *= -1
	print("Minion changing direction to: ", "right" if movement_direction > 0 else "left")


func face_spawn_point() -> void:
	"""Turn minion towards spawn point when it wanders too far"""
	var direction_to_spawn = spawn_position - global_position
	if direction_to_spawn.x > 0:
		movement_direction = 1  # Move right
	else:
		movement_direction = -1  # Move left

	time_since_direction_change = 0.0


func update_animation() -> void:
	"""Update the animation state based on current movement"""
	# Determine what animation should be playing
	var new_state: AnimState

	if abs(velocity.x) < 1.0:
		new_state = AnimState.IDLE
	elif movement_direction > 0:
		new_state = AnimState.WALK_RIGHT
	else:
		new_state = AnimState.WALK_LEFT

	# Only change animation if state has changed
	if new_state != current_anim_state:
		current_anim_state = new_state
		play_animation_for_state(current_anim_state)


func play_animation_for_state(state: AnimState) -> void:
	"""Play the appropriate animation for the given state"""
	if not animated_sprite:
		return

	# TODO: Add your animation names here once you've created them in AnimatedSprite2D
	match state:
		AnimState.IDLE:
			# animated_sprite.play("idle")
			# Flip sprite to face the direction
			animated_sprite.flip_h = movement_direction < 0
			pass
		AnimState.WALK_LEFT:
			# animated_sprite.play("walk")
			animated_sprite.flip_h = true
			pass
		AnimState.WALK_RIGHT:
			# animated_sprite.play("walk")
			animated_sprite.flip_h = false
			pass


## Public interface methods

func setup(spawn_pos: Vector2) -> void:
	"""Initialize minion at a specific position"""
	global_position = spawn_pos
	spawn_position = spawn_pos


func stop() -> void:
	"""Stop the minion from moving"""
	is_active = false
	velocity = Vector2.ZERO
	current_anim_state = AnimState.IDLE
	if animated_sprite:
		# animated_sprite.play("idle")
		pass


func resume() -> void:
	"""Resume minion movement"""
	is_active = true


func hit_by_projectile(projectile: Node) -> void:
	"""Called when minion is hit by a projectile (for future use)"""
	# TODO: Add damage handling, death animation, etc.
	print("Minion hit by projectile: ", projectile)
	pass


## Debug/Visual feedback (optional - remove once you have sprites)
func _draw() -> void:
	"""Temporary visual representation until sprites are added"""
	# Draw a simple colored circle to represent the minion
	draw_circle(Vector2.ZERO, 15, Color.YELLOW)
	# Draw eyes
	draw_circle(Vector2(-5, -5), 3, Color.BLACK)
	draw_circle(Vector2(5, -5), 3, Color.BLACK)
	# Draw direction indicator
	var direction_indicator = Vector2(movement_direction * 10, 5)
	draw_line(Vector2.ZERO, direction_indicator, Color.RED, 2.0)
