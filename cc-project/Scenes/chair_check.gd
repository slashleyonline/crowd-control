extends Node3D

func interact(body):
	var chair = $StaticBody3D
	chair.interact(body)

func check_sitting():
	var body = $StaticBody3D
	return body.check_sitting()
