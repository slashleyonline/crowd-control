extends Node

class WalkingState:
	func update(agent):
		var current_location = agent.global_transform.origin
		var next_location = agent.nav_agent.get_next_path_position()
		var new_velocity = (next_location  - current_location).normalized() * 10

		if agent.nav_agent.is_navigation_finished():
			agent.state = agent.idle_state
			new_velocity = Vector3.ZERO

		return new_velocity
