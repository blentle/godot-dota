extends RefCounted
## 规则世界的远程门面：命令只发往服务端，本地状态仅由快照替换。

signal feedback(message: String)
const State = preload("res://network/remote_state.gd")
const Snapshot = preload("res://network/world_snapshot.gd")
const Unit = preload("res://simulation/combat/unit_state.gd")
var combat := State.Combat.new()
var economy := State.Availability.new()
var skills := economy
var progression := State.Progression.new()
var match_state := State.Match.new()
var summons := State.Summons.new()
var path := PackedVector3Array()
var obstacles: Array[Vector3] = []
var target_id := ""
var elapsed := 0.0
var order := "等待服务器"
var tick := -1
var sequence := 0
var pending: Dictionary = {}
var result: Dictionary = {}
var client: RefCounted
var motion := preload("res://presentation/remote_motion.gd").new()
var closed := false
var last_event := 0
var position: Vector3:
	get: return combat.player.position

func _init(connection: RefCounted) -> void:
	client = connection
	progression.player = combat.player
	client.received.connect(_receive)

func apply(snapshot: Dictionary) -> void:
	if closed or int(snapshot.tick) <= tick: return
	tick = int(snapshot.tick)
	var units: Dictionary = {}
	motion.begin()
	for record in snapshot.units:
		var unit: RefCounted = combat.units.get(record.id)
		if record.id == "player": unit = combat.player
		var fresh := not combat.units.has(record.id)
		if unit == null: unit = Unit.new()
		var snap: bool = fresh or unit.life_id != int(record.life_id) or (unit.hp > 0) != (record.hp > 0)
		for field in Snapshot.UNIT_FIELDS: unit.set(field, record[field])
		var destination := Vector3(record.position[0], 0, record.position[1])
		motion.track(unit, destination, snap)
		units[unit.id] = unit
	combat.units = units
	combat.projectiles.active.clear()
	for shot in snapshot.projectiles:
		combat.projectiles.active[shot.id] = {"team": shot.team,
			"position": Vector3(shot.position[0], shot.position[1], shot.position[2]),
			"target": shot.get("target", ""), "life": int(shot.get("life", -1)), "speed": float(shot.get("speed", 0.0))}
	for field in ["gold", "kills", "deaths", "last_hits"]: combat.set(field, snapshot[field])
	economy.slots.assign(snapshot.inventory)
	economy.reasons = snapshot.reasons.duplicate(true)
	economy.enabled = true
	elapsed = snapshot.elapsed
	order = snapshot.order
	match_state.wave = snapshot.wave
	match_state.next_wave = snapshot.next_wave
	summons.active_id = snapshot.summon_id
	summons.remaining = snapshot.summon_remaining
	result = snapshot.result.duplicate(true)
	if not result.is_empty(): match_state.winner = result.winner
	_emit_events(snapshot.get("events", []))

func _emit_events(events: Array) -> void:
	# 事件在状态更新后转发，保证受击闪烁读到的生命值已经是服务器结果。
	for raw in events:
		var serial := int(raw.get("sequence", 0))
		if serial <= last_event: continue
		last_event = serial
		var relevant: String = raw.get("target", "") if raw.get("type") == "damage" else raw.get("actor", "")
		var unit: RefCounted = combat.units.get(relevant)
		var generation_key := "target_life" if raw.get("type") == "damage" else "actor_life"
		if unit == null or unit.life_id != int(raw.get(generation_key, -1)): continue
		var event := {"type": raw.get("type", ""), "actor": raw.get("actor", ""), "target": raw.get("target", "")}
		if raw.has("amount"): event["amount"] = raw.amount
		if raw.has("position"):
			event["position"] = Vector3(raw.position[0], raw.position[1], raw.position[2])
		combat.combat_event.emit(event)

func _receive(message: Dictionary) -> void:
	if message.get("type") == "snapshot": apply(message)
	elif message.get("type") == "ack" and pending.has(int(message.sequence)):
		pending.erase(int(message.sequence))
		feedback.emit("服务器已确认操作" if message.ok else message.reason)

func _send(command: String, target: Variant = null) -> String:
	if not economy.enabled: return "连接不可用"
	if finished(): return "对局已经结束"
	if pending.size() >= 32: return "操作过快，请等待服务器确认"
	var next := sequence + 1
	var message := {"type": "command", "match": preload("res://network/dev_protocol.gd").MATCH_ID,
		"sequence": next, "command": command, "target": target}
	var invalid: String = preload("res://network/dev_protocol.gd").command_error(message)
	if not invalid.is_empty(): return "无效操作：" + invalid
	if client.send(message) != OK: return "连接不可用"
	sequence = next
	pending[sequence] = command
	return "等待服务器确认"

func submit_move(at: Vector3) -> bool:
	var reason := _send("move", [clampf(at.x, -48, 48), clampf(at.z, -48, 48)])
	feedback.emit(reason)
	return reason == "等待服务器确认"

func submit_attack(id: String = "") -> String:
	if not id.is_empty(): target_id = id
	var target := current_target()
	return "没有目标" if target == null else _send("attack", target.id)

func submit_stop(hold: bool = false) -> void:
	feedback.emit(_send("hold" if hold else "stop"))

func submit_strike() -> String:
	return _send("cast", "strike")

func submit_skill(kind: String) -> String:
	return _send("cast", kind)

func submit_buy(id: String) -> String:
	return _send("buy", id)

func submit_sell(index: int) -> String:
	return _send("sell", index)

func current_target() -> RefCounted:
	var target: RefCounted = combat.units.get(target_id)
	if target != null and target.alive(): return target
	var nearest: RefCounted
	var distance := INF
	for unit in combat.units.values():
		if unit.team == combat.player.team or not unit.alive() or unit.invulnerable: continue
		var next: float = position.distance_squared_to(unit.position)
		if next < distance:
			nearest = unit
			distance = next
	return nearest

func block(at: Vector3, _radius: int = 1) -> void:
	obstacles.append(at)

func step(delta: float) -> void:
	if not closed: motion.advance(combat, delta)

func finished() -> bool:
	return not result.is_empty()

func result_snapshot() -> Dictionary:
	return result.duplicate(true)

func disable() -> void:
	closed = true
	motion.clear()
	economy.enabled = false
	pending.clear()
