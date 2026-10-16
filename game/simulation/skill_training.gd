extends RefCounted
## 训练技能成长策略；三级升级分别要求英雄 2/4/6 级，不代表正式英雄规则。

const KINDS := ["strike", "area", "summon"]
const MAX_RANK := 4

static func reason(hero: RefCounted, kind: String, ended: bool) -> String:
	if ended: return "对局已经结束"
	if kind not in KINDS: return "技能不存在"
	if not hero.alive(): return "单位已倒下，等待复活"
	var rank := int(hero.skill_levels[kind])
	if rank >= MAX_RANK: return "技能已满级"
	if hero.skill_points <= 0: return "没有可用技能点"
	if hero.level < rank * 2: return "需要英雄 %d 级" % (rank * 2)
	return ""

static func upgrade(hero: RefCounted, kind: String, ended: bool) -> String:
	var rejection := reason(hero, kind, ended)
	if not rejection.is_empty(): return rejection
	# 全部校验成功后才提交；不刷新已有冷却、魔法或召唤物状态。
	hero.skill_points -= 1
	hero.skill_levels[kind] = int(hero.skill_levels[kind]) + 1
	return ""

static func bonus(hero: RefCounted, kind: String) -> int:
	return int(hero.skill_levels[kind]) - 1

static func valid_record(record: Dictionary) -> bool:
	if not record.skill_points is int or record.skill_points < 0: return false
	if not record.skill_levels is Dictionary or record.skill_levels.size() != KINDS.size(): return false
	var spent := 0
	for kind in KINDS:
		var rank: Variant = record.skill_levels.get(kind)
		if not rank is int or rank < 1 or rank > MAX_RANK: return false
		if rank > 1 and record.level < (rank - 1) * 2: return false
		spent += rank - 1
	return record.level >= 1 and record.level <= 10 and spent + record.skill_points == record.level - 1
