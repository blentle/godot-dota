extends RefCounted
## 开发经验分配策略：死亡时一次收集候选，再分配固定总额；不代表正式 6.83d 数值。

static func distribute(victim: RefCounted, progressions: Array, ended: bool) -> void:
	if victim == null or victim.alive(): return
	if victim.experience_claimed_life == victim.life_id: return
	# 无人符合资格也消费本次死亡，禁止靠近尸体、复活或新加入后补领。
	victim.experience_claimed_life = victim.life_id
	if ended or victim.kind not in ["hero", "creep"] or victim.team not in [0, 1]: return
	if victim.experience_reward <= 0: return
	var candidates: Array = []
	var seen: Dictionary = {}
	for progression in progressions:
		var hero: RefCounted = progression.player
		if seen.has(hero.id): continue
		seen[hero.id] = true
		if hero.team not in [0, 1] or hero.team == victim.team or hero.kind != "hero": continue
		if not hero.alive() or hero.level >= progression.MAX_LEVEL: continue
		if hero.position.distance_to(victim.position) > progression.EXPERIENCE_RANGE: continue
		candidates.append(progression)
	if candidates.is_empty(): return
	# 余数按稳定英雄标识分配，保证总量守恒且不受事件订阅/入场顺序影响。
	candidates.sort_custom(func(a: RefCounted, b: RefCounted) -> bool: return a.player.id < b.player.id)
	var share := int(victim.experience_reward / candidates.size())
	var remainder: int = victim.experience_reward % candidates.size()
	for index in range(candidates.size()):
		candidates[index].grant(share + (1 if index < remainder else 0))
