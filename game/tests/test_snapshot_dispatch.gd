extends SceneTree
## 分批发包不能改变采集时的状态；失败席位不阻塞后续席位。

var received: Array = []
var failures := 0
var dropped: Array = []

func _initialize() -> void:
	var dispatch := preload("res://network/snapshot_dispatch.gd").new()
	var snapshot := {"type": "snapshot", "tick": 60, "units": [{"hp": 100}]}
	for peer in range(10): dispatch.enqueue(peer, snapshot, {"type": "lobby"})
	snapshot.units[0].hp = 50
	dispatch.drain(_send, func(peer: int) -> void: dropped.append(peer))
	_check(received.size() == 4 and dispatch.batches.size() == 8, "一帧只能发送两个席位，状态包属于同一批")
	for frame in range(4): dispatch.drain(_send, func(peer: int) -> void: dropped.append(peer))
	_check(dispatch.batches.is_empty() and received.size() == 18 and dropped == [4], "失败席位应跳过且后续席位继续发送")
	for message in received:
		if message.type == "snapshot":
			_check(message.tick == 60 and message.units[0].hp == 100, "分批发送必须保持同一采集 tick 的状态")
	dispatch.enqueue(10, snapshot, {})
	dispatch.enqueue(11, snapshot, {})
	dispatch.cancel(10)
	_check(dispatch.batches.size() == 1 and dispatch.batches[0].peer == 11, "离场只取消本席位排队快照")
	if failures == 0: print("快照发送节奏测试通过。")
	quit(1 if failures else 0)

func _send(peer: int, packet: PackedByteArray) -> bool:
	if peer == 4: return false
	received.append(preload("res://network/packet_codec.gd").decode(packet))
	return true

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
