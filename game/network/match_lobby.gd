extends RefCounted
## 装载状态机与席位表；仅记录连接状态，不修改战斗和资源。

var seats: Array = []
var phase := "waiting"
var elapsed := 0.0
const LOAD_TIMEOUT := 30.0

func _init(teams: Array = [0, 1]) -> void:
	for team in teams:
		seats.append({"slot": seats.size(), "team": team, "peer": 0, "ready": false})

func claim(peer_id: int) -> int:
	if phase not in ["waiting", "loading"]: return -1
	for seat in seats:
		if seat.peer == 0:
			seat.peer = peer_id
			if connected() == seats.size(): phase = "loading"
			return seat.slot
	return -1

func ready(peer_id: int) -> bool:
	if phase == "aborted": return false
	for seat in seats:
		if seat.peer == peer_id:
			seat.ready = true
			if connected() == seats.size() and ready_count() == seats.size(): phase = "running"
			return true
	return false

func disconnect_peer(peer_id: int) -> void:
	# 装载中失去参与者时取消整局，避免已加载快照与补入席位不一致。
	if phase in ["waiting", "loading"]: phase = "aborted"
	for seat in seats:
		if seat.peer == peer_id: seat.peer = -1

func step(delta: float) -> void:
	if phase != "loading": return
	elapsed += delta
	if elapsed >= LOAD_TIMEOUT: phase = "aborted"

func connected() -> int:
	var count := 0
	for seat in seats:
		if seat.peer > 0: count += 1
	return count

func ready_count() -> int:
	var count := 0
	for seat in seats:
		if seat.peer > 0 and seat.ready: count += 1
	return count

func snapshot() -> Dictionary:
	var public_seats: Array = []
	for seat in seats:
		public_seats.append({"slot": seat.slot, "team": seat.team,
			"connected": seat.peer > 0, "ready": seat.peer > 0 and seat.ready})
	return {"type": "lobby", "phase": phase, "required": seats.size(),
		"connected": connected(), "ready": ready_count(), "seats": public_seats}
