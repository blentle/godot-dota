extends RefCounted
## 将经典 Geoset 矩阵组映射为 Godot 骨骼蒙皮；保留全部组权重，不截断五骨头像。

static func create(data: Dictionary, bone_ids: Dictionary, skin: Skin, material: Material) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var eight := false
	for group in data.Groups:
		if group.size() > 4: eight = true
	var count := 8 if eight else 4
	for index in range(data.Vertices.size() / 3):
		vertices.append(Vector3(data.Vertices[index*3], data.Vertices[index*3+1], data.Vertices[index*3+2]))
		normals.append(Vector3(data.Normals[index*3], data.Normals[index*3+1], data.Normals[index*3+2]))
		uv.append(Vector2(data.TVertices[0][index*2], data.TVertices[0][index*2+1]))
		var group: Array = data.Groups[int(data.VertexGroup[index])]
		assert(group.size() <= count, "源模型骨骼组超出当前八权重支持范围")
		for part in range(count):
			bones.append(int(bone_ids.get(int(group[part]), 0)) if part < group.size() else 0)
			weights.append(1.0 / group.size() if part < group.size() else 0.0)
	var faces := PackedInt32Array()
	# 原 MDX 三角形与外法线为逆时针；Godot 正面为顺时针，因此交换后两个索引。
	for index in range(0, data.Faces.size(), 3):
		faces.append(int(data.Faces[index]))
		faces.append(int(data.Faces[index+2]))
		faces.append(int(data.Faces[index+1]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if eight else 0)
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.skin = skin
	result.skeleton = NodePath("../Skeleton")
	result.material_override = material
	return result
