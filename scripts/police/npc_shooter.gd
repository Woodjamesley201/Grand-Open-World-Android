## ShooterNPC - armed character on foot (police officer or gang member).
class_name ShooterNPC
extends CharacterBody3D

signal npc_died(n: ShooterNPC)

var target: Node3D
var faction: String = "police"
var health: float = 40.0
var max_health: float = 40.0
var fire_rate: float = 1.7
var accuracy: float = 0.5
var damage: float = 6.0
var engage_range: float = 30.0
var move_speed: float = 4.6
var _fire_timer: float = 1.0
var _dead: bool = false
var _model: Node3D
var _audio: AudioManager

func setup(t: Node3D, fact: String) -> void:
	target = t
	faction = fact
	if fact == "police":
		add_to_group("police")
	add_to_group("npc")
	collision_layer = 4
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_build_model()

func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var cloth := Color(0.12, 0.15, 0.3) if faction == "police" else Color(0.15, 0.1, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cloth
	var torso := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.5, 0.6, 0.3)
	torso.mesh = tm
	torso.material_override = mat
	torso.position = Vector3(0, 1.1, 0)
	_model.add_child(torso)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.28, 0.3, 0.28)
	head.mesh = hm
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.5, 0.36)
	head.material_override = skin
	head.position = Vector3(0, 1.58, 0)
	_model.add_child(head)
	var legs := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.36, 0.8, 0.26)
	legs.mesh = lm
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.1, 0.1, 0.14)
	legs.material_override = pants
	legs.position = Vector3(0, 0.4, 0)
	_model.add_child(legs)
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.08, 0.12, 0.4)
	gun.mesh = gm
	var gm2 := StandardMaterial3D.new()
	gm2.albedo_color = Color(0.1, 0.1, 0.11)
	gun.material_override = gm2
	gun.position = Vector3(0.3, 1.2, -0.25)
	_model.add_child(gun)

func _ready() -> void:
	_audio = get_node_or_null("/root/Main/AudioManager")

func _physics_process(delta: float) -> void:
	if _dead or target == null:
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	# move toward the target, stop at engagement range
	if dist > 14.0:
		var dir := to.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_model.rotation.y = atan2(dir.x, dir.z)
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * 8.0)
		velocity.z = lerpf(velocity.z, 0.0, delta * 8.0)
		if dist > 0.5:
			var face := to.normalized()
			_model.rotation.y = atan2(face.x, face.z)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# shoot
	_fire_timer -= delta
	if _fire_timer <= 0.0 and dist < engage_range and _has_los():
		_fire_timer = fire_rate
		_shoot()

func _has_los() -> bool:
	var from := global_position + Vector3(0, 1.4, 0)
	var to := target.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _shoot() -> void:
	if _audio != null:
		_audio.play_3d("gunshot", global_position, -10.0)
	if randf() < accuracy and target.has_method("take_hit"):
		target.call("take_hit", damage)

func take_hit(dmg: float) -> void:
	if _dead:
		return
	health -= dmg
	if health <= 0.0:
		die()

func die() -> void:
	if _dead:
		return
	_dead = true
	npc_died.emit(self)
	rotation.x = PI / 2.0
	position.y = 0.3
	set_physics_process(false)
	var t := get_tree().create_timer(6.0)
	t.timeout.connect(queue_free)
