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

		#occasionally decide to get a walking group together
		if agent.try_start_march_group():
			return Vector3.ZERO

		if agent.idle_timer <= 0.0:
			#random chance that agent seeks out a chair

			if (randf() <= 0.05):
				# set target location to a random chair on the map
				if agent.chairs:
					var idx= randi() % agent.chairs.size()
					var target_chair = agent.chairs[idx]

					#move to seeking chair state
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
	#single file line. followers walk the leader's own breadcrumb trail rather
	#than steering at a point behind the person ahead of them. that matters for
	#two reasons: the trail is by definition walkable, so nobody cuts a corner
	#into a wall, and every follower reads the same clean source instead of
	#chaining off a neighbour's jittery heading, which used to make the wobble
	#grow with every place down the line.
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

		if gap < agent.march_slot_tolerance:
			#in place. clear the stuck tracker, otherwise standing still on
			#purpose gets mistaken for being jammed against something.
			agent.stuck_timer = 0.0
			agent.last_position = agent.global_position
			return Vector3.ZERO

		#only check for being jammed when we are actually trying to travel.
		#easing into a slot right in front of us is slow on purpose, and that
		#would otherwise keep tripping the stuck detector.
		if gap > agent.march_path_distance:
			if agent.is_stuck():
				agent.march_force_path_timer = agent.march_unstick_time
				agent.update_target_location(slot)
		else:
			agent.stuck_timer = 0.0
			agent.last_position = agent.global_position

		agent.march_force_path_timer -= agent.get_physics_process_delta_time()

		var direction: Vector3

		if gap <= agent.march_path_distance and agent.march_force_path_timer <= 0.0:
			#the trail point is close and the leader already walked it, so
			#heading straight there is safe and much crisper than pathing
			direction = to_slot
		else:
			#a long way back, or we just got stuck, so use a real path. the
			#target moves constantly and re-pathing every frame is what makes
			#follow behaviour expensive, so only a few times a second.
			agent.march_repath_timer -= agent.get_physics_process_delta_time()
			if agent.march_repath_timer <= 0.0:
				agent.march_repath_timer = agent.march_repath_interval
				agent.update_target_location(slot)

			var next_location = agent.nav_agent.get_next_path_position()
			direction = next_location - agent.global_position
			direction.y = 0.0

		#marchers still open doors like everyone else
		agent.check_door_interact()

		var catch_up_gap = agent.march_slot_tolerance * 3.0
		var march_speed = agent.speed

		if gap > catch_up_gap:
			#well behind, so hurry up and close the distance
			march_speed = agent.speed * 1.4
		else:
			#ease in as we approach rather than running flat out then stopping
			#dead, which makes a line bounce and zigzag. the floor stops them
			#crawling so slowly that they look frozen.
			march_speed = agent.speed * max(gap / catch_up_gap, 0.35)

		return direction.normalized() * march_speed

class FrozenState:
	#stand still while the gun is on us. if the player looks away we calm down;
	#if they keep aiming we eventually break and run.
	func update(agent):
		#threat withdrawn. a scare that passes is not worth running from, so
		#walk it off rather than sprinting across the map.
		if not agent.is_aimed_at:
			agent.start_returning()
			return Vector3.ZERO

		agent.freeze_timer -= agent.get_physics_process_delta_time()

		if agent.freeze_timer <= 0.0:
			#still being aimed at, so panic and run away from whoever it is
			agent.fleeing_state.threat_position = agent.aim_threat_position
			agent.fleeing_state.radius = agent.flee_distance
			agent.flee_radius(agent.aim_threat_position, agent.flee_distance)
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
				#reset both, or the next door we meet starts already "opened"
				#with a stale timer and we get stranded in the doorway
				time = 0
				agent.door_state.current_door_state = agent.door_state.move_to_pos_state
				agent.update_target_location(agent.door_state.prev_target)
				agent.state = agent.door_state.prev_state
			
			return Vector3.ZERO
			

class LocateChairState:
	#chair object to be located. needs to be set
	var chair = null

	func update(agent):
		if agent.global_position.distance_to(agent.nav_agent.target_location) < 4 \
			and !chair.check_sitting():
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
		agent.snap_to_seat(chair)
		return Vector3.ZERO
	
	func move_npc(agent, status):
		#we used to disable the collision shape while seated. that made seated
		#npcs invisible to the player's aim ray, and because this only runs
		#when the sit timer expires, anything else that pulled them out of the
		#chair (a gunshot, being aimed at) left collision off for good and they
		#fell through the floor.
		if chair != null:
			agent.snap_to_seat(chair)

		if not status:
			#the chair rotated our whole body to face it. everywhere else only
			#the mesh child is turned, so leftover body rotation makes us walk
			#crooked. clear it on the way out of the seat.
			agent.rotation = Vector3.ZERO

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

#how far an npc runs when it panics. kept well inside the level so the
#destination is actually reachable instead of a point past the boundary.
@export var flee_distance = 25.0

#how far above the seat surface to put the hip joint. the bone sits inside the
#mesh rather than on the skin, so a small lift stops the seat clipping into the
#backside. everything else about the placement is measured at runtime.
@export var sit_surface_offset = 0.09

#how long does the pedestrian sit for?
@export var sitting_timer = 30.0

#how close the player must be before an idle npc may stare
@export var stare_range = 8.0
#rough chance per second while idle and in range
@export var stare_chance_per_second = 0.35
#how long they keep looking
@export var stare_duration_min = 1.5
@export var stare_duration_max = 3.5

#chance per second that a bored, idle npc decides to start a walking group
@export var march_call_chance_per_second = 0.03
#how far away someone can hear that call and come over
@export var march_join_range = 35.0
#most people that will fall in behind one leader
@export var march_group_max = 5
#how long a leader keeps its group together before everyone goes back to normal
@export var march_lead_duration = 45.0

#marching: how far apart people stand in the line. avoidance already keeps
#agents about 1.4m apart, so anything near that has them shoving each other.
@export var march_spacing = 2.2
#how close to our slot counts as being in place
@export var march_slot_tolerance = 0.6
#seconds between path updates while following a moving slot
@export var march_repath_interval = 0.25
#slots nearer than this are steered at directly instead of pathfound. the
#navigation agent reports "arrived" about a metre out, which left followers
#parked just short of their slot.
@export var march_path_distance = 4.0
#after walking into something, how long to use real paths instead of
#steering straight at the slot
@export var march_unstick_time = 3.0

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
var march_force_path_timer = 0.0
#leaders only: how many have fallen in, and how long left before disbanding
var march_followers = 0
var march_lead_timer = 0.0
#breadcrumbs of where this npc has walked, newest first. only a march leader
#fills this in; its followers read it to walk the same route.
var march_trail: Array[Vector3] = []
#metres between breadcrumbs, and how many to keep. 64 x 0.4m is about 25m of
#history, plenty for any line we would actually show.
const MARCH_TRAIL_STEP = 0.4
const MARCH_TRAIL_MAX = 64
#the leader's last travel direction, so followers know where "behind" is
var march_forward = Vector3(0, 0, -1)

#true while the player's gun is pointed at this npc. set by the player,
#read by the fsm - a FrozenState can just check this in its update().
var is_aimed_at = false

#where whoever aimed at us was standing, so we can run away from them rather
#than to a random point on the map
var aim_threat_position = Vector3.ZERO

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
@onready var collision_shape = $CollisionShape3D
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

	#listen for anyone putting a call out for a walking group
	CrowdEvents.march_call.connect(_on_march_call)

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

func flee_radius(position, _radius):
	# Given a threat position, pick somewhere to run that is away from it and
	# actually reachable.

	var flee_direction = (global_position - position).normalized()

	#we used to aim radius * 1.5 away. the gunshot radius is 50m, which is most
	#of the level, so that target always landed well outside the walkable area.
	#navigation then walked everyone into the boundary and held them there:
	#measured 17.5% of all fleeing frames pressed against geometry.
	var wanted = global_position + flee_direction * flee_distance

	#snap onto the navmesh so the destination is somewhere we can stand
	var map = nav_agent.get_navigation_map()
	update_target_location(NavigationServer3D.map_get_closest_point(map, wanted))

#called by the player when its aim ray enters or leaves this npc.
#only called when the target changes, not every frame.
func set_aimed_at(aimed: bool):
	is_aimed_at = aimed
	#if the gun just landed on us and we are not already reacting, freeze
	if aimed and state != frozen_state and state != fleeing_state:
		start_frozen()

#roll whether a bored npc decides to start a walking group and put a call out
func try_start_march_group() -> bool:
	if is_march_leader or march_leader != null:
		return false

	var chance = march_call_chance_per_second * get_physics_process_delta_time()
	if randf() > chance:
		return false

	is_march_leader = true
	march_followers = 0
	march_lead_timer = march_lead_duration
	march_trail.clear()
	CrowdEvents.call_for_march(self)
	return true


#someone nearby wants company. fall in behind them if we are free to.
func _on_march_call(leader):
	if leader == self or not is_instance_valid(leader):
		return
	#already busy leading, following, sitting, or reacting to danger
	if is_march_leader or march_leader != null:
		return
	if state != idle_state and state != walking_state:
		return
	if leader.march_followers >= march_group_max:
		return
	if global_position.distance_to(leader.global_position) > march_join_range:
		return

	leader.march_followers += 1
	#we walk to the leader first: MarchingState aims at their trail, and an
	#empty trail just means "go stand where the leader is"
	join_march(leader, leader, leader.march_followers)


#stop leading and let everyone drift back to normal crowd behaviour
func end_march_group():
	is_march_leader = false
	march_followers = 0
	march_trail.clear()


#is the line we belong to still intact
func march_is_valid() -> bool:
	if march_leader == null or not is_instance_valid(march_leader):
		return false
	#the leader can call time on the group, which sends everyone back to normal
	return march_leader.is_march_leader

#walk back along the leader's breadcrumb trail until we have covered our own
#place in the line, and stand there
func march_slot_position() -> Vector3:
	var trail = march_leader.march_trail
	if trail.is_empty():
		return march_leader.global_position

	var wanted_distance = march_spacing * march_slot
	var travelled = 0.0
	var previous = march_leader.global_position

	for point in trail:
		var segment = previous.distance_to(point)
		if travelled + segment >= wanted_distance:
			#interpolate inside the segment. snapping to whichever breadcrumb
			#happens to be nearest makes the target jump 0.4m at a time, and
			#the follower visibly twitches with every jump.
			var along = (wanted_distance - travelled) / max(segment, 0.0001)
			return previous.lerp(point, along)
		travelled += segment
		previous = point

	#trail is shorter than our place in the line, so aim at its oldest point
	return trail[trail.size() - 1]

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

	#note where the threat is now, while we can still see who it is
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		aim_threat_position = player.global_position

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

#where to stand an npc so it looks seated: over the chair, but at the height
#it would normally stand at rather than sunk into the chair's own origin
#the top of the chair's own mesh, so this keeps working if the chair is resized
func chair_seat_point(chair) -> Vector3:
	var seat_y = chair.global_position.y
	var seat_mesh = chair.get_node_or_null("MeshInstance3D")
	if seat_mesh != null:
		seat_y = seat_mesh.global_position.y + seat_mesh.get_aabb().end.y

	return Vector3(
		chair.global_position.x,
		seat_y + sit_surface_offset,
		chair.global_position.z)


#where the pelvis actually is right now, taken from the posed skeleton
func hip_world_position():
	var left = skeleton.find_bone("Hip.L")
	var right = skeleton.find_bone("Hip.R")
	if left < 0 or right < 0:
		return null

	var a = skeleton.global_transform * skeleton.get_bone_global_pose(left).origin
	var b = skeleton.global_transform * skeleton.get_bone_global_pose(right).origin
	return (a + b) * 0.5


#slide ourselves so the pelvis lands on the seat. we correct from the posed
#skeleton instead of hard-coding an offset, because the right number depends on
#the model and the animation, and guessing it produced npcs sitting through the
#chair, beside it, and hovering over it in turn.
func snap_to_seat(chair):
	var hips = hip_world_position()
	if hips == null:
		#no skeleton to measure, so fall back to the chair's own position
		global_position = chair_seat_point(chair)
		return

	global_position += chair_seat_point(chair) - hips


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
	#fires whenever any chair changes occupancy. there is nothing to swap:
	#"chairs" already holds these exact node references, so occupancy is
	#visible through them directly.
	#
	#the previous version threw on every chair event for two reasons. nodes
	#have no .uid property, and "for i in chairs" walks the chair objects
	#themselves, then used one as an array index.
	pass

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
	#a leader keeps its group together for a while, then calls time and
	#everyone drifts back to ordinary crowd behaviour
	if is_march_leader:
		march_lead_timer -= _delta
		if march_lead_timer <= 0.0:
			end_march_group()

	#a march leader drops a breadcrumb every so often so its followers can walk
	#the exact route it took. only leaders pay for this.
	if is_march_leader:
		if march_trail.is_empty() or global_position.distance_to(march_trail[0]) > MARCH_TRAIL_STEP:
			march_trail.push_front(global_position)
			if march_trail.size() > MARCH_TRAIL_MAX:
				march_trail.resize(MARCH_TRAIL_MAX)

	#belt and braces: whatever route we took out of a chair, make sure we can
	#collide with the world again before we try to walk on it
	if state != sitting_state and collision_shape.disabled:
		collision_shape.disabled = false

	var new_velocity=state.update(self)

	#rotate the model in the direction of movement; stare handles its own facing.
	if new_velocity != Vector3.ZERO and new_velocity != null:
		mesh.rotation.y = rotate_toward(mesh.rotation.y,
			Vector2(-new_velocity.x, new_velocity.z).angle(), _delta * 5)
		anim_player.play("Walk")
	elif state == stare_state or state == idle_state or state == frozen_state:
		anim_player.play("Idle")

	#a seated npc is placed by hand each frame. running move_and_slide on a
	#standing capsule that overlaps the chair just shoves them back off it, so
	#skip physics movement entirely while sitting. the collider stays enabled,
	#which is what lets the player still aim at and shoot them.
	if state == sitting_state:
		velocity = Vector3.ZERO
		return

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
	#the navigation server fires this every physics tick once avoidance is on,
	#not only when we call set_velocity. a seated npc is placed by hand, so
	#letting move_and_slide run here shoved them straight back off the chair.
	if state == sitting_state:
		return
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
