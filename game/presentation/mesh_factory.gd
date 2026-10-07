extends RefCounted
## 临时几何体工厂：集中创建与缓存开发场景材质。

var materials := {}

func material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.9
		materials[color] = result
	return materials[color]

func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = shape
	result.material_override = material(color)
	parent.add_child(result)
	result.position = at
	return result

func box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return mesh(parent, shape, at, color)

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = 10
	return mesh(parent, shape, at, color)
