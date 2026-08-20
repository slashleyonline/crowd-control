extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
func _ready():
	update_target_location(Vector3(20,0,0))

func update_target_location(target_location: Vector3):
	nav_agent.target_position = target_location

func _process(delta: float) -> void:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * 3
	
	new_velocity.y -= 9.31
	velocity = new_velocity
	
	move_and_slide()
