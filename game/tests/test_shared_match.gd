extends SceneTree
## 同局双玩家：共享时间和实体，控制权、交易、施法与结算统计按玩家隔离。

const Protocol = preload("res://network/dev_protocol.gd")
var failures := 0

func _initialize() -> void:
	var authority := preload("res://network/shared_authority.gd").new()
	var hello := Protocol.identity()
	hello.merge({"type": "hello", "profile": "guardian"})
	var first: Dictionary = authority.receive(10, hello)
	for frame in range(12): authority.step()
	var second: Dictionary = authority.receive(20, hello)
	var a: RefCounted = authority.session(10).world
	var b: RefCounted = authority.session(20).world
	var core: RefCounted = authority.shared.core
	_check(first.entity == "player" and second.entity == "player_2" and second.team == 1, "服务端应分配不同英雄与阵营")
	_check(a.combat.units == b.combat.units and a.routing == b.routing and a.match_state == b.match_state, "双方必须共享实体、导航和胜负")
	_check(a.combat.player != b.combat.player and a.economy != b.economy, "双方英雄与经济应独立")
	_check(authority.snapshot(10).tick == authority.snapshot(20).tick, "迟到玩家必须使用同一模拟时钟")
	var buy := _command(1, "buy", "blade")
	_check(authority.receive(20, buy).ok and b.combat.gold == 200 and a.combat.gold == 300, "天灾基地购买只能扣天灾金币")
	_check(authority.receive(20, buy).ok and b.economy.slots.count("blade") == 1, "重复命令不得重复交易")
	var forged := _command(1, "move", [-10, 10])
	forged.entity_id = "player_2"
	_check(authority.receive(10, forged).code == "UNEXPECTED_FIELD", "不允许通过载荷指定他人英雄")
	var before: Vector3 = b.position
	_check(authority.receive(10, _command(1, "move", [-28, 30])).ok, "玩家一应能移动")
	for frame in range(30): authority.step()
	_check(a.position.x > -32 and b.position == before, "玩家一移动不能改变玩家二位置")
	a.submit_stop()
	# 两人同时施法，不能复用单个全局 player 或召唤物标识。
	_check(authority.receive(10, _command(2, "cast", "summon")).ok, "玩家一召唤应成功")
	_check(authority.receive(20, _command(2, "cast", "summon")).ok, "玩家二召唤应成功")
	_check(a.summons.active_id != b.summons.active_id, "召唤物标识必须全局唯一")
	_check(core.units[a.summons.active_id].owner_id == a.combat.player.id and core.units[b.summons.active_id].owner_id == b.combat.player.id, "召唤物归属必须绑定各自英雄")
	var mana: float = b.combat.player.mana
	for frame in range(60): authority.step()
	_check(absf(b.combat.player.mana - mana - 3.0) < 0.001, "共享战斗不能因两人而每帧推进两次")
	var snap_a := authority.snapshot(10)
	var snap_b := authority.snapshot(20)
	_check(snap_a.units == snap_b.units and snap_a.tick == snap_b.tick, "双方快照公共世界与 tick 必须一致")
	_check(snap_a.inventory.count("blade") == 0 and snap_b.inventory.count("blade") == 1, "背包快照必须按接收者过滤")
	_check(snap_b.controlled_entity == "player_2", "第二客户端应控制第二英雄")
	# 第二名玩家的震击必须从自己扣魔法，并以自己为伤害来源。
	a.combat.player.position = Vector3.ZERO
	b.combat.player.position = Vector3(2, 0, 0)
	b.target_id = a.combat.player.id
	var hp: float = a.combat.player.hp
	mana = a.combat.player.mana
	_check(authority.receive(20, _command(3, "cast", "strike")).ok, "玩家二震击应成功")
	_check(a.combat.player.hp == hp - 80 and a.combat.player.mana == mana and b.combat.player.skill_cooldown > 0, "第二玩家施法的费用与伤害不能落到错误玩家")
	# 奖励、阵亡和经验按阵营与来源裁定，事件订阅顺序不得吞掉经验。
	var creep: RefCounted
	for unit in core.units.values():
		if unit.kind == "creep" and unit.team == 0:
			creep = unit
			break
	creep.position = b.position
	var gold: int = b.combat.gold
	core.apply_damage(core.units[b.summons.active_id], creep, 9999)
	_check(b.combat.gold == gold + creep.reward and b.combat.last_hits == 1 and b.combat.player.experience > 0, "天灾召唤物补刀与经验必须归属天灾玩家")
	core.apply_damage(b.combat.player, a.combat.player, 9999)
	_check(b.combat.kills == 1 and a.combat.deaths == 1, "击杀与阵亡应分别进入双方账本")
	for lane in range(3): core.apply_damage(b.combat.player, core.units["tower_0_%d" % lane], 9999)
	core.apply_damage(b.combat.player, core.units.base_0, 9999)
	snap_a = authority.snapshot(10)
	snap_b = authority.snapshot(20)
	_check(snap_a.result.winner == 1 and snap_b.result.winner == 1 and snap_a.result.seconds == snap_b.result.seconds, "双方必须得到相同胜方和结束时间")
	_check(snap_a.result.deaths == 1 and snap_b.result.kills == 1, "结算统计必须属于各自玩家")
	_check(not authority.receive(10, _command(3, "buy", "vest")).ok, "胜负确定后不得继续交易")
	authority.release_peer(10)
	_check(authority.session(20) != null and authority.shared.players.has(0), "断线不能销毁另一人的对局")
	_check(authority.receive(30, hello).code == "SERVER_FULL", "新连接不能接管断线席位")
	authority.release_peer(20)
	_check(authority.shared == null and authority.sessions.is_empty(), "最后一人退出后应释放共享世界")
	_check(authority.receive(30, hello).entity == "player" and authority.session(30).world.combat.gold == 300, "下一局必须从干净状态开始")
	authority.release_peer(30)
	if failures == 0: print("双玩家同局规则通过：共同时钟、控制权、私有资源、施法、归属、胜负与断线清理。")
	quit(1 if failures else 0)

func _command(sequence: int, kind: String, target: Variant) -> Dictionary:
	return {"type": "command", "match": Protocol.MATCH_ID, "sequence": sequence, "command": kind, "target": target}

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
