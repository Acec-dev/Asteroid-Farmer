extends PathFollow3D

@onready var marker = $"../../Marker3D"

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	progress += delta
	
	$Camera3D.look_at(marker.global_position)
