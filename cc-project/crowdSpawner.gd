extends Node

#builds the crowd by copying the pedestrian already in the scene, so we can
#test 10 / 25 / 50 npcs by changing one number instead of hand editing Test.tscn.

@export var crowd_size = 18

#prints the frame rate every few seconds so we can write the numbers down
@export var show_fps = true

var report_timer = 0.0

func _ready():
	#lets us benchmark without touching the scene: godot ... -- --crowd=50
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crowd="):
			crowd_size = int(arg.split("=")[1])

	#wait until the pedestrians already in the scene have their navigation
	#working. once that is true the map is built and we can pick spawn points.
	var npcs = get_tree().get_nodes_in_group("npc")
	while npcs.is_empty() or not npcs[0].navigation_ready:
		await get_tree().physics_frame
		npcs = get_tree().get_nodes_in_group("npc")

	build_crowd()


func build_crowd():
	var npcs = get_tree().get_nodes_in_group("npc")
	if npcs.is_empty():
		return

	var template = npcs[0]
	var map = template.nav_agent.get_navigation_map()

	#the map reports its regions before the polygons are actually usable, and
	#asking for a random point too early just returns (0,0,0). that would drop
	#the whole crowd on the same spot inside the floor, and they would fall
	#through it. wait until we get a real point back.
	while NavigationServer3D.map_get_random_point(map, 1, true) == Vector3.ZERO:
		await get_tree().physics_frame

	#too many pedestrians in the scene, so remove the extras. we never remove
	#the first one because everything else is copied from it.
	while npcs.size() > crowd_size and npcs.size() > 1:
		npcs.pop_back().queue_free()

	#not enough, so copy the template until the crowd is the size we asked for
	for i in range(npcs.size(), crowd_size):
		#flags are DUPLICATE_GROUPS | DUPLICATE_SCRIPTS. signals are left out on
		#purpose: copying them would wire the copy's navigation agent back into
		#the original pedestrian, so the copy would never move.
		var clone = template.duplicate(6)

		#without this godot names them @CharacterBody3D@5 and so on, which
		#is useless when we are printing who the player shot at
		clone.name = "Pedestrian%d" % (i + 1)

		template.get_parent().add_child(clone)

		#drop them on a random spot on the navmesh so they start spread out.
		#the 1.0 lifts them clear of the floor slab, same as the pedestrians
		#already placed in the scene, so gravity settles them instead of
		#starting them half buried in it.
		clone.global_position = NavigationServer3D.map_get_random_point(map, 1, true) + Vector3(0, 1.0, 0)

	print("crowd size: ", crowd_size)


func _process(delta):
	if not show_fps:
		return

	report_timer += delta
	if report_timer >= 5.0:
		report_timer = 0.0
		print("npcs: %d | fps: %d" % [
			get_tree().get_nodes_in_group("npc").size(),
			Engine.get_frames_per_second()])
