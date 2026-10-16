extends RefCounted
## 长局测试的命令策略：先观察五分钟兵线，再由指定阵营依次推塔、攻击基地。
## 不改写规则状态，不代表真人对抗或正式平衡验收。

static func next(world: RefCounted, attacking_team: int, warmup: float = 300.0) -> Dictionary:
	if world.finished() or not world.combat.player.alive(): return {}
	if world.elapsed < warmup or world.combat.player.team != attacking_team: return {"command": "hold", "target": null}
	var enemy := 1 - attacking_team
	for lane in range(3):
		var id := "tower_%d_%d" % [enemy, lane]
		if world.combat.units[id].alive(): return {"command": "attack", "target": id}
	return {"command": "attack", "target": "base_%d" % enemy}
