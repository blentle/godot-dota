extends Node3D
## 批量单位表现：按规则标识维护视图，建筑倒塌后保留矮墩作为障碍提示。

const UnitView = preload("res://presentation/unit_view.gd")
const Geometry = preload("res://presentation/mesh_factory.gd")
var views: Dictionary = {}
var buildings: Dictionary = {}
var bars: Dictionary = {}
var geometry := Geometry.new()
var projectile_view := preload("res://presentation/projectile_view.gd").new()

func _ready() -> void:
	add_child(projectile_view)

func sync(combat: RefCounted, delta: float) -> void:
	projectile_view.sync(combat.projectiles.active)
	for id in views.keys():
		if not combat.units.has(id):
			views[id].queue_free()
			views.erase(id)
	for unit in combat.units.values():
		if unit.kind in ["tower", "base"]:
			_sync_building(unit)
		elif unit.kind in ["creep", "summon"]:
			if not views.has(unit.id):
				var view := UnitView.new()
				add_child(view)
				view.build(Color("b5a77d") if unit.kind == "summon" else Color("7eaaad") if unit.team == 0 else Color("b66f57"))
				view.scale = Vector3.ONE * (1.1 if unit.kind == "summon" else 0.8 if unit.role == "ranged" else 0.65)
				if unit.role == "ranged":
					geometry.cylinder(view, Vector3(0, 2.7, 0), 0.45, 0.7, Color("d7b96b"), 0.0)
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
