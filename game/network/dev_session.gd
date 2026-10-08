extends RefCounted
## 单个席位的权威会话：独立训练世界、命令序号、缓存确认与事件缓冲。

const Protocol = preload("res://network/dev_protocol.gd")
const Snapshot = preload("res://network/world_snapshot.gd")
const MAX_EVENTS := 64
const TICK_RATE := 60

var world: RefCounted
var sequence := 0
var tick := 0
var last_reply: Dictionary = {}
var pending_events: Array = []
var event_sequence := 0
var dropped_events := 0

func open_world(profile: String) -> bool:
	var candidate := preload("res://simulation/training_world.gd").new()
	if not candidate.configure_hero(profile).is_empty(): return false
	preload("res://simulation/terrain_layout.gd").register_trees(candidate)
	candidate.start_match()
	world = candidate
	world.combat.combat_event.connect(_record_event)
	return true

func step() -> void:
	if world == null: return
	world.step(1.0 / TICK_RATE)
	tick += 1

func snapshot() -> Dictionary:
	if world == null: return {}
	var packet := Snapshot.capture(world, tick, sequence, pending_events)
	packet["dropped_events"] = dropped_events
	pending_events.clear()
	return packet

func receive_command(message: Dictionary) -> Dictionary:
	var rejection := Protocol.command_error(message)
	if not rejection.is_empty(): return _error(rejection)
	var requested := int(message.sequence)
	if requested == sequence: return last_reply.duplicate(true)
	if requested != sequence + 1: return _error("SEQUENCE_MISMATCH")
	sequence = requested
	var reason := _execute(message)
	last_reply = {"type": "ack", "sequence": sequence, "ok": reason.is_empty(), "reason": reason}
	return last_reply.duplicate(true)

func close() -> void:
	world = null
	sequence = 0
	tick = 0
	last_reply = {}
	pending_events.clear()
	event_sequence = 0
	dropped_events = 0

func _execute(message: Dictionary) -> String:
	if world.finished(): return "对局已经结束"
	var target: Variant = message.get("target")
	match message.command:
		"move": return "" if world.submit_move(Vector3(target[0], 0, target[1])) else "无法移动"
		"attack": return world.submit_attack(target)
		"buy": return world.submit_buy(target)
		"sell": return world.submit_sell(int(target))
		"cast": return world.submit_strike() if target == "strike" else world.submit_skill(target)
		"stop", "hold": world.submit_stop(message.command == "hold")
	return ""

func _record_event(event: Dictionary) -> void:
	# 单窗口事件数量有上限，超出丢弃新事件；只保留白名单字段供序列化。
	event_sequence += 1
	if pending_events.size() >= MAX_EVENTS:
		dropped_events += 1
		return
	var record := {"type": event.get("type", ""), "actor": event.get("actor", ""), "target": event.get("target", "")}
	record["sequence"] = event_sequence
	for key in ["actor", "target"]:
		var unit: RefCounted = world.combat.units.get(record[key])
		if unit != null: record[key + "_life"] = unit.life_id
	if event.has("amount"): record["amount"] = event.amount
	if event.has("position"):
		record["position"] = [event.position.x, event.position.y, event.position.z]
	pending_events.append(record)

func _error(code: String) -> Dictionary:
	return {"type": "error", "code": code, "ack": sequence}
