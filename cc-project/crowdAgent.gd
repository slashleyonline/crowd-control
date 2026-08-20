extends CharacterBody3D

enum States {IDLE, WALKING, FROZEN, FLEEING, RETURNING}
var state = States.IDLE

#higher than usual for testing purposes. should be 3.
const SPEED = 10

@onready var nav_agent = $NavigationAgent3D

func _ready():
	#must be called twice due to the nature of NavigationServer3D.
	#Source: https://github.com/godotengine/godot/issues/112652
	await NavigationServer3D.map_changed
	await NavigationServer3D.map_changed
	randomize_target_location()


func update_target_location(target_location: Vector3):
	nav_agent.target_position = target_location

func randomize_target_location():
	var map = nav_agent.get_navigation_map()
	update_target_location(NavigationServer3D.map_get_random_point(map, 1, true))

func _process(delta: float) -> void:
	var new_velocity = Vector3.ZERO
	if state == States.IDLE:
		#Beginning state. Nothing should really happen 
		#and agent should stand still
		randomize_target_location()
		if !nav_agent.is_navigation_finished():
			state = States.WALKING
	elif state == States.WALKING:
		var current_location = global_transform.origin
		var next_location = nav_agent.get_next_path_position()
		new_velocity = (next_location - current_location).normalized() * 10
		if nav_agent.is_navigation_finished():
			state = States.IDLE
			new_velocity = Vector3.ZERO
	
	if !is_on_floor():
		new_velocity.y -= 9.31
	velocity = new_velocity
	
	move_and_slide()
