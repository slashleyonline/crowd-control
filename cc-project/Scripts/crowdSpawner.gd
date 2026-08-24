extends Node

#builds the crowd by copying the pedestrian already in the scene, so we can
#test 10 / 25 / 50 npcs by changing one number instead of hand editing Test.tscn.

@export var crowd_size = 18

#prints the frame rate every few seconds so we can write the numbers down
@export var show_fps = true

var report_timer = 0.0

#loading textures and models
@export var dict_eye = { 
	"Angry" : preload("res://Textures/Face/Eyes/Angry.png"),
	"Arched" : preload("res://Textures/Face/Eyes/Arched.png"),
	"Groggy" : preload("res://Textures/Face/Eyes/Groggy.png"),
	"Round" : preload("res://Textures/Face/Eyes/Round.png")}

@export var dict_mouth = {
	"Cat" : preload("res://Textures/Face/Mouth/Cat.png"),
	"Frown" : preload("res://Textures/Face/Mouth/Frown.png"),
	"Grin" : preload("res://Textures/Face/Mouth/Grin.png"),
	"Neutral" : preload("res://Textures/Face/Mouth/Neutral.png"),
	"Toothy Smile" : preload("res://Textures/Face/Mouth/Toothy Smile.png"),
	"V" : preload("res://Textures/Face/Mouth/V.png")
}

@export var dict_hair = {
	"Bald" : preload("res://Models/Player/Cosmetic/Hair/Bald.tres"),
	"Combover" : preload("res://Models/Player/Cosmetic/Hair/Combover.tres"),
	"Curly" : preload("res://Models/Player/Cosmetic/Hair/Curly.tres"),
	"FlatTop" : preload("res://Models/Player/Cosmetic/Hair/FlatTop.tres"),
	"Long" : preload("res://Models/Player/Cosmetic/Hair/Long.tres"),
}

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
		clone.add_to_group('npc')
		npcs.append(clone)
		template.get_parent().add_child(clone)
		
		#drop them on a random spot on the navmesh so they start spread out.
		#the 1.0 lifts them clear of the floor slab, same as the pedestrians
		#already placed in the scene, so gravity settles them instead of
		#starting them half buried in it.
		clone.global_position = NavigationServer3D.map_get_random_point(map, 1, true) + Vector3(0, 1.0, 0)
	attach_signals(npcs)
	modify_meshes(npcs)

	print("crowd size: ", crowd_size)


func attach_signals(npc_list):
	#attach crowdEvents Signals to all predestrians.
	for npc in npc_list:
		#print('connected!')
		CrowdEvents.connect("gunshot", npc.fear_response)
		CrowdEvents.connect("explosion", npc.fear_response)
	
	pass

func modify_meshes(npc_list):
	#modify the npc models to demonstrate variety
	for npc in npc_list:
		var skeleton3d = npc.get_node("PedBase/Armature/Skeleton3D")
		#randomize skin color
		var body = skeleton3d.get_node("Body")
		
		var skin = StandardMaterial3D.new()
		skin.albedo_color = Color(randf_range(0,1), randf_range(0,1), randf_range(0,1))
		
		body.set_surface_override_material(0, skin)
		
		#randomize facial features
		
		#eyes
		var eyes = skeleton3d.get_node("Eyes")
		var size = dict_eye.size()
		var idx = randi() % size
		var random_eye = dict_eye.keys()[idx]
		
		var eye_texture = dict_eye[random_eye]

		eyes.mesh = eyes.mesh.duplicate(true)
		var mat = eyes.get_active_material(0)
		print('selected texture: ', eye_texture)
		mat.albedo_texture = eye_texture
		print(mat.albedo_texture)
		
		#mouth
		var mouth = skeleton3d.get_node("Mouth")
		size = dict_mouth.size()
		idx = randi() % size
		var random_mouth = dict_mouth.keys()[idx]
		
		var mouth_texture = dict_mouth[random_mouth]

		mouth.mesh = mouth.mesh.duplicate(true)
		mat = mouth.get_active_material(0)
		print('selected texture: ', eye_texture)
		mat.albedo_texture = mouth_texture
		print(mat.albedo_texture)
		
		#randomize hair
		size = dict_hair.size()
		idx = randi() % size
		var random_hair = dict_hair.keys()[idx]
		print(random_hair)
		
		var hair_mesh = dict_hair[random_hair]
		var hair = MeshInstance3D.new()
		hair.mesh = hair_mesh
		skeleton3d.add_child(hair)

		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(randf_range(0,1), randf_range(0,1), randf_range(0,1))
		hair.set_surface_override_material(0, mat)
	
func _process(delta):
	if not show_fps:
		return

	report_timer += delta
	if report_timer >= 5.0:
		report_timer = 0.0
		print("npcs: %d | fps: %d" % [
			get_tree().get_nodes_in_group("npc").size(),
			Engine.get_frames_per_second()])
