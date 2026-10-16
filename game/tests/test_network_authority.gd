extends SceneTree
## 协议拒绝路径必须保持规则状态不变，重复命令不能再次执行；多席位互不干扰。

const Protocol = preload("res://network/dev_protocol.gd")
var failures := 0

func _initialize() -> void:
	var authority := preload("res://network/dev_authority.gd").new()
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	var bad := hello.duplicate()
	bad.version = 99
	_check(authority.receive(2, bad).code == "VERSION_MISMATCH" and authority.sessions.is_empty(), "版本不符不得装载世界")
	_check(authority.receive(2, hello).type == "welcome", "合法连接应绑定席位")
	_check(authority.receive(3, hello).type == "welcome" and authority.sessions.size() == 2, "第二席位可并行装载独立世界")
	_check(authority.receive(2, hello).code == "SEAT_OCCUPIED", "同连接重复握手必须拒绝")
	var buy := {"type": "command", "match": Protocol.MATCH_ID, "sequence": 1, "command": "buy", "target": "blade"}
	_check(authority.receive(4, buy).code == "NOT_AUTHORIZED", "未握手连接不能发送命令")
	var forged := buy.duplicate()
	forged.entity_id = "enemy"
	_check(authority.receive(2, forged).code == "UNEXPECTED_FIELD", "不得自选控制实体")
	var gap := buy.duplicate()
	gap.sequence = 3
	_check(authority.receive(2, gap).code == "SEQUENCE_MISMATCH", "拒绝跳号")
	_check(authority.receive(2, buy).ok, "合法交易应由服务端执行")
	var gold: int = authority.session(2).world.combat.gold
	_check(authority.receive(2, buy).ok and authority.session(2).world.combat.gold == gold, "重复购买不能重复扣费")
	_check(authority.session(2).world.economy.slots.count("blade") == 1, "重复命令不能发放第二份装备")
	var other_gold: int = authority.session(3).world.combat.gold
	authority.session(3).world.combat.gold = other_gold + 100
	_check(authority.session(2).world.combat.gold == gold and authority.snapshot(2).gold == gold, "席位金币不得互相泄漏")
	authority.session(3).world.combat.gold = other_gold
	authority.session(2).world.combat.apply_damage(authority.session(2).world.combat.player, authority.session(2).world.combat.units.tower_1_0, 12.0)
	var with_events: Dictionary = authority.snapshot(2)
	_check(with_events.events.size() == 1 and with_events.events[0].type == "damage"
		and with_events.events[0].actor == "player" and with_events.events[0].target == "tower_1_0"
		and absf(float(with_events.events[0].amount) - 12.0) < 0.01, "战斗事件必须进入快照")
	_check(authority.snapshot(3).events.is_empty(), "事件不得跨席位泄漏")
	_check(authority.snapshot(2).events.is_empty(), "事件必须在快照捕获后清空")
	authority.session(2).world.combat.combat_event.emit({"type": "spell", "actor": "player", "position": Vector3(1.5, 0.25, -3.0)})
	for index in range(80):
		authority.session(2).world.combat.combat_event.emit({"type": "damage", "actor": "player", "target": "enemy", "amount": 1.0})
	var capped: Dictionary = JSON.parse_string(JSON.stringify(authority.snapshot(2)))
	_check(capped.events.size() == 64 and capped.events[0].type == "spell"
		and capped.events[0].position.size() == 3 and capped.events[0].position[1] == 0.25, "事件必须白名单序列化并限制数量")
	for target in [[NAN, 0], [INF, 0], [49, 0], ["1", 0], [1], null]:
		var move := {"type": "command", "match": Protocol.MATCH_ID, "sequence": 2, "command": "move", "target": target}
		_check(authority.receive(2, move).code == "BAD_TARGET" and authority.session(2).sequence == 1, "异常坐标不能进入导航")
	var denied := buy.duplicate()
	denied.sequence = 2
	denied.target = "missing"
	_check(not authority.receive(2, denied).ok and authority.session(2).sequence == 2, "业务拒绝也必须确认序号")
	_check(authority.receive(2, buy).code == "SEQUENCE_MISMATCH", "过期命令不能重新执行")
	var snapshot := authority.snapshot(2)
	snapshot.inventory[0] = "forged"
	_check(authority.session(2).world.economy.slots[0] == "blade", "快照不能修改库存")
	_check(Protocol.decode("[]".to_utf8_buffer()).is_empty(), "拒绝非对象 JSON")
	_check(Protocol.decode("x".repeat(4097).to_utf8_buffer()).is_empty(), "拒绝超限消息")
	_check(authority.receive(5, hello).type == "welcome", "更多席位可继续装载")
	_check(authority.receive(6, hello).type == "welcome", "第四席位可装载")
	_check(authority.receive(7, hello).code == "SERVER_FULL", "超过席位上限必须拒绝")
	authority.release_peer(7)
	_check(authority.sessions.size() == 4, "未握手连接释放无副作用")
	authority.release_peer(3)
	_check(authority.session(2) != null and authority.session(3) == null, "释放席位不得影响其他席位")
	for peer in [2, 5, 6]:
		authority.release_peer(peer)
	_check(authority.sessions.is_empty(), "断开必须清理全部会话")
	_check(authority.receive(3, hello).type == "welcome" and authority.session(3).world.combat.gold == 300, "新会话必须是新世界")
	if failures == 0: print("网络权威规则通过：握手、多席位隔离、序号、重复扣费、异常数据、事件缓冲与断开清理。")
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
