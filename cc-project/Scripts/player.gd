extends CharacterBody3D

#simple first person controller. this exists so we can walk through the
#crowd and set off danger events, not to be a polished fps.

@export var move_speed = 5.0
@export var mouse_sensitivity = 0.003

#if we ever end up below this we have fallen out of the world
@export var fall_limit = -5.0

#how far the blast is heard, and where it lands if we are aiming at open sky.
#the map is 120m across with a sparse crowd, so a small radius catches nobody:
#at 12m it reached under one person on average.
@export var explosion_radius = 25.0
@export var explosion_throw_distance = 15.0

const EXPLOSION_SCENE = preload("res://Scenes/Explosion.tscn")

#where to put us back if that happens
var spawn_position = Vector3.ZERO

#the npc we are currently pointing the gun at, or null
var aim_target = null

@onready var camera = $Camera3D
@onready var aim_ray = $Camera3D/RayCast3D

func _ready():
	#so npcs can find us for stare / reactions without a hard scene path
	add_to_group("player")

	spawn_position = global_position

	#the ray starts inside our own capsule, so ignore ourselves
	aim_ray.add_exception(self)

	#lock the mouse to the window so it drives the camera instead of
	#leaving a cursor floating over the game
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event):
	#mouse look. the whole body turns left and right, but only the camera
	#tilts up and down, so walking always follows where we are looking.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)

		#stops the camera tipping over backwards at the top and bottom
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)

	#set off an explosion where we are looking
	if event.is_action_pressed("explode"):
		throw_explosion()

	#escape releases the mouse so we can get back to the editor
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseButton and event.pressed:
		#clicking back on the window grabs the mouse again rather than firing
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.is_action_pressed("fire"):
			fire()


func _physics_process(delta):
	if !is_on_floor():
		velocity += get_gravity() * delta

	#get_vector gives us a Vector2. its y is forward/back because forward
	#is -z in godot, so it maps straight onto the z axis below.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	#transform.basis rotates the input so "forward" means where we are facing
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	move_and_slide()

	#the boundary walls should stop this ever happening, but if we do get
	#out of the world, put us back at the start instead of falling forever
	if global_position.y < fall_limit:
		global_position = spawn_position
		velocity = Vector3.ZERO

	update_aim()


#work out which npc the gun is pointed at, if any
func update_aim():
	var hit = null

	if aim_ray.is_colliding():
		var collider = aim_ray.get_collider()
		#the ray also hits walls and the floor, so check it is actually an npc
		if collider != null and collider.is_in_group("npc") and \
		Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			hit = collider
		elif collider != null and collider.is_in_group("Interactable") and \
		Input.is_action_just_pressed("Use"):
			collider.interact(self)

	#only tell npcs when the target actually changes. sweeping the mouse
	#across a crowd is then two calls per frame at most, however big it is.
	if hit == aim_target:
		return

	if aim_target != null:
		aim_target.set_aimed_at(false)

	if hit != null:
		hit.set_aimed_at(true)

	aim_target = hit


#drop an explosion wherever we are looking. the blast node announces itself
#through CrowdEvents, so the crowd reacts to the event rather than to the node.
func throw_explosion():
	var spot: Vector3

	if aim_ray.is_colliding():
		#land it on whatever we are pointing at
		spot = aim_ray.get_collision_point()
	else:
		#aiming at open sky, so drop it a fixed distance ahead of us instead
		spot = camera.global_position - camera.global_transform.basis.z * explosion_throw_distance

	var blast = EXPLOSION_SCENE.instantiate()
	blast.radius = explosion_radius
	get_tree().current_scene.add_child(blast)
	blast.global_position = spot

	print("explosion at ", spot, " radius ", explosion_radius)


#pulling the trigger. we do not model bullets, we just announce the noise
#so the crowd ai has something to react to.
func fire():
	CrowdEvents.report_gunshot(global_position)

	#aim_target only gets set while the right mouse button is held (that is
	#what makes npcs freeze), so reporting it here made every ordinary shot
	#say "nothing". check what the ray is actually on instead.
	var shot = null
	if aim_ray.is_colliding():
		var collider = aim_ray.get_collider()
		if collider != null and collider.is_in_group("npc"):
			shot = collider

	if shot != null:
		print("fired at ", shot.name)
	else:
		print("fired at nothing")
