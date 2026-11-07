## PedBody - physical body of a pedestrian (so vehicles, bullets and police
## raycasts can interact with it).
class_name PedBody
extends AnimatableBody3D

var manager: PedestrianManager = null

func take_hit(dmg: float) -> void:
	if manager != null:
		manager.ped_hit(self, dmg)
