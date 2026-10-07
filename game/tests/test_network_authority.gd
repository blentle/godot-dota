extends SceneTree
## 协议拒绝路径必须保持规则状态不变，重复命令不能再次执行。

const Protocol = preload("res://network/dev_protocol.gd")
var failures := 0

func _initialize() -> void:
	var authority := preload("res://network/dev_authority.gd").new()
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	var bad := hello.duplicate()
	bad.version = 99
	_check(authority.receive(2, bad).code == "VERSION_MISMATCH" and authority.world == null, "版本不符不得装载世界")
	_check(authority.receive(2, hello).type == "welcome", "合法连接应绑定席位")
	_check(authority.receive(3, hello).code == "SEAT_OCCUPIED", "第二连接不得接管")
	var buy := {"type": "command", "match": Protocol.MATCH_ID, "sequence": 1, "command": "buy", "target": "blade"}
	_check(authority.receive(3, buy).code == "NOT_AUTHORIZED", "不能控制其他连接角色")
	var forged := buy.duplicate()
	forged.entity_id = "enemy"
	_check(authority.receive(2, forged).code == "UNEXPECTED_FIELD", "不得自选控制实体")
	var gap := buy.duplicate()
	gap.sequence = 3
	_check(authority.receive(2, gap).code == "SEQUENCE_MISMATCH", "拒绝跳号")
	_check(authority.receive(2, buy).ok, "合法交易应由服务端执行")
	var gold: int = authority.world.combat.gold
	_check(authority.receive(2, buy).ok and authority.world.combat.gold == gold, "重复购买不能重复扣费")
	_check(authority.world.economy.slots.count("blade") == 1, "重复命令不能发放第二份装备")
	for target in [[NAN, 0], [INF, 0], [49, 0], ["1", 0], [1], null]:
		var move := {"type": "command", "match": Protocol.MATCH_ID, "sequence": 2, "command": "move", "target": target}
		_check(authority.receive(2, move).code == "BAD_TARGET" and authority.sequence == 1, "异常坐标不能进入导航")
	var denied := buy.duplicate()
	denied.sequence = 2
	denied.target = "missing"
	_check(not authority.receive(2, denied).ok and authority.sequence == 2, "业务拒绝也必须确认序号")
	_check(authority.receive(2, buy).code == "SEQUENCE_MISMATCH", "过期命令不能重新执行")
	var snapshot := authority.snapshot()
	snapshot.inventory[0] = "forged"
	_check(authority.world.economy.slots[0] == "blade", "快照不能修改库存")
	_check(Protocol.decode("[]".to_utf8_buffer()).is_empty(), "拒绝非对象 JSON")
	_check(Protocol.decode("x".repeat(4097).to_utf8_buffer()).is_empty(), "拒绝超限消息")
	authority.release_peer(3)
	_check(authority.owner == 2, "旁观连接断开不能清空对局")
	authority.release_peer(2)
	_check(authority.world == null and authority.sequence == 0, "断开必须清理旧控制权")
	_check(authority.receive(3, hello).type == "welcome" and authority.world.combat.gold == 300, "新会话必须是新世界")
	if failures == 0: print("网络权威规则通过：握手、控制权、序号、重复扣费、异常数据与断开清理。")
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
