extends RefCounted
## 追踪投射物规则：仅保存值快照，发射者被清理后仍可结算；不持有单位引用。

const MAX_LIFETIME := 4.0
var active: Dictionary = {}
var next_id := 1

func launch(actor: RefCounted, target: RefCounted) -> void:
	active[next_id] = {"id": next_id, "actor": actor.owner_id if not actor.owner_id.is_empty() else actor.id, "team": actor.team,
		"target": target.id, "life": target.life_id, "damage": actor.damage,
		"speed": actor.projectile_speed, "remaining": MAX_LIFETIME,
		"position": actor.position + Vector3.UP * (4.6 if actor.kind == "tower" else 1.5)}
	next_id += 1

func step(delta: float, units: Dictionary, hit: Callable) -> void:
	for id in active.keys():
		var shot: Dictionary = active[id]
		var target: RefCounted = units.get(shot.target)
		if target == null or not target.alive() or target.life_id != shot.life:
			active.erase(id)
			continue
		var destination: Vector3 = target.position + Vector3.UP
		var distance: float = shot.position.distance_to(destination)
		var travel: float = shot.speed * minf(delta, shot.remaining)
		shot.position = shot.position.move_toward(destination, travel)
		shot.remaining -= delta
		if distance <= travel:
			# 先移除再回调，防止命中事件重入而重复结算。
			active.erase(id)
			hit.call(shot, target)
		elif shot.remaining <= 0:
			active.erase(id)
