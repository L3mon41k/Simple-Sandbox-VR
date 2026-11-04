extends Node3D

const FLOOR_SIZE := Vector3(12.0, 0.2, 12.0)
const CUBE_SIZE := Vector3(0.17, 0.17, 0.17)
const MOVE_SPEED := 2.0
const GRAB_DISTANCE := 0.38
const HAND_PUSH_RADIUS := 0.075
const ORB_SPEED := 7.0

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


func _ready() -> void:
	_build_environment()
	_build_world()
	_setup_xr()


func _process(delta: float) -> void:
	if not xr_active:
		return
	_update_controller_interaction(left_controller)
	_update_controller_interaction(right_controller)
	_move_player(delta)


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
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.8
	sun.shadow_blur = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 24.0
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

	_create_cube(Vector3(-0.32, 1.35, -1.2), Color(0.92, 0.12, 0.10), "RedCube")
	_create_cube(Vector3(0.32, 1.75, -1.2), Color(0.08, 0.30, 0.96), "BlueCube")
	_create_test_rod(Vector3(0.72, 1.25, -1.1))
	_create_energy_launcher(Vector3(-0.72, 1.25, -1.1))


func _create_cube(at: Vector3, tint: Color, object_name: String) -> void:
	var body := RigidBody3D.new()
	body.name = object_name
	body.position = at
	body.mass = 0.35
	body.gravity_scale = 0.0
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


func _create_test_rod(at: Vector3) -> void:
	# A plain wooden test prop for checking grabbing and physics; it is not a weapon.
	var body := RigidBody3D.new()
	body.name = "GripTestRod"
	body.position = at
	body.mass = 0.45
	body.gravity_scale = 0.0
	body.add_to_group("grabbable")
	add_child(body)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.48, 0.29, 0.14)
	wood.roughness = 0.9

	var rod_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.025
	cylinder.bottom_radius = 0.025
	cylinder.height = 0.62
	rod_mesh.mesh = cylinder
	rod_mesh.material_override = wood
	body.add_child(rod_mesh)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.025
	shape.height = 0.62
	collision.shape = shape
	body.add_child(collision)


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
	_add_hand_collider(left_controller, "LeftHandCollider")
	right_controller = _create_controller(xr_origin, "RightController", "right_hand")
	right_hand = _create_hand_model(right_controller, "RightLowPolyHand", Color(0.78, 0.62, 0.49), false)
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
		Vector3(-0.032, 0.0, -0.105),
		Vector3(-0.011, 0.0, -0.112),
		Vector3(0.011, 0.0, -0.108),
		Vector3(0.032, 0.0, -0.096)
	]
	var finger_lengths := [0.060, 0.075, 0.068, 0.052]
	for i in range(finger_offsets.size()):
		var finger := Node3D.new()
		finger.name = "Finger%d" % i
		finger.position = finger_offsets[i]
		hand.add_child(finger)
		_add_hand_box(finger, "Proximal", Vector3(0.0, 0.0, -finger_lengths[i] * 0.25), Vector3(0.014, 0.014, finger_lengths[i] * 0.5), skin)
		_add_hand_box(finger, "Distal", Vector3(0.0, 0.0, -finger_lengths[i] * 0.72), Vector3(0.012, 0.012, finger_lengths[i] * 0.42), skin)

	var side := -1.0 if is_left else 1.0
	var thumb := Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(side * 0.052, 0.018, -0.035)
	thumb.rotation_degrees.x = 90.0
	thumb.rotation_degrees.z = side * 18.0
	hand.add_child(thumb)
	_add_hand_box(thumb, "ThumbBase", Vector3(0.0, 0.0, -0.025), Vector3(0.019, 0.018, 0.055), skin)
	_add_hand_box(thumb, "ThumbTip", Vector3(0.0, 0.0, -0.060), Vector3(0.016, 0.016, 0.035), skin)

	return hand


func _add_hand_box(parent: Node3D, node_name: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)


func _add_hand_collider(parent: XRController3D, collider_name: String) -> void:
	var physical_hand := AnimatableBody3D.new()
	physical_hand.name = collider_name
	physical_hand.sync_to_physics = true
	parent.add_child(physical_hand)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = HAND_PUSH_RADIUS
	collision.shape = shape
	collision.position = Vector3(0.0, -0.015, -0.075)
	physical_hand.add_child(collision)


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


func _shoot_energy_orb(controller: XRController3D) -> void:
	var orb := RigidBody3D.new()
	orb.name = "EnergyOrb"
	orb.mass = 0.08
	orb.gravity_scale = 0.0
	orb.continuous_cd = true
	add_child(orb)
	orb.global_position = controller.global_position + (-controller.global_basis.z * 0.24)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	mesh_instance.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.85, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.05, 0.55, 1.0)
	material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material
	orb.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.055
	collision.shape = sphere_shape
	orb.add_child(collision)
	orb.linear_velocity = -controller.global_basis.z * ORB_SPEED


func _update_controller_interaction(controller: XRController3D) -> void:
	if controller == null:
		return

	var controller_id := controller.get_instance_id()
	var grip_pressed := controller.get_float("grip") > 0.55 or controller.is_button_pressed("grip_click")
	var was_pressed: bool = previous_grip.get(controller_id, false)
	var trigger_pressed := controller.get_float("trigger") > 0.65 or controller.is_button_pressed("trigger_click")
	var was_trigger: bool = previous_trigger.get(controller_id, false)
	if trigger_pressed and not was_trigger and not held_data.is_empty():
		var held_object: Node = held_data.get("body")
		if is_instance_valid(held_object) and held_object.name == "EnergyOrbLauncher":
			_shoot_energy_orb(controller)
	previous_trigger[controller_id] = trigger_pressed
	var held_data: Dictionary = held_by_controller.get(controller_id, {})

	if grip_pressed and not was_pressed and held_data.is_empty():
		_try_grab_nearest(controller, controller_id)
		held_data = held_by_controller.get(controller_id, {})

	if not grip_pressed and was_pressed and not held_data.is_empty():
		_release_held(controller_id)
		held_data = {}

	if not held_data.is_empty():
		var held_body: RigidBody3D = held_data.get("body")
		if is_instance_valid(held_body):
			held_body.global_transform = controller.global_transform * held_data.get("offset", Transform3D.IDENTITY)

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
		var distance := controller.global_position.distance_to(candidate.global_position)
		if candidate.name == "GripTestRod":
			var rod_axis := candidate.global_basis.y.normalized()
			var from_center := controller.global_position - candidate.global_position
			var along := clampf(from_center.dot(rod_axis), -0.31, 0.31)
			var closest_point := candidate.global_position + rod_axis * along
			distance = controller.global_position.distance_to(closest_point)
		elif candidate.name == "EnergyOrbLauncher":
			distance = _distance_to_local_box(controller.global_position, candidate.global_transform, Vector3(0.075, 0.14, 0.20))
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
	held_by_controller[controller_id] = {"body": nearest, "offset": relative_transform}


func _distance_to_local_box(world_point: Vector3, object_transform: Transform3D, half_extents: Vector3) -> float:
	var local_point := object_transform.affine_inverse() * world_point
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
	var movement := (forward * -stick.y + right * stick.x).limit_length(1.0)
	xr_origin.global_position += movement * MOVE_SPEED * delta
