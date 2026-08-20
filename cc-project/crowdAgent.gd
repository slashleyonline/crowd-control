extends CharacterBody3D

#with this, each state can handle its own update logic
class IdleState:
	func update(agent):
		var new_velocity= Vector3.ZERO

		agent.randomize_target_location()

		if !agent.nav_agent.is_navigation_finished():
			agent.state  = agent.walking_state

		return new_velocity  

class WalkingState:
	func update(agent):
		var current_location = agent.global_transform.origin
		var next_location = agent.nav_agent.get_next_path_position()
		var new_velocity = (next_location  - current_location).normalized() * 10

		if agent.nav_agent.is_navigation_finished():
			agent.state = agent.idle_state
			new_velocity = Vector3.ZERO

		return new_velocity

#starts in the idle state
var idle_state = IdleState.new()
var walking_state = WalkingState.new()
var state=idle_state

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

	var new_velocity=state.update(self)
	# we only need one line now
	
	if !is_on_floor():
		new_velocity.y -= 9.31
	velocity = new_velocity
	
	move_and_slide()
