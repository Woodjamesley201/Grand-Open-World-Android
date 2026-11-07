## VehicleFactory - builds original vehicle archetypes from primitives.
class_name VehicleFactory
extends Node

const TYPES: Dictionary = {
	"sports": {
		"name": "Talon GT", "width": 1.9, "length": 4.4, "body_h": 0.55, "cabin_h": 0.42,
		"cabin_len": 0.38, "mass": 1200, "engine": 60, "max_speed": 38.0, "brake": 40,
		"steer": 0.5, "wheel_r": 0.34, "ride": 0.22,
		"colors": [Color(0.85, 0.1, 0.1), Color(0.95, 0.75, 0.1), Color(0.1, 0.3, 0.8)],
	},
	"super": {
		"name": "Viper X", "width": 2.0, "length": 4.6, "body_h": 0.48, "cabin_h": 0.38,
		"cabin_len": 0.34, "mass": 1350, "engine": 85, "max_speed": 48.0, "brake": 45,
		"steer": 0.48, "wheel_r": 0.35, "ride": 0.18,
		"colors": [Color(0.9, 0.05, 0.2), Color(0.05, 0.05, 0.08), Color(0.9, 0.5, 0.05)],
	},
	"sedan": {
		"name": "Cruiser", "width": 1.85, "length": 4.7, "body_h": 0.6, "cabin_h": 0.55,
		"cabin_len": 0.5, "mass": 1450, "engine": 38, "max_speed": 29.0, "brake": 32,
		"steer": 0.55, "wheel_r": 0.33, "ride": 0.25,
		"colors": [Color(0.75, 0.75, 0.78), Color(0.1, 0.12, 0.15), Color(0.2, 0.35, 0.6)],
	},
	"suv": {
		"name": "Ranger", "width": 2.05, "length": 5.0, "body_h": 0.85, "cabin_h": 0.6,
		"cabin_len": 0.55, "mass": 1950, "engine": 45, "max_speed": 27.0, "brake": 34,
		"steer": 0.55, "wheel_r": 0.4, "ride": 0.3,
		"colors": [Color(0.2, 0.25, 0.2), Color(0.5, 0.45, 0.4), Color(0.1, 0.15, 0.3)],
	},
	"motorcycle": {
		"name": "Blaze", "width": 0.6, "length": 2.2, "body_h": 0.35, "cabin_h": 0.3,
		"cabin_len": 0.3, "mass": 280, "engine": 22, "max_speed": 37.0, "brake": 30,
		"steer": 0.65, "wheel_r": 0.3, "ride": 0.15, "bike": true,
		"colors": [Color(0.8, 0.1, 0.1), Color(0.1, 0.1, 0.12), Color(0.9, 0.7, 0.1)],
	},
	"pickup": {
		"name": "Hauler", "width": 2.05, "length": 5.5, "body_h": 0.75, "cabin_h": 0.6,
		"cabin_len": 0.35, "mass": 2150, "engine": 50, "max_speed": 25.0, "brake": 34,
		"steer": 0.55, "wheel_r": 0.42, "ride": 0.32, "bed": true,
		"colors": [Color(0.4, 0.2, 0.1), Color(0.3, 0.35, 0.4), Color(0.55, 0.5, 0.2)],
	},
	"van": {
		"name": "Boxer Van", "width": 2.1, "length": 5.6, "body_h": 1.0, "cabin_h": 0.85,
		"cabin_len": 0.6, "mass": 2250, "engine": 40, "max_speed": 23.0, "brake": 32,
		"steer": 0.55, "wheel_r": 0.38, "ride": 0.28,
		"colors": [Color(0.85, 0.85, 0.9), Color(0.2, 0.25, 0.35), Color(0.6, 0.6, 0.2)],
	},
	"bus": {
		"name": "City Bus", "width": 2.5, "length": 9.5, "body_h": 1.7, "cabin_h": 1.0,
		"cabin_len": 0.75, "mass": 9000, "engine": 70, "max_speed": 19.0, "brake": 38,
		"steer": 0.45, "wheel_r": 0.5, "ride": 0.35, "bus": true,
		"colors": [Color(0.75, 0.55, 0.1), Color(0.2, 0.4, 0.6)],
	},
	"police": {
		"name": "Interceptor", "width": 1.95, "length": 4.9, "body_h": 0.6, "cabin_h": 0.55,
		"cabin_len": 0.5, "mass": 1500, "engine": 55, "max_speed": 34.0, "brake": 40,
		"steer": 0.55, "wheel_r": 0.35, "ride": 0.25, "police": true,
		"colors": [Color(0.1, 0.12, 0.2)],
	},
}

func build(type_id: String, color: Color = Color.BLACK, world_builder: WorldBuilder = null) -> Vehicle:
	var def: Dictionary = TYPES.get(type_id, TYPES["sedan"])
	if color == Color.BLACK:
		var palette: Array = def["colors"]
		color = palette[randi() % palette.size()]
	var v := Vehicle.new()
	v.type_id = type_id
	v.display_name = String(def["name"])
	v.setup(def, color, world_builder)
	return v

func random_civilian_type() -> String:
	var pool := ["sedan", "sedan", "suv", "van", "pickup", "sports", "bus", "motorcycle"]
	return pool[randi() % pool.size()]
