extends Node
## 仅绑定回环地址的开发服务器；传输、限流和超时独立于游戏规则。

const Protocol = preload("res://network/dev_protocol.gd")
var peer := ENetMultiplayerPeer.new()
var authority := preload("res://network/dev_authority.gd").new()
var connections: Dictionary = {}
var started := false
# 仅测试脚本使用：每物理帧人为阻塞，模拟慢服务器。
var frame_delay_ms := 0

func start(port: int) -> Error:
	peer.set_bind_ip("127.0.0.1")
	var error := peer.create_server(port, 4)
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
	var now := Time.get_ticks_msec()
	for ignored in range(128):
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
		var reply: Dictionary = authority.receive(sender, Protocol.decode(packet))
		_send(sender, reply)
	for id in connections.keys():
		var state: Dictionary = connections[id]
		if now - state.seen > 10000 or (not authority.sessions.has(id) and now - state.joined > 5000): _drop(id)
	authority.step()
	for id in authority.sessions.keys():
		if authority.sessions[id].tick % 6 == 0 and not _send(id, authority.snapshot(id)):
			_drop(id)

func _send(id: int, message: Dictionary) -> bool:
	if message.is_empty() or not connections.has(id): return false
	peer.set_target_peer(id)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return peer.put_packet(JSON.stringify(message).to_utf8_buffer()) == OK

func _drop(id: int) -> void:
	peer.disconnect_peer(id, true)
	_disconnected(id)

func _disconnected(id: int) -> void:
	connections.erase(id)
	authority.release_peer(id)

func _exit_tree() -> void:
	if started: peer.close()
