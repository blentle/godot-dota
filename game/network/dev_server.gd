extends Node
## 仅绑定回环地址的开发服务器；传输、限流和超时独立于游戏规则。

const Protocol = preload("res://network/dev_protocol.gd")
var peer := ENetMultiplayerPeer.new()
var authority := preload("res://network/dev_authority.gd").new()
var connections: Dictionary = {}
var started := false
var checkpoint := preload("res://network/checkpoint/checkpoint_service.gd").new()
var dispatch := preload("res://network/snapshot_dispatch.gd").new()
# 仅测试脚本使用：每物理帧人为阻塞，模拟慢服务器。
var frame_delay_ms := 0

func start(port: int) -> Error:
	if not checkpoint.path.is_empty():
		if not authority.has_method("_resume"): return ERR_INVALID_PARAMETER
		var restored: RefCounted = checkpoint.load_authority(authority)
		if restored == null:
			push_error(checkpoint.error)
			return ERR_FILE_CORRUPT
		authority = restored
	peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(port, authority.connection_capacity())
	if error != OK: return error
	# 服务端进程必须与规则步长一致，不能继承离线场景的 30 Hz 配置。
	Engine.physics_ticks_per_second = preload("res://network/dev_session.gd").TICK_RATE
	peer.peer_connected.connect(func(id: int) -> void:
		connections[id] = {"joined": Time.get_ticks_msec(), "seen": Time.get_ticks_msec(), "window": Time.get_ticks_msec(), "count": 0})
	peer.peer_disconnected.connect(_disconnected)
	started = true
	return OK

func _physics_process(_delta: float) -> void:
	if not started: return
	if frame_delay_ms > 0: OS.delay_msec(frame_delay_ms)
	peer.poll()
	if not started: return
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		started = false
		for id in connections.keys(): _disconnected(id)
		push_error("开发服务器传输已关闭，停止轮询并释放会话")
		return
	var now := Time.get_ticks_msec()
	for ignored in range(128):
		if not started: return
		if peer.get_available_packet_count() == 0: break
		var sender := peer.get_packet_peer()
		var packet := peer.get_packet()
		if not connections.has(sender): continue
		var state: Dictionary = connections[sender]
		if now - state.window >= 1000:
			state.window = now
			state.count = 0
		state.count += 1
		if state.count > 120 or packet.size() > Protocol.MAX_BYTES:
			_drop(sender)
			continue
		state.seen = now
		if state.has("leaving"):
			_send(sender, {"type": "left"})
			continue
		var request := Protocol.decode(packet)
		var reply: Dictionary = authority.receive(sender, request)
		# 命令确认与凭据发出前完成持久化；失败即停止服务，不能确认未保存的交易。
		if request.get("type") in ["hello", "ready", "resume", "command", "leave"]:
			if not _persist(): return
		if reply.get("type") == "left":
			# 规则席位已释放，传输暂留以送达确认，不能套用最初的握手期限。
			state["leaving"] = now
			dispatch.cancel(sender)
		_send(sender, reply)
	for id in connections.keys():
		var state: Dictionary = connections[id]
		if state.has("leaving"):
			if now - state.leaving > 2000: _drop(id)
		elif now - state.seen > 10000 or (not authority.sessions.has(id) and now - state.joined > 5000): _drop(id)
	if not started: return
	authority.step()
	if not checkpoint.path.is_empty() and authority.shared != null and authority.tick % 60 == 0:
		if not _persist(): return
	for id in authority.sessions.keys():
		# 终局状态已冻结，每秒重发一次；继续提供恢复依据，避免重复推送十份全量世界。
		var interval := 60 if authority.sessions[id].world.finished() else 6
		if authority.sessions[id].tick % interval == 0:
			dispatch.enqueue(id, authority.snapshot(id), authority.status_packet())
	dispatch.drain(_send_bytes, _drop)

func _send(id: int, message: Dictionary) -> bool:
	if message.is_empty(): return false
	return _send_bytes(id, preload("res://network/packet_codec.gd").encode(message))

func _send_bytes(id: int, packet: PackedByteArray) -> bool:
	if not started or packet.is_empty() or not connections.has(id): return false
	peer.set_target_peer(id)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return peer.put_packet(packet) == OK

func _drop(id: int) -> void:
	if not connections.has(id): return
	peer.disconnect_peer(id, true)
	_disconnected(id)

func _disconnected(id: int) -> void:
	dispatch.cancel(id)
	connections.erase(id)
	authority.release_peer(id)
	if started: _persist()

func _persist() -> bool:
	if checkpoint.save(authority): return true
	started = false
	push_error("权威存档失败，停止确认操作：" + checkpoint.error)
	get_tree().quit(1)
	return false

func _exit_tree() -> void:
	peer.close()
