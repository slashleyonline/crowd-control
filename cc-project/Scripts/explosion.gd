extends Node3D

#a purely visual blast: a sphere that swells and fades, then deletes itself.
#the crowd does not watch this node at all - it reacts to the CrowdEvents
#explosion signal, exactly like it reacts to gunfire.

@export var radius = 25.0
@export var duration = 0.6

#the fireball is drawn smaller than the radius people react to, the same way a
#real blast is heard much further than it is seen. a sphere drawn at the full
#radius just fills the screen.
@export var visual_fraction = 0.35

var elapsed = 0.0

@onready var ball = $Ball

var fade_material: StandardMaterial3D = null

func _ready():
	#give this blast its own copy of the material, otherwise every explosion
	#shares one and they fade each other out
	var base = ball.mesh.surface_get_material(0)
	if base != null:
		fade_material = base.duplicate()
		ball.set_surface_override_material(0, fade_material)

	#tell the crowd first so the reaction lines up with the flash
	CrowdEvents.report_explosion(global_position, radius)

func _process(delta):
	elapsed += delta
	var progress = elapsed / duration

	if progress >= 1.0:
		queue_free()
		return

	#swell out to the blast radius and fade as it goes
	ball.scale = Vector3.ONE * lerp(0.2, radius * visual_fraction, progress)
	if fade_material != null:
		fade_material.albedo_color.a = 1.0 - progress
