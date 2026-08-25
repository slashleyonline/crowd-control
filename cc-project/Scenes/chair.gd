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

	#a pedestrian's AnimationPlayer lives under PedBase, not at its root, so
	#get_node("AnimationPlayer") threw and aborted the rest of this function.
	#that left the chair marked occupied forever and the npc stuck walking to
	#it. get_node_or_null also keeps this safe for anything without one.
	var anim_player = body.get_node_or_null("PedBase/AnimationPlayer")
	if anim_player != null:
		anim_player.play("Sit")
		#removed: var mesh = get_node("PedBase") - looked for PedBase on the
		#chair rather than the pedestrian, and the result was never used
		#look_at aims the body's -Z fully at the target in 3D, so a target at a
		#different height pitches the whole body over. this chair sits below a
		#pedestrian, which tipped them forward, and the tilt stayed with them
		#after they stood up again. flatten the target to our own height first.
		var face_point = self.global_position + global_basis.x
		face_point.y = body.global_position.y
		body.look_at(face_point)
		chair_sat.emit(self)
	#when interacted, should make the body play an animation and sit in the chair.
	
	#automatically close after some time.

func check_sitting():
	return sitting_body != null
