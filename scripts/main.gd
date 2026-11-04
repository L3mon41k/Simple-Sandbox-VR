extends Node3D

const FLOOR_SIZE := Vector3(12.0, 0.2, 12.0)
const CUBE_SIZE := Vector3(0.22, 0.22, 0.22)

var xr_active := false
var left_hand: Node3D
var right_hand: Node3D


func _ready() -> void:
	_build_environment()
	_setup_xr()


func _build_environment() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = FLOOR_SIZE
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.1
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.22, 0.24, 0.27)
	floor_mesh.material_override = floor_material
	floor_body.add_child(floor_mesh)

	var floor_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = FLOOR_SIZE
	floor_shape.shape = box_shape
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)

	_create_cube(Vector3(-0.35, 1.0, -1.2), Color(0.85, 0.16, 0.13), "RedCube")
	_create_cube(Vector3(0.35, 1.0, -1.2), Color(0.12, 0.38, 0.9), "BlueCube")


func _create_cube(at: Vector3, tint: Color, object_name: String) -> void:
	var body := RigidBody3D.new()
	body.name = object_name
	body.position = at
	body.mass = 0.5
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = CUBE_SIZE
	mesh_instance.mesh = cube_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.72
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = CUBE_SIZE
	collision.shape = shape
	body.add_child(collision)


func _setup_xr() -> void:
	var openxr := XRServer.find_interface("OpenXR")
	if openxr == null:
		_setup_desktop_preview()
		return

	if not openxr.initialize():
		push_warning("OpenXR could not be initialized. Starting desktop preview.")
		_setup_desktop_preview()
		return

	xr_active = true
	get_viewport().use_xr = true

	var origin := XROrigin3D.new()
	origin.name = "XROrigin3D"
	add_child(origin)

	var camera := XRCamera3D.new()
	camera.name = "XRCamera3D"
	origin.add_child(camera)

	var left_controller := _create_controller(origin, "LeftController", "left_hand")
	left_hand = _create_hand_model(left_controller, "LeftLowPolyHand", Color(0.78, 0.62, 0.49))
	var right_controller := _create_controller(origin, "RightController", "right_hand")
	right_hand = _create_hand_model(right_controller, "RightLowPolyHand", Color(0.78, 0.62, 0.49))


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


func _create_hand_model(parent: Node3D, hand_name: String, skin_color: Color) -> Node3D:
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

	var thumb := Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(-0.052, 0.0, -0.035)
	thumb.rotation_degrees.y = -28.0
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
