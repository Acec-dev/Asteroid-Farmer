@tool
extends Node

@export var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		if my_sprite:
			my_sprite.texture = sprite_texture
			
var my_sprite: Sprite2D

func _init():
	if Engine.is_editor_hint():
		my_sprite = Sprite2D.new()
		add_child(my_sprite)
		my_sprite.position = Vector2(50, 50)
		
func _ready():
	if Engine.is_editor_hint():
		if sprite_texture:
			my_sprite.texture = sprite_texture
