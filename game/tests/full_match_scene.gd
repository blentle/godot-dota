extends SceneTree
## 真实客户端完整长局；只提交命令，检查终局界面及服务端冻结快照。

const Orders = preload("res://tests/full_match_orders.gd")
var flow: Node
var slot := -1
var signatures: Dictionary = {}
var final_packet: Dictionary = {}
var frozen := true
var warmup := 300.0
var terminal_packets := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	flow = preload("res://bootstrap/network_flow.gd").new()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): flow.port = int(argument.trim_prefix("--port="))
		if argument.begins_with("--warmup-seconds="): warmup = float(argument.trim_prefix("--warmup-seconds="))
	flow.client.received.connect(_record)
	root.add_child(flow)
	var deadline := Time.get_ticks_msec() + 900000
	var next_order := 0.0
	while flow.phase != "result":
		if not _check(flow.phase != "failed" and Time.get_ticks_msec() < deadline, "完整联机长局未能到达结算"): return
		if flow.phase == "playing" and flow.world.elapsed >= next_order:
			var intent: Dictionary = Orders.next(flow.world, 0, warmup)
			if intent.get("command") == "attack": flow.world.submit_attack(intent.target)
			elif intent.get("command") == "hold": flow.world.submit_stop(true)
			next_order = flow.world.elapsed + 1
		await process_frame
	var result: Dictionary = flow.world.result_snapshot()
	if not _check(result.winner == 0 and result.seconds >= warmup, "必须正常推塔获得一致胜方并达到指定观察时长"): return
	if not _check(is_instance_valid(flow.panel) and flow.panel.snapshot == result, "结算界面必须呈现本席位权威战绩"): return
	if not _check(flow.panel.restart_button.disabled and not flow.battle.hud.visible and flow.world.closed, "终局必须关闭战场操作和联网重开"): return
	var sequence: int = flow.world.sequence
	flow.world.submit_buy("blade")
	if not _check(flow.world.sequence == sequence, "终局客户端不得继续发交易命令"): return
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end: await process_frame
	if not _check(frozen and terminal_packets >= 2, "终局后服务端规则或个人结果发生漂移"): return
	print("FULL_MATCH_RESULT " + JSON.stringify({"slot": slot, "result": result, "public": final_packet}))
	print("SHARED_SIGNATURES " + JSON.stringify({"slot": slot, "team": flow.world.combat.player.team,
		"entity": flow.world.combat.player.id, "states": signatures}))
	print("SHARED_SCENE_PASS：完整长局、权威胜负、个人结算与终局冻结。")
	flow.phase = "leaving"
	await flow.client.leave()
	if not _check(flow.client.departed, "主动离场未收到服务器确认"): return
	quit(0)

func _record(message: Dictionary) -> void:
	if message.get("type") == "welcome": slot = int(message.slot)
	if message.get("type") != "snapshot": return
	# 每秒留一个公共摘要，长局测试不保留全部大快照。
	if int(message.tick) % 60 == 0:
		signatures[str(int(message.tick))] = JSON.stringify(message.units).sha256_text()
	if message.result.is_empty(): return
	terminal_packets += 1
	var summary := {"units": JSON.stringify(message.units).sha256_text(), "elapsed": message.elapsed,
		"wave": message.wave, "projectiles": JSON.stringify(message.projectiles).sha256_text()}
	if final_packet.is_empty(): final_packet = summary
	elif summary != final_packet: frozen = false
	if flow.phase == "result" and flow.world.result_snapshot() != message.result: frozen = false

func _check(value: bool, reason: String) -> bool:
	if not value:
		push_error(reason)
		quit(1)
	return value
