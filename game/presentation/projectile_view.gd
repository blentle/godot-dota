extends Node3D
## 弹道视图只读取模拟坐标，不以动画结束或碰撞节点决定伤害。

var views: Dictionary = {}
var geometry := preload("res://presentation/mesh_factory.gd").new()

func sync(active: Dictionary) -> void:
	for id in views.keys():
		if not active.has(id):
			views[id].queue_free()
			views.erase(id)
	for id in active:
		var shot: Dictionary = active[id]
		if not views.has(id):
			var shape := SphereMesh.new()
			shape.radius = 0.22
			shape.height = 0.44
			views[id] = geometry.mesh(self, shape, shot.position,
				Color("b4e8ee") if shot.team == 0 else Color("ffb76b"))
		views[id].position = shot.position
