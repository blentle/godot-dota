extends SceneTree
## 真实进程网络异常验证：命令突发按序收敛、读取停顿后追赶与待确认上限。

const Protocol = preload("res://network/dev_protocol.gd")
var client := preload("res://network/dev_client.gd").new()
var world: RefCounted
var port := 27883
var stall_until := 0
var last_ping := 0
var handshaken := false
var accepted := 0
var rejected := 0

func _initialize() -> void:
	world = preload("res://network/remote_world.gd").new(client)
	world.feedback.connect(func(message: String) -> void:
		if message == "等待服务器确认": accepted += 1
		elif message.begins_with("操作过快"): rejected += 1)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): port = int(argument.trim_prefix("--port="))
	if client.start(port) != OK:
		_fail("客户端创建失败")
		return
	last_ping = Time.get_ticks_msec()
	_run()

func _run() -> void:
	var deadline := _deadline(15)
	while not world.economy.enabled:
		_step_frame()
		if _expired(deadline): return _fail("未收到首个快照")
		await process_frame
	# 阶段一：连续命令突发，服务器必须按序全部执行并收敛到目标。
	var origin: Vector3 = world.position
	for index in range(6):
		world.submit_move(origin + Vector3(0.7 * (index + 1), 0, 0))
	deadline = _deadline(25)
	while world.position.x <= origin.x + 3.5:
		_step_frame()
		if _expired(deadline): return _fail("突发命令未按序收敛，位置=%s" % world.position)
		await process_frame
	# 阶段二：暂停读取与心跳，模拟客户端卡顿，恢复后必须追上服务器。
	var before_tick: int = world.tick
	stall_until = Time.get_ticks_msec() + 2500
	deadline = _deadline(12)
	while world.tick <= before_tick:
		_step_frame()
		if _expired(deadline): return _fail("停顿后未恢复快照推进")
		await process_frame
	if client.peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return _fail("短时停顿不应断线")
	# 阶段三：不等待确认连续发送，32 条以后必须被本地待确认上限拦截。
	accepted = 0
	rejected = 0
	var target: Vector3 = world.position
	for index in range(40):
		world.submit_move(target + Vector3(0.3, 0, 0))
	if accepted != 32 or rejected != 8:
		return _fail("待确认上限错误：接受 %d，拒绝 %d" % [accepted, rejected])
	deadline = _deadline(15)
	while not world.pending.is_empty():
		_step_frame()
		if _expired(deadline): return _fail("确认队列未排空")
		await process_frame
	if not world.submit_move(target + Vector3(0.5, 0, 0)):
		return _fail("队列排空后无法继续发送命令")
	print("NETWORK_ANOMALY_PASS：突发收敛、停顿恢复、待确认上限与排空恢复。")
	client.close()
	quit(0)

func _step_frame() -> void:
	if stall_until > 0:
		if Time.get_ticks_msec() < stall_until: return
		stall_until = 0
	if not handshaken and client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		handshaken = true
		var hello: Dictionary = Protocol.identity()
		hello.merge({"type": "hello", "profile": "guardian"})
		client.send(hello)
	client.poll()
	# 测试进程没有战场物理回调，需独立推进只读表现插值。
	world.step(0.016)
	if Time.get_ticks_msec() - last_ping >= 1000:
		last_ping = Time.get_ticks_msec()
		client.send({"type": "ping"})

func _deadline(seconds: int) -> int:
	return Time.get_ticks_msec() + seconds * 1000

func _expired(deadline: int) -> bool:
	return Time.get_ticks_msec() > deadline

func _fail(message: String) -> void:
	push_error(message)
	client.close()
	quit(1)
