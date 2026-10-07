extends RefCounted
## 无副作用的责任链：逐项校验，通过后才允许调用方提交状态变更。

var checks: Array[Callable] = [check_actor, check_target, check_range, check_resource, check_cooldown]

func validate(context: Dictionary) -> String:
	for check in checks:
		var reason: String = check.call(context)
		if not reason.is_empty():
			return reason
	return ""

func check_actor(context: Dictionary) -> String:
	if not context.actor.alive(): return "单位已倒下，等待复活"
	if context.actor.stunned > 0: return "单位被眩晕"
	return ""

func check_target(context: Dictionary) -> String:
	if context.target == null or not context.target.alive(): return "目标已倒下"
	if context.actor == context.target: return "不能攻击自己"
	if context.actor.team == context.target.team: return "不能攻击友方"
	if context.target.invulnerable: return "目标受到防御塔保护"
	return ""

func check_range(context: Dictionary) -> String:
	if context.actor.position.distance_to(context.target.position) > context.range:
		return "目标超出范围"
	return ""

func check_resource(context: Dictionary) -> String:
	return "魔法不足" if context.actor.mana < context.mana_cost else ""

func check_cooldown(context: Dictionary) -> String:
	if context.cooldown > 0: return "技能或攻击正在冷却"
	return ""
