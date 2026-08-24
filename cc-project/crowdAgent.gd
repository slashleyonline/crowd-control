extends CharacterBody3D

#with this, each state can handle its own update logic
class IdleState:
	func update(agent):
		#stand still and count the wait down. only when it runs out do we
		#pick a new destination, so we ask for one path instead of one per frame.
		agent.idle_timer -= agent.get_physics_process_delta_time()

		if agent.idle_timer <= 0.0:
			agent.randomize_target_location()
			agent.state = agent.walking_state

		return Vector3.ZERO

class WalkingState:
	func update(agent):
		if agent.nav_agent.is_navigation_finished():
			agent.start_idle()
			return Vector3.ZERO

		#if we are barely moving we are probably jammed against someone.
		#give up on this destination rather than pushing forever.
		if agent.is_stuck():
			agent.randomize_target_location()

		var next_location = agent.nav_agent.get_next_path_position()
		var direction = next_location - agent.global_position

		#the path sits on the navmesh, which is below the agent's centre.
		#flattening y stops that downward slope from stealing horizontal
		#speed and from fighting the floor collision.
		direction.y = 0

		return direction.normalized() * agent.speed 

class FrozenState:
	#stand still while the gun is on us. when the timer runs out we flee,
	#matching the readme: freeze briefly when threatened, then run.
	func update(agent):
		agent.freeze_timer -= agent.get_physics_process_delta_time()

		if agent.freeze_timer <= 0.0:
			#no gunshot position here, so pick any far nav point and run
			agent.randomize_target_location()
			agent.state = agent.fleeing_state

		return Vector3.ZERO

class FleeingState:
	#set position of event that  NPC is fleeing from. 
	var position = null
	func update(agent):
		if agent.nav_agent.is_navigation_finished():
			agent.start_idle()
			return Vector3.ZERO

		#if we are barely moving we are probably jammed against someone.
		#give up on this destination rather than pushing forever.
		if agent.is_stuck():
			agent.randomize_target_location()

		var next_location = agent.nav_agent.get_next_path_position()
		var direction = next_location - agent.global_position

		#if an event that is meant to scare the agent occurs, transition to the fear state.

		#the path sits on the navmesh, which is below the agent's centre.
		#flattening y stops that downward slope from stealing horizontal
		#speed and from fighting the floor collision.
		direction.y = 0
		var final_speed = agent.speed * 30000
		print(final_speed)
		return direction.normalized() * final_speed

class ReturnState:
	pass
#starts in the idle state
var idle_state = IdleState.new()
var walking_state = WalkingState.new()
var frozen_state = FrozenState.new()
var fleeing_state = FleeingState.new()
var returning_state
var state=idle_state

#constant value for the distance an NPC should have from the player while in the fleeing state.

#every npc rolls its own speed and wait times in _ready so the crowd
#does not walk like one organism. tune the ranges in the inspector.
@export var min_speed = 2.5
@export var max_speed = 4.0
@export var min_idle_time = 0.5
@export var max_idle_time = 3.0

#how much room an npc tries to keep around itself. the body itself is
#0.5 wide, so anything above that leaves a gap between people.
@export var avoidance_radius = 0.7

#how long an npc pushes against something before choosing a new destination
@export var stuck_give_up_time = 2.0

#how long an aimed-at npc freezes before switching to fleeing
@export var freeze_duration = 0.8

#this npc's own rolled values
var speed = 3.0
var idle_timer = 0.0
var freeze_timer = 0.0

#true while the player's gun is pointed at this npc. set by the player,
#read by the fsm - a FrozenState can just check this in its update().
var is_aimed_at = false

#used by is_stuck() to notice when we have stopped making progress
var stuck_timer = 0.0
var last_position = Vector3.ZERO

#avoidance only starts once the navigation map exists
var navigation_ready = false

@onready var nav_agent = $NavigationAgent3D

func _ready():
	#lets the player's aim raycast tell npcs apart from walls and floors
	add_to_group("npc")

	speed = randf_range(min_speed, max_speed)
	last_position = global_position

	#hold still until navigation is ready below, otherwise the idle state
	#would ask for a path before the map exists
	idle_timer = INF

	await wait_for_navigation()

	setup_avoidance()

	#a random first wait staggers the crowd so they do not all set off
	#on the same frame
	idle_timer = randf_range(0.0, max_idle_time)
	randomize_target_location()
	navigation_ready = true


#the navigation map is not usable on the very first frame, so we have to wait
#before asking it for a path. we used to wait for NavigationServer3D.map_changed
#(see https://github.com/godotengine/godot/issues/112652) but that only works
#for pedestrians already in the scene: one spawned later finds the map already
#built, so the signal never fires again and it would wait forever. checking the
#map directly works for both.
func wait_for_navigation():
	while true:
		var map = nav_agent.get_navigation_map()
		if map.is_valid() and NavigationServer3D.map_get_regions(map).size() > 0:
			#one more frame so the map has finished syncing before we use it
			await get_tree().physics_frame
			return
		await get_tree().physics_frame


#let the navigation server steer this npc around its neighbours.
#done in code so the scene file does not need editing on every pedestrian.
func setup_avoidance():
	nav_agent.avoidance_enabled = true
	nav_agent.radius = avoidance_radius
	nav_agent.max_speed = speed

	#only consider npcs that are actually close. the default is 50m, which
	#is the whole map, so every agent would weigh every other agent.
	nav_agent.neighbor_distance = 6.0
	nav_agent.max_neighbors = 8

	nav_agent.velocity_computed.connect(_on_velocity_computed)


func update_target_location(target_location: Vector3):
	nav_agent.target_position = target_location

func randomize_target_location():
	var map = nav_agent.get_navigation_map()
	update_target_location(NavigationServer3D.map_get_random_point(map, 1, true))

func random_target_location_outside_radius(position, radius):
	#given a position and radius, find an area on the map outside of it.
	
	var map = nav_agent.get_navigation_map()
	var target_location = position
	
	while (target_location.distance_to(position) >= radius):
		update_target_location(NavigationServer3D.map_get_random_point(map, 1, true))

#called by the player when its aim ray enters or leaves this npc.
#only called when the target changes, not every frame.
func set_aimed_at(aimed: bool):
	is_aimed_at = aimed
	#if the gun just landed on us and we are not already reacting, freeze
	if aimed and state != frozen_state and state != fleeing_state:
		start_frozen()

#stand still for a random moment before walking somewhere new
func start_idle():
	idle_timer = randf_range(min_idle_time, max_idle_time)
	state = idle_state

#lock up briefly when the player aims at this npc, then flee
func start_frozen():
	freeze_timer = freeze_duration
	state = frozen_state

#true once we have spent stuck_give_up_time hardly moving while walking
func is_stuck() -> bool:
	var moved = global_position.distance_to(last_position)
	last_position = global_position

	if moved < 0.02:
		stuck_timer += get_physics_process_delta_time()
	else:
		stuck_timer = 0.0

	if stuck_timer >= stuck_give_up_time:
		stuck_timer = 0.0
		return true
	return false

func fear_response(position, loudness):
	#called when the CrowdEvent for explosions or gunshots fires a signal.
	#depending on the position andd radius, pedestrian must switch to a fear state.
	if self.global_position.distance_to(position) <= loudness:
		random_target_location_outside_radius(position, loudness)
		state = fleeing_state

func _physics_process(_delta: float) -> void:

	var new_velocity=state.update(self)

	#hand the velocity we want to the navigation server. it adjusts it to
	#dodge nearby agents and hands it back through velocity_computed.
	if navigation_ready:
		nav_agent.set_velocity(new_velocity)
	else:
		apply_velocity(new_velocity)


#the navigation server's answer: our velocity, adjusted to miss the neighbours
func _on_velocity_computed(safe_velocity: Vector3):
	apply_velocity(safe_velocity)


func apply_velocity(new_velocity: Vector3):
	#gravity builds up over time, so add to the fall speed we already
	#have instead of replacing it with a fixed value
	if !is_on_floor():
		new_velocity.y = velocity.y + get_gravity().y * get_physics_process_delta_time()
	velocity = new_velocity

	move_and_slide()
