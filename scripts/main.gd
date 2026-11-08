extends Node3D

const FLOOR_SIZE := Vector3(12.0, 0.2, 12.0)
const CUBE_SIZE := Vector3(0.17, 0.17, 0.17)
const MOVE_SPEED := 2.0
const GRAB_DISTANCE := 0.38
const HAND_PUSH_RADIUS := 0.105
const ORB_SPEED := 19.0

var xr_active := false
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_controller: XRController3D
var right_controller: XRController3D
var left_hand: Node3D
var right_hand: Node3D
var held_by_controller: Dictionary = {}
var previous_grip: Dictionary = {}
var previous_trigger: Dictionary = {}
var hand_finger_nodes: Dictionary = {}
var controller_positions: Dictionary = {}


func _ready() -> void:
	_build_environment()
	_build_world()
	_setup_xr()


func _process(delta: float) -> void:
	if not xr_active:
		return
	_update_controller_interaction(left_controller)
	_update_controller_interaction(right_controller)
	_update_hand_fingers(left_controller)
	_update_hand_fingers(right_controller)
	_constrain_hand_to_table(left_controller, left_hand)
	_constrain_hand_to_table(right_controller, right_hand)
	_move_player(delta)


func _physics_process(_delta: float) -> void:
	for projectile in get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(projectile):
			continue
		var p: Vector3 = projectile.global_position
		if absf(p.x) > FLOOR_SIZE.x * 0.5 or absf(p.z) > FLOOR_SIZE.z * 0.5 or p.y < -1.0 or p.y > 8.0:
			projectile.queue_free()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.43, 0.62, 0.78)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.82, 0.88)
	environment.ambient_light_energy = 0.85
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.45
	sun.shadow_blur = 0.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 16.0
	add_child(sun)


func _build_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = FLOOR_SIZE
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.1
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.20, 0.34, 0.25)
	floor_material.roughness = 0.95
	floor_mesh.material_override = floor_material
	floor_body.add_child(floor_mesh)

	var floor_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = FLOOR_SIZE
	floor_shape.shape = box_shape
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)

	_create_table(Vector3(0.0, 0.0, -1.25))
	_create_cube(Vector3(-0.62, 0.88, -1.18), Color(0.92, 0.12, 0.10), "RedCube")
	_create_cube(Vector3(-0.20, 0.88, -1.18), Color(0.08, 0.30, 0.96), "BlueCube")
	_create_bouncy_ball(Vector3(-0.62, 0.94, -1.53))
	_create_physics_crate(Vector3(-0.20, 0.91, -1.53))
	_create_rubber_puck(Vector3(0.28, 0.91, -1.53))
	_create_training_sword(Vector3(0.28, 1.10, -1.18))
	_create_training_dummy(Vector3(-1.75, 0.0, -1.25))
	_create_energy_launcher(Vector3(0.70, 0.91, -1.18))


func _create_table(at: Vector3) -> void:
	var table := StaticBody3D.new()
	table.name = "SandboxTable"
	table.position = at
	add_child(table)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.22, 0.13)
	wood.roughness = 0.88
	_add_table_part(table, "TableTop", Vector3(0.0, 0.74, 0.0), Vector3(1.9, 0.08, 0.95), wood)
	for x in [-0.82, 0.82]:
		for z in [-0.37, 0.37]:
			_add_table_part(table, "Leg", Vector3(x, 0.36, z), Vector3(0.09, 0.72, 0.09), wood)


func _add_table_part(parent: StaticBody3D, part_name: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	collision.position = at
	parent.add_child(collision)


func _create_cube(at: Vector3, tint: Color, object_name: String) -> void:
	var body := RigidBody3D.new()
	body.name = object_name
	body.position = at
	body.mass = 0.35
	body.gravity_scale = 1.0
	body.add_to_group("grabbable")
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = CUBE_SIZE
	mesh_instance.mesh = cube_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.68
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = CUBE_SIZE
	collision.shape = shape
	body.add_child(collision)


func _create_bouncy_ball(at: Vector3) -> void:
	var ball := RigidBody3D.new()
	ball.name = "BouncyBall"
	ball.position = at
	ball.mass = 0.22
	ball.gravity_scale = 1.0
	ball.linear_damp = 0.04
	ball.angular_damp = 0.08
	var bounce := PhysicsMaterial.new()
	bounce.bounce = 0.86
	bounce.friction = 0.48
	ball.physics_material_override = bounce
	ball.add_to_group("grabbable")
	add_child(ball)
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	mesh_instance.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.58, 0.08)
	material.roughness = 0.38
	mesh_instance.material_override = material
	ball.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.11
	collision.shape = shape
	ball.add_child(collision)


func _create_physics_crate(at: Vector3) -> void:
	var crate := RigidBody3D.new()
	crate.name = "SmallCrate"
	crate.position = at
	crate.mass = 0.75
	crate.gravity_scale = 1.0
	crate.add_to_group("grabbable")
	var wood_bounce := PhysicsMaterial.new()
	wood_bounce.bounce = 0.12
	wood_bounce.friction = 0.9
	crate.physics_material_override = wood_bounce
	add_child(crate)
	var dimensions := Vector3(0.20, 0.20, 0.20)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.29, 0.14)
	material.roughness = 0.92
	mesh_instance.material_override = material
	crate.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	crate.add_child(collision)


func _create_rubber_puck(at: Vector3) -> void:
	var puck := RigidBody3D.new()
	puck.name = "RubberPuck"
	puck.position = at
	puck.mass = 0.38
	puck.gravity_scale = 1.0
	puck.add_to_group("grabbable")
	var rubber := PhysicsMaterial.new()
	rubber.bounce = 0.58
	rubber.friction = 0.72
	puck.physics_material_override = rubber
	add_child(puck)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.105
	mesh.bottom_radius = 0.105
	mesh.height = 0.07
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.68, 0.43)
	material.roughness = 0.65
	mesh_instance.material_override = material
	puck.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.105
	shape.height = 0.07
	collision.shape = shape
	puck.add_child(collision)


func _create_training_sword(at: Vector3) -> void:
	var body := RigidBody3D.new()
	body.name = "TrainingSword"
	body.position = at
	body.mass = 0.65
	body.gravity_scale = 1.0
	body.add_to_group("grabbable")
	body.contact_monitor = true
	body.max_contacts_reported = 8
	add_child(body)
	var grip_material := StandardMaterial3D.new()
	grip_material.albedo_color = Color(0.20, 0.16, 0.12)
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color(0.63, 0.70, 0.76)
	blade_material.metallic = 0.55
	blade_material.roughness = 0.38
	var guard_material := StandardMaterial3D.new()
	guard_material.albedo_color = Color(0.30, 0.34, 0.39)
	guard_material.metallic = 0.65
	_add_launcher_box(body, "SwordGrip", Vector3(0.0, 0.0, 0.19), Vector3(0.045, 0.045, 0.20), grip_material)
	_add_launcher_box(body, "SwordGuard", Vector3(0.0, 0.0, 0.075), Vector3(0.19, 0.035, 0.045), guard_material)
	_add_launcher_box(body, "SwordBlade", Vector3(0.0, 0.0, -0.20), Vector3(0.075, 0.025, 0.48), blade_material)
	var grip_collision := CollisionShape3D.new()
	var grip_shape := BoxShape3D.new()
	grip_shape.size = Vector3(0.065, 0.065, 0.22)
	grip_collision.shape = grip_shape
	grip_collision.position = Vector3(0.0, 0.0, 0.19)
	body.add_child(grip_collision)
	var blade_collision := CollisionShape3D.new()
	var blade_shape := BoxShape3D.new()
	blade_shape.size = Vector3(0.085, 0.04, 0.49)
	blade_collision.shape = blade_shape
	blade_collision.position = Vector3(0.0, 0.0, -0.20)
	body.add_child(blade_collision)
	body.body_entered.connect(_on_sword_body_entered.bind(body))


func _on_sword_body_entered(other: Node, sword: RigidBody3D) -> void:
	if not is_instance_valid(sword) or sword.freeze or other == null:
		return
	if other.is_in_group("dummy_parts"):
		# Training sword rests against the dummy surface; it never penetrates it.
		sword.freeze = true
		sword.linear_velocity = Vector3.ZERO
		sword.angular_velocity = Vector3.ZERO
		sword.collision_layer = 0
		sword.collision_mask = 0
		sword.reparent(other, true)


func _setup_xr() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	if openxr == null:
		push_warning("OpenXR interface is unavailable. Starting desktop preview.")
		_setup_desktop_preview()
		return

	if not openxr.is_initialized() and not openxr.initialize():
		push_warning("OpenXR could not be initialized. Starting desktop preview.")
		_setup_desktop_preview()
		return

	if not openxr.is_initialized():
		push_warning("OpenXR is not initialized. Starting desktop preview.")
		_setup_desktop_preview()
		return

	xr_active = true
	get_viewport().use_xr = true

	xr_origin = XROrigin3D.new()
	xr_origin.name = "XROrigin3D"
	add_child(xr_origin)

	xr_camera = XRCamera3D.new()
	xr_camera.name = "XRCamera3D"
	xr_origin.add_child(xr_camera)

	left_controller = _create_controller(xr_origin, "LeftController", "left_hand")
	left_hand = _create_hand_model(left_controller, "LeftLowPolyHand", Color(0.78, 0.62, 0.49), true)
	hand_finger_nodes[left_controller.get_instance_id()] = _get_finger_nodes(left_hand)
	_add_hand_collider(left_controller, "LeftHandCollider")
	right_controller = _create_controller(xr_origin, "RightController", "right_hand")
	right_hand = _create_hand_model(right_controller, "RightLowPolyHand", Color(0.78, 0.62, 0.49), false)
	hand_finger_nodes[right_controller.get_instance_id()] = _get_finger_nodes(right_hand)
	_add_hand_collider(right_controller, "RightHandCollider")


func _create_controller(parent: Node3D, node_name: String, tracker_name: String) -> XRController3D:
	var controller := XRController3D.new()
	controller.name = node_name
	controller.tracker = StringName(tracker_name)
	parent.add_child(controller)
	return controller


func _setup_desktop_preview() -> void:
	var camera := Camera3D.new()
	camera.name = "DesktopPreviewCamera"
	camera.position = Vector3(0.0, 1.65, 3.6)
	camera.look_at(Vector3(0.0, 0.9, -1.0), Vector3.UP)
	add_child(camera)
	camera.current = true


func _create_hand_model(parent: Node3D, hand_name: String, skin_color: Color, is_left: bool) -> Node3D:
	var hand := Node3D.new()
	hand.name = hand_name
	parent.add_child(hand)

	var skin := StandardMaterial3D.new()
	skin.albedo_color = skin_color
	skin.roughness = 0.9

	_add_hand_box(hand, "Palm", Vector3(0.0, 0.0, -0.045), Vector3(0.085, 0.025, 0.105), skin)

	var finger_offsets := [
		Vector3(-0.032, 0.0, -0.105), Vector3(-0.011, 0.0, -0.112),
		Vector3(0.011, 0.0, -0.108), Vector3(0.032, 0.0, -0.096)
	]
	var finger_lengths := [0.060, 0.075, 0.068, 0.052]
	for i in range(finger_offsets.size()):
		var finger := Node3D.new()
		finger.name = "Finger%d" % i
		finger.position = finger_offsets[i]
		hand.add_child(finger)
		var proximal_length: float = finger_lengths[i] * 0.58
		_add_hand_box(finger, "ProximalMesh", Vector3(0.0, 0.0, -proximal_length * 0.5), Vector3(0.014, 0.014, proximal_length), skin)
		var distal := Node3D.new()
		distal.name = "DistalJoint"
		distal.position = Vector3(0.0, 0.0, -proximal_length)
		finger.add_child(distal)
		_add_hand_box(distal, "DistalMesh", Vector3(0.0, 0.0, -finger_lengths[i] * 0.21), Vector3(0.012, 0.012, finger_lengths[i] * 0.42), skin)
	var side := -1.0 if is_left else 1.0
	hand.rotation_degrees.z = side * 90.0
	var thumb := Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(side * 0.052, 0.018, -0.035)
	thumb.rotation_degrees = Vector3(30.0, -side * 30.0, 0.0)
	hand.add_child(thumb)
	_add_hand_box(thumb, "ThumbBase", Vector3(0.0, 0.0, -0.025), Vector3(0.019, 0.018, 0.055), skin)
	var thumb_tip := Node3D.new()
	thumb_tip.name = "ThumbTipJoint"
	thumb_tip.position = Vector3(0.0, 0.0, -0.052)
	thumb.add_child(thumb_tip)
	_add_hand_box(thumb_tip, "ThumbTip", Vector3(0.0, 0.0, -0.018), Vector3(0.016, 0.016, 0.036), skin)
	return hand


func _get_finger_nodes(hand: Node3D) -> Dictionary:
	var result: Dictionary = {}
	var names := ["index", "middle", "ring", "pinky"]
	for i in range(names.size()):
		var root: Node3D = hand.get_node("Finger%d" % i)
		result[names[i]] = {"base": root, "tip": root.get_node("DistalJoint")}
	var thumb: Node3D = hand.get_node("Thumb")
	result["thumb"] = {"base": thumb, "tip": thumb.get_node("ThumbTipJoint")}
	return result


func _update_hand_fingers(controller: XRController3D) -> void:
	if controller == null:
		return
	var controller_id := controller.get_instance_id()
	if not hand_finger_nodes.has(controller_id):
		return
	var fingers: Dictionary = hand_finger_nodes[controller_id]
	var trigger_value := maxf(controller.get_float("trigger"), 1.0 if controller.is_button_pressed("trigger_click") else 0.0)
	var grip_value := maxf(controller.get_float("grip"), 1.0 if controller.is_button_pressed("grip_click") else 0.0)
	var thumb_touch := _controller_touch(controller, ["thumbstick_touch", "primary_touch", "secondary_touch", "ax_touch", "by_touch"])
	_set_finger_curl(fingers["index"], clampf(trigger_value, 0.0, 1.0))
	for name in ["middle", "ring", "pinky"]:
		_set_finger_curl(fingers[name], clampf(grip_value, 0.0, 1.0))
	_set_finger_curl(fingers["thumb"], thumb_touch)


func _controller_touch(controller: XRController3D, actions: Array) -> float:
	var amount := 0.0
	for action in actions:
		amount = maxf(amount, controller.get_float(StringName(action)))
		if controller.is_button_pressed(StringName(action)):
			amount = 1.0
	return clampf(amount, 0.0, 1.0)


func _set_finger_curl(joints: Dictionary, amount: float) -> void:
	var base: Node3D = joints["base"]
	var tip: Node3D = joints["tip"]
	# Positive local X folds the fingers toward the palm.
	base.rotation.x = lerpf(0.0, 1.28, amount)
	tip.rotation.x = lerpf(0.0, 1.18, amount)


func _constrain_hand_to_table(controller: XRController3D, hand: Node3D) -> void:
	if controller == null or hand == null:
		return
	var hand_position := controller.global_position
	# Constrain the virtual palm and its collider above the tabletop.
	var inside_table_x := absf(hand_position.x) <= 1.02
	var inside_table_z := absf(hand_position.z + 1.25) <= 0.56
	if inside_table_x and inside_table_z:
		hand_position.y = maxf(hand_position.y, 0.91)
	hand.global_position = hand_position
	var collider := controller.get_node_or_null("LeftHandCollider")
	if collider == null:
		collider = controller.get_node_or_null("RightHandCollider")
	if collider is Node3D:
		(collider as Node3D).global_position = hand_position


func _controller_hand_position(controller: XRController3D) -> Vector3:
	var hand := controller.get_node_or_null("LeftLowPolyHand")
	if hand == null:
		hand = controller.get_node_or_null("RightLowPolyHand")
	if hand is Node3D:
		return (hand as Node3D).global_position
	return controller.global_position


func _add_hand_box(parent: Node3D, node_name: String, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part


func _add_hand_collider(parent: XRController3D, collider_name: String) -> void:
	var physical_hand := AnimatableBody3D.new()
	physical_hand.name = collider_name
	physical_hand.sync_to_physics = true
	physical_hand.collision_layer = 1
	physical_hand.collision_mask = 1
	physical_hand.rotation_degrees.z = -90.0 if collider_name.begins_with("Left") else 90.0
	parent.add_child(physical_hand)
	_add_hand_sphere(physical_hand, Vector3(0.0, -0.005, -0.055), 0.105)
	_add_hand_sphere(physical_hand, Vector3(-0.045, 0.0, -0.145), 0.045)
	_add_hand_sphere(physical_hand, Vector3(0.0, 0.0, -0.16), 0.045)
	_add_hand_sphere(physical_hand, Vector3(0.045, 0.0, -0.145), 0.045)


func _add_hand_sphere(parent: AnimatableBody3D, at: Vector3, radius: float) -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	collision.position = at
	parent.add_child(collision)


func _create_energy_launcher(at: Vector3) -> void:
	var body := RigidBody3D.new()
	body.name = "EnergyOrbLauncher"
	body.position = at
	body.mass = 0.55
	body.gravity_scale = 0.0
	body.add_to_group("grabbable")
	add_child(body)

	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color(0.16, 0.18, 0.22)
	dark_material.metallic = 0.45
	dark_material.roughness = 0.35
	var glow_material := StandardMaterial3D.new()
	glow_material.albedo_color = Color(0.12, 0.85, 1.0)
	glow_material.emission_enabled = true
	glow_material.emission = Color(0.05, 0.65, 1.0)
	glow_material.emission_energy_multiplier = 1.6

	_add_launcher_box(body, "Grip", Vector3(0.0, -0.055, 0.0), Vector3(0.075, 0.16, 0.075), dark_material)
	_add_launcher_box(body, "Body", Vector3(0.0, 0.045, -0.015), Vector3(0.12, 0.10, 0.20), dark_material)
	_add_launcher_box(body, "EnergyBarrel", Vector3(0.0, 0.045, -0.16), Vector3(0.065, 0.065, 0.18), glow_material)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.13, 0.25, 0.38)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.015, -0.07)
	body.add_child(collision)


func _add_launcher_box(parent: Node3D, part_name: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)


func _create_training_dummy(at: Vector3) -> void:
	var platform := StaticBody3D.new()
	platform.name = "DummyPlatform"
	platform.position = at
	add_child(platform)
	var platform_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.48
	cylinder.bottom_radius = 0.48
	cylinder.height = 0.12
	platform_mesh.mesh = cylinder
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.22, 0.25, 0.29)
	platform_material.metallic = 0.35
	platform_mesh.material_override = platform_material
	platform_mesh.position.y = 0.06
	platform.add_child(platform_mesh)
	var platform_shape := CollisionShape3D.new()
	var platform_cylinder := CylinderShape3D.new()
	platform_cylinder.radius = 0.48
	platform_cylinder.height = 0.12
	platform_shape.shape = platform_cylinder
	platform_shape.position.y = 0.06
	platform.add_child(platform_shape)
	var torso := _create_dummy_part("DummyTorso", at + Vector3(0.0, 1.25, 0.0), Vector3(0.32, 0.52, 0.20), 2.0)
	var head := _create_dummy_part("DummyHead", at + Vector3(0.0, 1.67, 0.0), Vector3(0.24, 0.24, 0.24), 0.7)
	var left_arm := _create_dummy_part("DummyLeftArm", at + Vector3(-0.28, 1.30, 0.0), Vector3(0.13, 0.48, 0.14), 0.65)
	var right_arm := _create_dummy_part("DummyRightArm", at + Vector3(0.28, 1.30, 0.0), Vector3(0.13, 0.48, 0.14), 0.65)
	_create_dummy_joint("DummyHeadJoint", torso, head, at + Vector3(0.0, 1.52, 0.0))
	_create_dummy_joint("DummyLeftShoulder", torso, left_arm, at + Vector3(-0.19, 1.48, 0.0))
	_create_dummy_joint("DummyRightShoulder", torso, right_arm, at + Vector3(0.19, 1.48, 0.0))


func _create_dummy_part(part_name: String, at: Vector3, dimensions: Vector3, body_mass: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = part_name
	body.position = at
	body.mass = body_mass
	body.gravity_scale = 0.65
	body.linear_damp = 1.2
	body.angular_damp = 2.0
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("grabbable")
	body.add_to_group("dummy_parts")
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.58, 0.64, 0.70)
	material.metallic = 0.12
	material.roughness = 0.72
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	return body


func _create_dummy_joint(joint_name: String, body_a: RigidBody3D, body_b: RigidBody3D, at: Vector3) -> void:
	var joint := PinJoint3D.new()
	joint.name = joint_name
	add_child(joint)
	joint.global_position = at
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)


func _shoot_energy_orb(launcher: RigidBody3D) -> void:
	var orb := RigidBody3D.new()
	orb.name = "EnergyOrb"
	orb.mass = 0.025
	orb.gravity_scale = 0.0
	orb.continuous_cd = true
	orb.contact_monitor = true
	orb.max_contacts_reported = 4
	orb.collision_layer = 1
	orb.collision_mask = 1
	orb.add_to_group("projectiles")
	add_child(orb)

	var muzzle := launcher.to_global(Vector3(0.0, 0.045, -0.265))
	var direction := -launcher.global_basis.z.normalized()
	orb.global_position = muzzle + direction * 0.045

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.022
	sphere.height = 0.044
	mesh_instance.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.035, 0.025)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.015, 0.005)
	material.emission_energy_multiplier = 1.8
	mesh_instance.material_override = material
	orb.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.022
	collision.shape = sphere_shape
	orb.add_child(collision)

	orb.body_entered.connect(_on_energy_orb_body_entered.bind(orb))
	get_tree().create_timer(4.0).timeout.connect(_remove_energy_orb.bind(orb))
	orb.linear_velocity = direction * ORB_SPEED


func _on_energy_orb_body_entered(other: Node, orb: RigidBody3D) -> void:
	if is_instance_valid(other) and other is RigidBody3D and not other.is_in_group("projectiles"):
		var target := other as RigidBody3D
		if not target.freeze:
			target.apply_central_impulse(orb.linear_velocity.normalized() * 0.42)
	_remove_energy_orb(orb)


func _remove_energy_orb(orb: RigidBody3D) -> void:
	if is_instance_valid(orb):
		orb.queue_free()


func _update_controller_interaction(controller: XRController3D) -> void:
	if controller == null:
		return

	var controller_id := controller.get_instance_id()
	var grip_pressed := controller.get_float("grip") > 0.55 or controller.is_button_pressed("grip_click")
	var was_pressed: bool = previous_grip.get(controller_id, false)
	var held_data: Dictionary = held_by_controller.get(controller_id, {})
	var trigger_pressed := controller.get_float("trigger") > 0.65 or controller.is_button_pressed("trigger_click")
	var was_trigger: bool = previous_trigger.get(controller_id, false)
	if trigger_pressed and not was_trigger and not held_data.is_empty():
		var held_object: Node = held_data.get("body")
		if is_instance_valid(held_object) and held_object.name == "EnergyOrbLauncher":
			_shoot_energy_orb(held_object as RigidBody3D)
	previous_trigger[controller_id] = trigger_pressed

	if grip_pressed and not was_pressed and held_data.is_empty():
		_try_grab_nearest(controller, controller_id)
		held_data = held_by_controller.get(controller_id, {})

	if not grip_pressed and was_pressed and not held_data.is_empty():
		_release_held(controller_id)
		held_data = {}

	if not held_data.is_empty():
		var held_body: RigidBody3D = held_data.get("body")
		if is_instance_valid(held_body):
			var target_transform: Transform3D = controller.global_transform * held_data.get("offset", Transform3D.IDENTITY)
			var old_position: Vector3 = held_data.get("last_position", held_body.global_position)
			held_data["throw_velocity"] = (target_transform.origin - old_position) / maxf(get_process_delta_time(), 0.001)
			held_data["last_position"] = target_transform.origin
			held_body.global_transform = target_transform
			held_by_controller[controller_id] = held_data

	previous_grip[controller_id] = grip_pressed


func _try_grab_nearest(controller: XRController3D, controller_id: int) -> void:
	var nearest: RigidBody3D
	var nearest_distance := GRAB_DISTANCE

	for node in get_tree().get_nodes_in_group("grabbable"):
		if not node is RigidBody3D:
			continue
		var candidate := node as RigidBody3D
		if candidate.freeze:
			continue
		var hand_position := _controller_hand_position(controller)
		var distance := hand_position.distance_to(candidate.global_position)
		if candidate.name == "GripTestRod":
			var rod_axis := candidate.global_basis.y.normalized()
			var from_center := controller.global_position - candidate.global_position
			var along := clampf(from_center.dot(rod_axis), -0.31, 0.31)
			var closest_point := candidate.global_position + rod_axis * along
			distance = hand_position.distance_to(closest_point)
		elif candidate.name == "EnergyOrbLauncher":
			distance = _distance_to_local_box(hand_position, candidate.global_transform, Vector3(0.045, 0.085, 0.045), Vector3(0.0, -0.055, 0.0))
		elif candidate.name == "TrainingSword":
			distance = _distance_to_local_box(hand_position, candidate.global_transform, Vector3(0.04, 0.04, 0.11), Vector3(0.0, 0.0, 0.19))
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance

	if nearest == null:
		return

	nearest.freeze = true
	nearest.sleeping = true
	nearest.linear_velocity = Vector3.ZERO
	nearest.angular_velocity = Vector3.ZERO
	var relative_transform: Transform3D = controller.global_transform.affine_inverse() * nearest.global_transform
	held_by_controller[controller_id] = {"body": nearest, "offset": relative_transform, "last_position": nearest.global_position, "throw_velocity": Vector3.ZERO}


func _distance_to_local_box(world_point: Vector3, object_transform: Transform3D, half_extents: Vector3, local_center: Vector3 = Vector3.ZERO) -> float:
	var local_point := object_transform.affine_inverse() * world_point - local_center
	var closest := Vector3(
		clampf(local_point.x, -half_extents.x, half_extents.x),
		clampf(local_point.y, -half_extents.y, half_extents.y),
		clampf(local_point.z, -half_extents.z, half_extents.z)
	)
	return local_point.distance_to(closest)


func _release_held(controller_id: int) -> void:
	var held_data: Dictionary = held_by_controller.get(controller_id, {})
	var body: RigidBody3D = held_data.get("body")
	if is_instance_valid(body):
		body.freeze = false
		body.gravity_scale = 1.0
		var throw_velocity: Vector3 = held_data.get("throw_velocity", Vector3.ZERO)
		body.linear_velocity = throw_velocity.limit_length(5.0) + Vector3.UP * 0.35
		body.sleeping = false
	held_by_controller.erase(controller_id)


func _move_player(delta: float) -> void:
	if left_controller == null or xr_origin == null or xr_camera == null:
		return

	var stick := left_controller.get_vector2("primary")
	if stick.length() < 0.05:
		stick = left_controller.get_vector2("thumbstick")
	if stick.length() < 0.08:
		return

	var forward := -xr_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := xr_camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var movement := (forward * stick.y + right * stick.x).limit_length(1.0)
	var requested_motion := movement * MOVE_SPEED * delta
	var body_shape := SphereShape3D.new()
	body_shape.radius = 0.22
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body_shape
	query.transform = Transform3D(Basis.IDENTITY, xr_origin.global_position + Vector3.UP * 0.92)
	query.motion = requested_motion
	query.collision_mask = 1
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	var safe_fraction := 1.0
	if fractions.size() >= 1:
		safe_fraction = clampf(fractions[0] - 0.025, 0.0, 1.0)
	xr_origin.global_position += requested_motion * safe_fraction
