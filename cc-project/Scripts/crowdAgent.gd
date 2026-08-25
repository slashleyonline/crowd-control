extends CharacterBody3D

#with this, each state can handle its own update logic
class IdleState:
	
	func update(agent):
		#stand still and count the wait down. only when it runs out do we
		#pick a new destination, so we ask for one path instead of one per frame.
		agent.idle_timer -= agent.get_physics_process_delta_time()

		#occasionally look at the player if they walk nearby
		if agent.try_start_stare():
			return Vector3.ZERO

		if agent.idle_timer <= 0.0:
			#random chance that agent seeks out a chair

			if (randf() <= 0.05):
				# set target location to a random chair on the map
				if agent.chairs:
					var idx= randi() % agent.chairs.size()
					var target_chair = agent.chairs[idx]

					#move to seeking chair state
					print(target_chair.global_position)
					agent.update_target_location(target_chair.global_position)
					agent.locate_chair_state.chair = target_chair
					agent.state = agent.locate_chair_state
					return Vector3.ZERO

			agent.randomize_target_location()
			agent.state = agent.walking_state

		return Vector3.ZERO

class StareState:
	#stand still and turn the body toward the player, then go back to idle.
	func update(agent):
		agent.stare_timer -= agent.get_physics_process_delta_time()

		var target = agent.stare_target
		if target == null or not is_instance_valid(target):
			agent.clear_head_look()
			agent.start_idle()
			return Vector3.ZERO

		#stop staring if the player walked out of range
		if agent.global_position.distance_to(target.global_position) > agent.stare_range:
			agent.clear_head_look()
			agent.start_idle()
			return Vector3.ZERO

		if agent.stare_timer <= 0.0:
			agent.stare_target = null
			agent.clear_head_look()
			agent.start_idle()

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

		#check if the pedestrian needs to open a door
		agent.check_door_interact()

		return direction.normalized() * agent.speed 

class MarchingState:
	#single file line. each npc follows whoever is directly in front of it
	#rather than a fixed offset from the leader, so the line bends around
	#corners instead of every slot swinging sideways when the leader turns.
	func update(agent):
		if not agent.march_is_valid():
			agent.march_leader = null
			agent.march_ahead = null
			agent.start_idle()
			return Vector3.ZERO

		var slot = agent.march_slot_position()

		#horizontal gap only, so a height difference does not read as lagging
		var to_slot = slot - agent.global_position
		to_slot.y = 0.0
		var gap = to_slot.length()

		#close enough. hold still rather than shuffling on the spot.
		if gap < agent.march_slot_tolerance:
			return Vector3.ZERO

		var direction: Vector3

		if gap <= agent.march_path_distance:
			#the slot is close and almost always in open floor right behind
			#someone, so walk straight at it. going through navigation here
			#makes the agent stop about a metre short, because that is when
			#NavigationAgent3D calls the trip finished.
			direction = to_slot
		else:
			#far enough that a wall could be in the way, so use a real path.
			#the slot moves every frame but re-pathing every frame is what
			#makes follow behaviour expensive, so only a few times a second.
			agent.march_repath_timer -= agent.get_physics_process_delta_time()
			if agent.march_repath_timer <= 0.0 or agent.is_stuck():
				agent.march_repath_timer = agent.march_repath_interval
				agent.update_target_location(slot)

			var next_location = agent.nav_agent.get_next_path_position()
			direction = next_location - agent.global_position
			direction.y = 0.0

		#marchers still open doors like everyone else
		agent.check_door_interact()

		#hurry a little when the line has stretched out, so it closes back up
		var march_speed = agent.speed
		if gap > agent.march_slot_tolerance * 3.0:
			march_speed = agent.speed * 1.4

		return direction.normalized() * march_speed

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
	var threat_position = null
	var radius = null
	
	func update(agent):
		agent.fleeing_timer -= agent.get_physics_process_delta_time()
		
		if threat_position == null:
			threat_position = agent.global_position
		if radius == null:
			radius = 50

		#vector pointing from the threat to npc
		var away_vector = threat_position - agent.global_position
		away_vector.y = 0
		var distance = away_vector.length()

		var is_safe = distance > radius
		
		if agent.nav_agent.is_navigation_finished() or agent.fleeing_timer <= 0.0:
			agent.fleeing_timer = randf_range(agent.min_fleeing_time, agent.max_fleeing_time)
			#reached a "safe" spot - cool down before normal crowd behavior
			#print('safe!')
			agent.start_returning()
			return Vector3.ZERO
		
		#if we are barely moving we are probably jammed against someone.
		#give up on this destination rather than pushing forever.
		if agent.is_stuck():
			agent.state = agent.frozen_state

		#vector pointing to the desired location
		var next_location = agent.nav_agent.get_next_path_position()
		var direction = (next_location - agent.global_position).normalized()
		direction.y = 0

		var steer_direction = direction

		#check if the pedestrian needs to open a door
		agent.check_door_interact()

		return steer_direction * agent.speed

class ReturnState:
	#after fleeing, wait out a short safety cooldown, then go back to idle.
	#walk calmly so the crowd does not all freeze in place after a scare.
	func update(agent):
		agent.return_timer -= agent.get_physics_process_delta_time()

		if agent.return_timer <= 0.0:
			agent.start_idle()
			return Vector3.ZERO

		if agent.nav_agent.is_navigation_finished():
			agent.randomize_target_location()
			return Vector3.ZERO

		if agent.is_stuck():
			agent.randomize_target_location()

		var next_location = agent.nav_agent.get_next_path_position()
		var direction = next_location - agent.global_position
		direction.y = 0

		#check if the pedestrian needs to open a door
		agent.check_door_interact()

		return direction.normalized() * agent.speed

class DoorState:
	#previous target location. needs to be set before moving to this state.
	var prev_target = null
	#previous state.
	var prev_state = null
	#door that is being opened.
	var door_body = null
	#opening position that the npc moves to
	var open_pos = null
	
	var move_to_pos_state = MoveToPosState.new()
	var open_door_state = OpenDoorState.new()
	
	var current_door_state = move_to_pos_state
	
	func update(agent):
		return current_door_state.update(agent)
	
	#move to the nearest opening position
	class MoveToPosState:
		func update(agent):
			if agent.nav_agent.is_navigation_finished():
				agent.door_state.current_door_state = agent.door_state.open_door_state
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
	#if the door is closed, open it. wait 1.5 seconds.
	class OpenDoorState:
		const waitTime = 1.5
		var time = 0
		func update(agent):
			var door_body = agent.door_state.door_body
			if !door_body.opened:
				door_body.interact(agent)
			
			time += agent.get_physics_process_delta_time()
			if time >= waitTime:
				agent.update_target_location(agent.door_state.prev_target)
				agent.state = agent.door_state.prev_state
			
			return Vector3.ZERO
			

class LocateChairState:
	#chair object to be located. needs to be set
	var chair = null

	func update(agent):
		if agent.global_position.distance_to(agent.nav_agent.target_location) < 4 \
			and !chair.check_sitting():
			print('found chair')
			agent.sitting_state.chair = chair
			chair.interact(agent)
			agent.state = agent.sitting_state
		elif chair.check_sitting():
			agent.state = agent.idle_state

		#if we are barely moving we are probably jammed against someone.
		#give up on this destination rather than pushing forever.
		if agent.is_stuck():
			agent.state = agent.idle_state

		var next_location = agent.nav_agent.get_next_path_position()
		var direction = next_location - agent.global_position

		#the path sits on the navmesh, which is below the agent's centre.
		#flattening y stops that downward slope from stealing horizontal
		#speed and from fighting the floor collision.
		direction.y = 0

		return direction.normalized() * agent.speed

class ChairSittingState:
	#check if player is in the proper position
	var npc_reoriented = false
	#chair object to be located. needs to be set
	var chair = null
	var timer = 0

	func update(agent):
		if !npc_reoriented:
			move_npc(agent, true)
		
		timer += agent.get_physics_process_delta_time()
		if timer > agent.sitting_timer:
			chair.interact(agent)
			agent.sitting_state.chair = null
			agent.state = agent.idle_state
			move_npc(agent, false)
			
			return Vector3.ZERO

		agent.anim_player.play("Sitting")
		agent.global_position = chair.global_position + Vector3(0,0,0)
		return Vector3.ZERO
	
	func move_npc(agent, status):
		var collision = agent.get_node("CollisionShape3D")
		collision.disabled = status
		if chair != null:
			agent.global_position = chair.global_position
		npc_reoriented = status

#starts in the idle state
var idle_state = IdleState.new()
var walking_state = WalkingState.new()
var frozen_state = FrozenState.new()
var fleeing_state = FleeingState.new()
var returning_state = ReturnState.new()
var door_state = DoorState.new()
var stare_state = StareState.new()
var marching_state = MarchingState.new()
var locate_chair_state = LocateChairState.new()
var sitting_state = ChairSittingState.new()
var state=idle_state

#constant value for the distance an NPC should have from the player while in the fleeing state.

#every npc rolls its own speed and wait times in _ready so the crowd
#does not walk like one organism. tune the ranges in the inspector.
@export var min_speed = 2.5
@export var max_speed = 4.0
@export var min_idle_time = 0.5
@export var max_idle_time = 3.0
@export var min_fleeing_time = 45.0
@export var max_fleeing_time = 75.0

#how much room an npc tries to keep around itself. the body itself is
#0.5 wide, so anything above that leaves a gap between people.
@export var avoidance_radius = 0.7

#how long an npc pushes against something before choosing a new destination
@export var stuck_give_up_time = 2.0

#how long an aimed-at npc freezes before switching to fleeing
@export var freeze_duration = 0.8

#how long after fleeing before an npc resumes normal idle/walk behavior
@export var return_cooldown = 2.0

#how long does the pedestrian sit for?
@export var sitting_timer = 30.0

#how close the player must be before an idle npc may stare
@export var stare_range = 8.0
#rough chance per second while idle and in range
@export var stare_chance_per_second = 0.35
#how long they keep looking
@export var stare_duration_min = 1.5
@export var stare_duration_max = 3.5

#marching: how far apart people stand in the line
@export var march_spacing = 1.6
#how close to our slot counts as being in place
@export var march_slot_tolerance = 0.6
#seconds between path updates while following a moving slot
@export var march_repath_interval = 0.25
#slots nearer than this are steered at directly instead of pathfound. the
#navigation agent reports "arrived" about a metre out, which left followers
#parked just short of their slot.
@export var march_path_distance = 4.0

#this npc's own rolled values
var speed = 3.0
var idle_timer = 0.0
var fleeing_timer = 0.0
var freeze_timer = 0.0
var return_timer = 0.0
var stare_timer = 0.0
var stare_target = null

#marching line. followers hold a slot behind their leader; the leader itself
#has no leader of its own and behaves like any other npc.
var march_leader = null
#the npc directly in front of us in the line (the leader, for the first one)
var march_ahead = null
var march_slot = 0
var is_march_leader = false
var march_repath_timer = 0.0
#the leader's last travel direction, so followers know where "behind" is
var march_forward = Vector3(0, 0, -1)

#true while the player's gun is pointed at this npc. set by the player,
#read by the fsm - a FrozenState can just check this in its update().
var is_aimed_at = false

#used by is_stuck() to notice when we have stopped making progress
var stuck_timer = 0.0
var last_position = Vector3.ZERO

#avoidance only starts once the navigation map exists
var navigation_ready = false

#used only so we can print when the fsm changes (see Output in Godot)
var _debug_last_state = null

#chairs to be located
var chairs = null

@onready var nav_agent = $NavigationAgent3D
@onready var mesh = $PedBase
@onready var skeleton = $PedBase/Armature/Skeleton3D
@onready var interact_ray = $PedBase/InteractionRayCast
@onready var label = $Label3D
@onready var anim_player = $PedBase/AnimationPlayer

var neck_bone = -1
var head_bone = -1

func _ready():
	#lets the player's aim raycast tell npcs apart from walls and floors
	add_to_group("npc")

	#bone indices kept so we can reset if a look pose ever gets stuck
	neck_bone = skeleton.find_bone("Neck")
	head_bone = skeleton.find_bone("Head")

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
	fleeing_timer = randf_range(min_fleeing_time, max_fleeing_time)
	sitting_timer = randf_range(30.0, 120.0)
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
	var target_location = position
	randomize_target_location()
	
	var attempts = 0
	while (target_location.distance_to(position) <= radius and attempts < 30):
		attempts += 1
		randomize_target_location()

func flee_radius(position, radius):
	# Given a threat/reference position and radius, find a point on the map
	# that is both outside the radius AND roughly in the opposite direction
	# from the threat, relative to my current position.

	var flee_direction = (global_position - position).normalized()

	var target_location = position
	update_target_location(global_position + flee_direction * (radius * 1.5))

#called by the player when its aim ray enters or leaves this npc.
#only called when the target changes, not every frame.
func set_aimed_at(aimed: bool):
	is_aimed_at = aimed
	#if the gun just landed on us and we are not already reacting, freeze
	if aimed and state != frozen_state and state != fleeing_state:
		start_frozen()

#is the line we belong to still intact
func march_is_valid() -> bool:
	if march_ahead == null or not is_instance_valid(march_ahead):
		return false
	if march_leader == null or not is_instance_valid(march_leader):
		return false
	return true

#stand one spacing behind whoever is directly in front of us
func march_slot_position() -> Vector3:
	return march_ahead.global_position - march_ahead.march_forward * march_spacing

#put this npc into a marching line behind "ahead", led overall by "leader"
func join_march(leader, ahead, slot: int):
	march_leader = leader
	march_ahead = ahead
	march_slot = slot
	march_repath_timer = 0.0

	#the avoidance solver clamps whatever we hand it to max_speed, which would
	#cancel out the catch-up boost below. give followers the headroom.
	nav_agent.max_speed = speed * 1.5

	state = marching_state

#stand still for a random moment before walking somewhere new
func start_idle():
	#marchers rejoin their line instead of wandering off on their own. this is
	#what lets a group scatter from a gunshot and then re-form afterwards.
	if march_is_valid():
		state = marching_state
		return

	idle_timer = randf_range(min_idle_time, max_idle_time)
	state = idle_state

#lock up briefly when the player aims at this npc, then flee
func start_frozen():
	clear_head_look()
	freeze_timer = freeze_duration
	state = frozen_state

#cool down after fleeing before rejoining normal crowd movement
func start_returning():
	return_timer = return_cooldown
	randomize_target_location()
	state = returning_state

#roll whether an idle npc should look at the player this frame
func try_start_stare() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	if global_position.distance_to(player.global_position) > stare_range:
		return false

	var chance = stare_chance_per_second * get_physics_process_delta_time()
	if randf() > chance:
		return false

	start_stare(player)
	return true

func start_stare(target):
	stare_target = target
	stare_timer = randf_range(stare_duration_min, stare_duration_max)
	state = stare_state

#turn the whole body toward a world point (y rotation only)
func face_toward(world_pos: Vector3):
	var direction = world_pos - global_position
	direction.y = 0
	if direction.length_squared() < 0.0001:
		return
	mesh.rotation.y = rotate_toward(
		mesh.rotation.y,
		Vector2(-direction.x, direction.z).angle(),
		get_physics_process_delta_time() * 5.0
	)

func clear_head_look():
	#left over from the bone-look attempt; reset in case a pose got stuck
	if neck_bone >= 0:
		skeleton.reset_bone_pose(neck_bone)
	if head_bone >= 0:
		skeleton.reset_bone_pose(head_bone)

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

func update_chair(chair_body):
	print('updating chairs')
	for i in chairs:
		if chair_body.uid == chairs[i].uid:
			var staticbody = chair_body.get_node("StaticBody3D")
			chairs[i] = chair_body

func fear_response(position, loudness):
	#called when the CrowdEvent for explosions or gunshots fires a signal.
	#depending on the position andd radius, pedestrian must switch to a fear state.
	#print(self.global_position.distance_to(position))
	if self.global_position.distance_to(position) <= loudness:
		clear_head_look()
		fleeing_state.threat_position = position
		fleeing_state.radius = loudness
		flee_radius(position, loudness)
		#print('heard!')
		state = fleeing_state

func _process(_delta: float) -> void:
	#body turn while staring (smooth face toward player)
	if state == stare_state and stare_target != null and is_instance_valid(stare_target):
		face_toward(stare_target.global_position)

func _physics_process(_delta: float) -> void:
	#prints once per change so you can confirm Return in the Output panel
	if state != _debug_last_state:
		_debug_last_state = state
		#print(name, " -> ", _state_label(state))
		label.text = _state_label(state)
	

	
	#remember which way we are heading so whoever is following us knows
	#where "behind" is. three floats per agent per frame.
	var flat_velocity = Vector3(velocity.x, 0.0, velocity.z)
	if flat_velocity.length_squared() > 0.25:
		march_forward = flat_velocity.normalized()

	var new_velocity=state.update(self)

	#rotate the model in the direction of movement; stare handles its own facing.
	if new_velocity != Vector3.ZERO and new_velocity != null:
		mesh.rotation.y = rotate_toward(mesh.rotation.y,
			Vector2(-new_velocity.x, new_velocity.z).angle(), _delta * 5)
		anim_player.play("Walk")
	elif state == stare_state or state == idle_state or state == frozen_state:
		anim_player.play("Idle")

	#hand the velocity we want to the navigation server. it adjusts it to
	#dodge nearby agents and hands it back through velocity_computed.
	if navigation_ready:
		nav_agent.set_velocity(new_velocity)
	else:
		apply_velocity(new_velocity)


func _state_label(s) -> String:
	if s == idle_state:
		return "Idle"
	if s == walking_state:
		return "Walking"
	if s == frozen_state:
		return "Frozen"
	if s == fleeing_state:
		return "Fleeing"
	if s == returning_state:
		return "Returning"
	if s == stare_state:
		return "Staring"
	if s == marching_state:
		return "Marching"
	if s == door_state:
		return "Door"
	if s == locate_chair_state:
		return "FindChair"
	if s == sitting_state:
		return "Sitting"
	return "Unknown"


#the navigation server's answer: our velocity, adjusted to miss the neighbours
func _on_velocity_computed(safe_velocity: Vector3):
	apply_velocity(safe_velocity)

func check_door_interact():
	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		#the ray also hits walls and the floor, so check it is actually an npc
		if collider != null and collider.is_in_group("Interactable") and \
		collider.is_in_group("Door"):
			door_state.prev_target = nav_agent.target_position
			door_state.prev_state = state
			door_state.door_body = collider
			door_state.open_pos = collider.get_open_pos(global_position)
			
			update_target_location(door_state.open_pos)
			
			state = door_state

func apply_velocity(new_velocity: Vector3):
	#gravity builds up over time, so add to the fall speed we already
	#have instead of replacing it with a fixed value
	if !is_on_floor() and state != sitting_state:
		new_velocity.y = velocity.y + get_gravity().y * get_physics_process_delta_time()
	velocity = new_velocity

	move_and_slide()
