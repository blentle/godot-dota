extends RefCounted
## 快照表现插值策略：有限时间内趋近服务器位置，不外推规则或跨生命代次平滑。

const WINDOW := 0.1
const SNAP_DISTANCE := 12.0
var spans: Dictionary = {}
var clock := 0.0

func begin() -> void:
	spans.clear()
	clock = 0.0

func track(unit: RefCounted, destination: Vector3, snap: bool) -> void:
	if snap or unit.position.distance_to(destination) > SNAP_DISTANCE:
		unit.position = destination
	spans[unit.id] = [unit.position, destination]

func advance(combat: RefCounted, delta: float) -> void:
	var amount := minf(maxf(delta, 0.0), maxf(0.0, WINDOW - clock))
	clock += amount
	for id in spans:
		if combat.units.has(id):
			combat.units[id].position = spans[id][0].lerp(spans[id][1], clock / WINDOW)
	# 只预测最多一个快照窗口，缺包时停止，不追踪复活后的同名目标。
	for shot in combat.projectiles.active.values():
		var target: RefCounted = combat.units.get(shot.target)
		if target == null or not target.alive() or target.life_id != shot.life: continue
		shot.position = shot.position.move_toward(target.position + Vector3.UP, shot.speed * amount)

func clear() -> void:
	spans.clear()
	clock = WINDOW
