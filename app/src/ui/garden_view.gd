class_name GardenView
extends SubViewportContainer

var stage: String = "seed"
var reduced_motion: bool = true
var _recipe: Dictionary = {}
var _viewport: SubViewport
var _world: Node3D
var _plant: Node3D
var _camera: Camera3D
var _yaw: float = 0.0
var _distance: float = 3.0
var _elapsed: float = 0.0

func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 280)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(342, 280)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("e9efe3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.45
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 0.85
	_world.add_child(light)
	_camera = Camera3D.new()
	_camera.fov = 35
	_world.add_child(_camera)
	var terrain := CylinderMesh.new()
	terrain.top_radius = 0.76
	terrain.bottom_radius = 0.65
	terrain.height = 0.17
	_mesh(_world, terrain, Color("cfa585"), Vector3(0, 0.09, 0))
	var soil := CylinderMesh.new()
	soil.top_radius = 0.74
	soil.bottom_radius = 0.74
	soil.height = 0.025
	_mesh(_world, soil, Color("dcbf9f"), Vector3(0, 0.19, 0))
	_plant = Node3D.new()
	_world.add_child(_plant)
	gui_input.connect(_on_input)
	_rebuild()
	_update_camera()

func show_recipe(recipe: Dictionary, next_stage: String = "seed") -> void:
	_recipe = recipe
	stage = next_stage
	if is_node_ready():
		_rebuild()

func turn(amount: float) -> void:
	_yaw = clampf(_yaw + amount, -55.0, 55.0)
	_update_camera()

func zoom(amount: float) -> void:
	_distance = clampf(_distance + amount, 2.3, 4.0)
	_update_camera()

func reset_camera() -> void:
	_yaw = 0.0
	_distance = 3.0
	_update_camera()

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if is_instance_valid(_plant):
		_plant.rotation.y = 0

func _process(delta: float) -> void:
	if not reduced_motion and is_instance_valid(_plant):
		_elapsed += delta
		_plant.rotation.y = sin(_elapsed * 0.6) * 0.025

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != -1 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		turn(-event.relative.x * 0.25)
	elif event is InputEventScreenDrag:
		turn(-event.relative.x * 0.25)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-0.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(0.15)

func _update_camera() -> void:
	if not is_instance_valid(_camera):
		return
	var angle: float = deg_to_rad(_yaw)
	_camera.position = Vector3(sin(angle) * _distance, 1.6, cos(angle) * _distance)
	_camera.look_at(Vector3(0, 0.55, 0), Vector3.UP)

func _rebuild() -> void:
	for child: Node in _plant.get_children():
		_plant.remove_child(child)
		child.queue_free()
	var families: Dictionary = _recipe.get("family_weights", {})
	var affection: float = families.get("afe", 0.0)
	if stage == "seed":
		var seed := SphereMesh.new()
		seed.radius = 0.24
		seed.height = 0.66
		var seed_node: MeshInstance3D = _mesh(_plant, seed, Color("977451").lerp(Color("c9a77b"), affection), Vector3(0, 0.53, 0))
		seed_node.rotation.z = -0.15
		var ids: Array = _recipe.get("selected_union", [])
		for i: int in range(ids.size()):
			var dot := SphereMesh.new()
			dot.radius = 0.015
			dot.height = 0.03
			var angle: float = -0.75 + float(i % 4) * 0.5
			var y: float = 0.37 + floorf(float(i) / 4.0) * 0.11
			_mesh(_plant, dot, Color("f3dfbc"), Vector3(sin(angle) * 0.20, y, cos(angle) * 0.24))
	else:
		var stem := CylinderMesh.new()
		stem.top_radius = 0.035
		stem.bottom_radius = 0.045
		stem.height = 0.57
		var stem_node: MeshInstance3D = _mesh(_plant, stem, Color("3e684a"), Vector3(0, 0.48, 0))
		stem_node.rotation.z = -0.10
		for side: int in [-1, 1]:
			var leaf := SphereMesh.new()
			leaf.radius = 0.16
			leaf.height = 0.32
			var leaf_node: MeshInstance3D = _mesh(_plant, leaf, Color("7fa168").lerp(Color("b6c58f"), affection + (0.15 if side == 1 else 0.0)), Vector3(side * 0.16, 0.69 + (0.10 if side == 1 else 0.0), 0))
			leaf_node.scale = Vector3(1.6, 0.27, 0.8)
			leaf_node.rotation.z = side * 0.45

func _mesh(parent: Node3D, shape: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	node.material_override = material
	parent.add_child(node)
	return node
