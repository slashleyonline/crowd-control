extends CharacterBody3D

#current goal: Move to any specified position on the navmesh

@onready var nav_agent = $NavigationAgent3D
func _ready():
	update_target_location(Vector3(20,0,0))
	pass

func update_target_location(target_location: Vector3):
	nav_agent.target_position = target_location
	pass

func _process(delta: float) -> void:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * 3
	
	velocity = new_velocity
	move_and_slide()
	
