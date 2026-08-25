extends StaticBody3D

var sitting_body = null

signal chair_sat

# Called when the node enters the scene tree for the first time.
func interact(body):
	if sitting_body != null and body != sitting_body:
		return
	elif sitting_body != null and body == sitting_body:
		sitting_body = null
	
	if body.is_in_group("npc"):
		sitting_body = body

	if body.get_node("AnimationPlayer") != null:
		var anim_player = body.get_node("AnimationPlayer")
		anim_player.play("Sit")
		var mesh = get_node("PedBase")
		body.look_at(self.global_position + global_basis.x)
		chair_sat.emit(self)
	#when interacted, should make the body play an animation and sit in the chair.
	
	#automatically close after some time.

func check_sitting():
	return sitting_body != null
