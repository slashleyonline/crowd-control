extends Node3D

@onready var anim_player = $AnimationPlayer

var opened = false

# Called when the node enters the scene tree for the first time.
func interact():
	#when interacted, should open the door in the opposite direction.
	if !opened:
		opened = true
		anim_player.play("Open")
	else:
		opened = false
		anim_player.play_backwards("Open")
	#automatically close after some time.
	pass
