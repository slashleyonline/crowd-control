extends CharacterBody3D

#simple first person controller. this exists so we can walk through the
#crowd and set off danger events, not to be a polished fps.

@export var move_speed = 5.0
@export var mouse_sensitivity = 0.003

#if we ever end up below this we have fallen out of the world
@export var fall_limit = -5.0

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


#pulling the trigger. we do not model bullets, we just announce the noise
#so the crowd ai has something to react to.
func fire():
	CrowdEvents.report_gunshot(global_position)

	if aim_target != null:
		print("fired at ", aim_target.name)
	else:
		print("fired at nothing")
