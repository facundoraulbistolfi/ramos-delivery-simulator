@tool
extends Node3D
## Este nodo carga el mapa completo de Ramos Mejía como referencia visual
## ÚNICAMENTE cuando la escena se abre adentro del Editor de Godot.
## En runtime del juego real, se auto-elimina inmediatamente sin consumir memoria.

func _ready() -> void:
	if Engine.is_editor_hint():
		if get_child_count() == 0:
			var map_scene: PackedScene = load("res://scenes/ramos_mejia.tscn") as PackedScene
			if map_scene != null:
				var map_inst: Node = map_scene.instantiate()
				add_child(map_inst)
	else:
		queue_free()
