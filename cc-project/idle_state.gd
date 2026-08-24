extends Node

func update(agent):
	var new_velocity= Vector3.ZERO

	agent.randomize_target_location()

	if !agent.nav_agent.is_navigation_finished():
		agent.state  = agent.walking_state
	return new_velocity  
