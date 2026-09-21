class_name CharacterView
extends AnimatedSprite2D

@export var masks: Dictionary[StringName, Texture2D] = {}

func sync(character: Dictionary) -> void:
	position = Map.to_pixel_continuous(character["cell"])
	(material as ShaderMaterial).set_shader_parameter("color", character["color"])
	if character["is_trapped"]:
		_play("bubble")
		return
	match character["facing"]:
		Vector2i.UP:
			_play("walk_up")
		Vector2i.DOWN:
			_play("walk_down")
		Vector2i.LEFT:
			_play("walk_side")
			flip_h = true
		Vector2i.RIGHT:
			_play("walk_side")
			flip_h = false

func _play(anim: StringName) -> void:
	play(anim)
	(material as ShaderMaterial).set_shader_parameter("mask_texture", masks.get(anim))
