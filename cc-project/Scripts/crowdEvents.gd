extends Node

#autoload singleton (registered as CrowdEvents in project settings).
#this is how the player tells the crowd that something dangerous happened
#without the player needing a reference to every npc in the scene.
#anything can emit, anything can listen.

#a gun was fired at this position. loudness is how far away it can be heard, in meters.
signal gunshot(position: Vector3, loudness: float)

#an explosion at this position. npcs inside radius should react.
signal explosion(position: Vector3, radius: float)

#how far a gunshot carries by default. the map is 40x40 so this covers most of it.
const GUNSHOT_LOUDNESS = 50.0

func report_gunshot(position: Vector3, loudness: float = GUNSHOT_LOUDNESS):
	gunshot.emit(position, loudness)

func report_explosion(position: Vector3, radius: float):
	explosion.emit(position, radius)


#TEMPORARY: press G to fake a gunshot at the camera so the npc danger states
#can be tested before the player controller exists. delete once the player fires.
func _unhandled_key_input(event):
	#echo check stops held keys from firing hundreds of shots per second
	if event.is_pressed() and not event.echo and event.keycode == KEY_G:
		var cam = get_viewport().get_camera_3d()
		if cam:
			report_gunshot(cam.global_position)

			#count who was close enough to hear it, so the test shows the
			#distance falloff working and not just that a key was pressed
			var heard = 0
			var npcs = get_tree().get_nodes_in_group("npc")
			for npc in npcs:
				if npc.global_position.distance_to(cam.global_position) <= GUNSHOT_LOUDNESS:
					heard += 1
			print("debug gunshot at ", cam.global_position,
				" - ", heard, " of ", npcs.size(), " npcs in earshot")
