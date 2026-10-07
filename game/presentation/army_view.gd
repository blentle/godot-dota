extends Node3D
## 批量单位表现：按规则标识维护视图，建筑倒塌后保留矮墩作为障碍提示。

const UnitView = preload("res://presentation/unit_view.gd")
const Geometry = preload("res://presentation/mesh_factory.gd")
var views: Dictionary = {}
var buildings: Dictionary = {}
var bars: Dictionary = {}
var geometry := Geometry.new()
var rules: RefCounted
var flashes: Array[Dictionary] = []

func sync(combat: RefCounted, delta: float) -> void:
	rules = combat
	for index in range(flashes.size() - 1, -1, -1):
		flashes[index].remaining -= delta
		if flashes[index].remaining <= 0:
			flashes[index].view.queue_free()
			flashes.remove_at(index)
	for id in views.keys():
		if not combat.units.has(id):
			views[id].queue_free()
			views.erase(id)
	for unit in combat.units.values():
		if unit.kind in ["tower", "base"]:
			_sync_building(unit)
		elif unit.kind == "creep":
			if not views.has(unit.id):
				var view := UnitView.new()
				add_child(view)
				view.build(Color("7eaaad") if unit.team == 0 else Color("b66f57"))
				view.scale = Vector3.ONE * 0.65
				views[unit.id] = view
			var target: RefCounted = combat.units.get(unit.pending_target_id)
			views[unit.id].sync(unit, false, delta, target.position if target != null else unit.position)

func _sync_building(unit: RefCounted) -> void:
	if buildings.has(unit.position):
		buildings[unit.position].scale.y = 1.0 if unit.alive() else 0.12
	if not bars.has(unit.id):
		var bar := geometry.box(self, unit.position + Vector3(0, 7.8, 0), Vector3(3, 0.2, 0.2),
			Color("7ecb9a") if unit.team == 0 else Color("d8735d"))
		bars[unit.id] = bar
	bars[unit.id].visible = unit.alive()
	bars[unit.id].scale.x = maxf(0.001, unit.hp / unit.max_hp)

func react(event: Dictionary) -> void:
	var id: String = event.get("target", event.actor)
	if event.type == "swing": id = event.actor
	if views.has(id): views[id].react(event)

	if event.type == "damage" and rules != null:
		var source: RefCounted = rules.units.get(event.actor)
		var target: RefCounted = rules.units.get(event.target)
		if source != null and target != null and source.kind == "tower":
			# 当前是即时命中反馈，不伪装成已有弹道碰撞模拟。
			var start: Vector3 = source.position + Vector3(0, 4.6, 0)
			var finish: Vector3 = target.position + Vector3(0, 1, 0)
			var beam := geometry.box(self, (start + finish) / 2, Vector3(0.12, 0.12, start.distance_to(finish)), Color("efbf6f"))
			beam.look_at(finish)
			flashes.append({"view": beam, "remaining": 0.12})
