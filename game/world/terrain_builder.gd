extends Node3D
## 地形构建器：只生成场景，并向规则层登记静态障碍。

const Geometry = preload("res://presentation/mesh_factory.gd")
var geometry := Geometry.new()
var rng := RandomNumberGenerator.new()
var simulation: RefCounted
var building_views: Dictionary = {}

func build(world: RefCounted) -> void:
	simulation = world
	rng.seed = 683
	_build_lighting()
	_build_terrain()

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("151d20")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b4c5d0")
	settings.ambient_light_energy = 0.32
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -28, 0)
	sun.light_color = Color("ffe4b5")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)

func _build_terrain() -> void:
	# 连续苔地纹理避免棋盘格和地图边缘空白。
	var noise := FastNoiseLite.new()
	noise.seed = 683
	noise.frequency = 0.025
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color("253a28"))
	ramp.set_color(1, Color("526447"))
	texture.color_ramp = ramp
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = texture
	ground_material.uv1_scale = Vector3(5, 5, 1)
	ground_material.roughness = 1.0
	var ground := PlaneMesh.new()
	ground.size = Vector2(220, 220)
	var ground_node := geometry.mesh(self, ground, Vector3(0, -0.04, 0), Color.WHITE)
	ground_node.material_override = ground_material
	for edge in [-1, 1]:
		geometry.box(self, Vector3(edge * 49, 0.25, 0), Vector3(0.8, 0.6, 98), Color("4c5648"))
		geometry.box(self, Vector3(0, 0.25, edge * 49), Vector3(98, 0.6, 0.8), Color("4c5648"))
	# 三条示意通路用于验证操作和寻路，尚非原版地图。
	_lane([Vector3(-37, 0, 37), Vector3(-37, 0, -37), Vector3(37, 0, -37)])
	_lane([Vector3(-37, 0, 37), Vector3(37, 0, -37)])
	_lane([Vector3(-37, 0, 37), Vector3(37, 0, 37), Vector3(37, 0, -37)])
	var river := geometry.box(self, Vector3(0, 0.035, 0), Vector3(126, 0.08, 5.4), Color("416c72"))
	river.rotation.y = -PI / 4
	for index in range(7):
		var ripple := geometry.box(self, Vector3(-2.2 + index * 0.7, 0.085, 0), Vector3(125, 0.012, 0.09), Color("648f91"))
		ripple.rotation.y = -PI / 4
	for at in [Vector3(-37, 0, -37), Vector3.ZERO, Vector3(37, 0, 37)]:
		var bridge := geometry.box(self, at + Vector3(0, 0.14, 0), Vector3(7, 0.25, 6), Color("8b8770"))
		bridge.rotation.y = PI / 4
	for index in range(330):
		var at := Vector3(rng.randf_range(-46, 46), 0, rng.randf_range(-46, 46))
		if absf(at.x + at.z) < 6 or absf(at.x - at.z) < 5 or absf(absf(at.x) - 37) < 5 or absf(absf(at.z) - 37) < 5:
			continue
		if at.distance_to(simulation.position) < 7 or at.distance_to(Vector3(-29, 0, 24)) < 5:
			continue
		_tree(at)
	for side in [-1, 1]:
		var color := Color("7eaaad") if side == -1 else Color("b66f57")
		var base := Vector3(side * 37, 0, -side * 37)
		var first := get_child_count()
		geometry.cylinder(self, base, 5.5, 0.4, Color("636a58"))
		geometry.box(self, base + Vector3(0, 2, 0), Vector3(3.8, 4, 3.8), color.darkened(0.35))
		geometry.cylinder(self, base + Vector3(0, 5.6, 0), 2.8, 3.8, color, 0)
		_group_building(base, first)
		simulation.block(base, 3)
		for at in [Vector3(side * 37, 0, -side * 20), Vector3(side * 20, 0, -side * 37), Vector3(side * 20, 0, -side * 20)]:
			_tower(at, color)
	for index in range(36):
		var at := Vector3(rng.randf_range(-44, 44), 0, rng.randf_range(-44, 44))
		if absf(at.x + at.z) > 9 and absf(at.x - at.z) > 7:
			var rock := geometry.cylinder(self, at + Vector3(0, 0.5, 0), rng.randf_range(0.4, 1), 1.3, Color("646e61"), 0.3)
			rock.rotation.z = 0.3

func _lane(points: Array) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var road := geometry.box(self, (a + b) / 2 + Vector3(0, 0.015, 0), Vector3(4.8, 0.06, a.distance_to(b)), Color("7b795a"))
		road.rotation.y = atan2(b.x - a.x, b.z - a.z)

func _tree(at: Vector3) -> void:
	var height := rng.randf_range(3.2, 5.5)
	geometry.cylinder(self, at + Vector3(0, 1, 0), 0.25, 2, Color("514735"), 0.18)
	var color := Color("294d31") if at.x < at.z else Color("3b4840")
	for tier in range(3):
		geometry.cylinder(self, at + Vector3(0, height * 0.5 + tier * 0.8, 0), 1.7 - tier * 0.35, height * 0.65, color.lightened(tier * 0.025), 0.1)
	simulation.block(at)

func _tower(at: Vector3, color: Color) -> void:
	var first := get_child_count()
	geometry.cylinder(self, at + Vector3(0, 0.3, 0), 1.9, 0.6, Color("7c7c69"))
	geometry.cylinder(self, at + Vector3(0, 2, 0), 1.1, 3.4, Color("787d70"), 0.85)
	geometry.cylinder(self, at + Vector3(0, 3.8, 0), 1.5, 0.7, color)
	for i in range(6):
		var angle := i * TAU / 6
		geometry.box(self, at + Vector3(cos(angle) * 1.1, 4.4, sin(angle) * 1.1), Vector3(0.5, 0.65, 0.5), color)
	_group_building(at, first)
	simulation.block(at, 2)


func _group_building(at: Vector3, first: int) -> void:
	var parts := get_children().slice(first)
	var root := Node3D.new()
	add_child(root)
	root.position = at
	for part in parts: part.reparent(root)
	building_views[at] = root
