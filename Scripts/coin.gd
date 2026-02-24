extends RigidBody3D

var settle_timer: float = 0.0
var settle_threshold: float = 0.05
var settle_time_required: float = 0.5

func _ready():
    linear_damp = 2.0
    angular_damp = 4.0
    mass = 1.0
    continuous_cd = true
    gravity_scale = 1.0
    can_sleep = true

func _physics_process(delta):
    if freeze:
        return  # already frozen, skip

    if linear_velocity.length() < settle_threshold and angular_velocity.length() < settle_threshold:
        settle_timer += delta
        if settle_timer >= settle_time_required:
            freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
            freeze = true
    else:
        settle_timer = 0.0