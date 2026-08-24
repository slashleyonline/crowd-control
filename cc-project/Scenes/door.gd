extends Node3D

@onready var anim_player = $AnimationPlayer

@onready var timer = null

var opened = false
var last_anim = null

@export var open_back = null
@export var open_front = null

func _ready():
	open_back = get_parent().get_node("OpenBack")
	open_front = get_parent().get_node("OpenFront")
	timer = get_parent().get_node("Timer")

func get_open_pos(position: Vector3):
	#returns the best position for the npc to approach the door and open from.
	var front_distance = open_front.global_position.distance_to(position)
	var back_distance = open_back.global_position.distance_to(position)
	
	if front_distance < back_distance:
		return open_front.global_position
	else:
		return open_back.global_position

# Called when the node enters the scene tree for the first time.
func interact(body):
	#when interacted, should open the door in the opposite direction.
	
	if !anim_player.is_playing():
		
		#get the position of the entity interacting with the door.
		#open in whichever direction the user is facing the door.
		
		var front = null
		#forward vector for the door
		var a = -self.get_transform().basis.x
		#vector between the door and the body.
		var b = (body.get_position() - self.get_position()).normalized()
		
		if body.name == "Player":
			print(rad_to_deg(acos(a.dot(b))))
		if acos(a.dot(b)) <= deg_to_rad(90):
			front = false
		else:
			front = true
		
		if !opened:
			opened = true
			timer.start()

			anim_player.play("OpenForward")
			last_anim = "OpenForward"
		else:
			opened = false
			anim_player.play_backwards(last_anim)
	#automatically close after some time.
	


func _on_timer_timeout() -> void:
	if opened:
		interact(self)
