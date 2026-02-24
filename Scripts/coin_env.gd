extends Node3D

@export var coin_scene: PackedScene
@export var spawn_height: float = 5.0

@onready var camera = get_viewport().get_camera_3d()

var next_x: float = -6.0

func _input(event):
    # Space - spawn coins 1m apart along X
    if event.is_action_pressed("ui_accept"):
        spawn_coin(Vector3(next_x, spawn_height, 0))
        next_x += 1.0
        if next_x > 6.0:
            next_x = -6.0

    # Q - spawn at cursor X with fixed Z depth
    if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
        var mouse_pos = get_viewport().get_mouse_position()
        var ray_origin = camera.project_ray_origin(mouse_pos)
        var ray_dir = camera.project_ray_normal(mouse_pos)

        var t = -ray_origin.z / ray_dir.z
        var world_x = (ray_origin + ray_dir * t).x

        spawn_coin(Vector3(world_x, spawn_height, 0))

func spawn_coin(pos: Vector3):
    var coin = coin_scene.instantiate()
    add_child(coin)
    coin.global_position = pos
    coin.linear_damp = 0.5
    coin.angular_damp = 1.0
    coin.mass = 2.0
    coin.continuous_cd = true