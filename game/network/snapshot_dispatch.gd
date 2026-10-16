extends RefCounted
## 同一 tick 采集状态，按物理帧分批发送，避免所有席位在同一帧集中发包。

const Codec = preload("res://network/packet_codec.gd")
const PER_FRAME := 2
var batches: Array = []

func enqueue(peer_id: int, snapshot: Dictionary, status: Dictionary) -> void:
	var packets: Array = [Codec.encode(snapshot)]
	if not status.is_empty(): packets.append(Codec.encode(status))
	batches.append({"peer": peer_id, "packets": packets})

func drain(sender: Callable, failed: Callable) -> void:
	for index in range(mini(PER_FRAME, batches.size())):
		var batch: Dictionary = batches.pop_front()
		for packet in batch.packets:
			if packet.is_empty() or not sender.call(batch.peer, packet):
				failed.call(batch.peer)
				break

func cancel(peer_id: int) -> void:
	# 离场确认之后不能再排出该席位的旧快照。
	batches = batches.filter(func(batch: Dictionary) -> bool: return batch.peer != peer_id)
