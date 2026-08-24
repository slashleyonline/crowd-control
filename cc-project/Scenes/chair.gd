extends StaticBody3D

@onready var sitting_body

# Called when the node enters the scene tree for the first time.
func interact(body):
	if sitting_body != null and body != sitting_body:
		return
	elif sitting_body != null and body == sitting_body:
		sitting_body =null
	
	if body.get_node("AnimationPlayer") != null:
		var anim_player = body.get_node("AnimationPlayer")
		anim_player.play("Sit")
		
	#when interacted, should make the body play an animation and sit in the chair.
	
	#automatically close after some time.
	

func _update():
	pass
