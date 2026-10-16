extends RefCounted
## 将训练规则映射到经典 HUD；未知原版属性留空，不修改权威状态。

const BTN = preload("res://ui/war3/assets/BTN_test.png")
const AHK = preload("res://ui/war3/assets/AHK_test.png")
const DIS = preload("res://ui/war3/assets/DISBTN_test.png")
const Catalog = preload("res://simulation/item_catalog.gd")
const Art = preload("res://ui/war3/scripts/classic_art.gd")
var use_original_art := false

const Training = preload("res://simulation/skill_training.gd")
const Profiles = preload("res://simulation/hero_profiles.gd")

func read(world: RefCounted, selected: bool, paused: bool) -> Dictionary:
	var combat: RefCounted = world.combat
	var actor: RefCounted = combat.player
	var blocked: bool = not selected or paused or not actor.alive() or actor.stunned > 0 or world.finished()
	var skills: Array = []
	var target: RefCounted = world.current_target()
	var strike_blocked := true
	if target != null:
		strike_blocked = not combat.chain.validate({"actor": actor, "target": target,
			"range": 5.0 + target.radius, "mana_cost": 60.0, "cooldown": actor.skill_cooldown}).is_empty()
	skills.append(_icon("训练震击 Q", _description(actor, "strike"), actor.skill_cooldown,
		blocked or strike_blocked or actor.mana < 60, "btnstormbolt"))
	skills.append(_icon("训练冲击 W", _description(actor, "area"), actor.area_cooldown,
		blocked or not world.skills.reason("area").is_empty(), "btnthunderclap"))
	skills.append(_icon("训练召唤 E", _description(actor, "summon"), actor.summon_cooldown,
		blocked or not world.skills.reason("summon").is_empty(), "btnsummonwaterelemental"))
	skills.append(_icon("未实现", "当前训练角色没有第四技能。", 0, true))
	var items: Array = []
	for id in world.economy.slots:
		var item: Dictionary = Catalog.ITEMS.get(id, {})
		items.append(_icon(str(item.get("name", "空物品格")),
			str(item.get("description", "")) + "\n被动装备，没有主动冷却。点击查看或出售。", 0, paused or id.is_empty(), Art.item_name(id)))
	var player := {"name": "训练玩家", "portrait": Art.icon("btnavatar") if use_original_art else BTN, "dead_portrait": Art.icon("btnheromountainking", true) if use_original_art else DIS,
		"alive": actor.alive(), "kills": combat.kills, "deaths": combat.deaths, "gold": combat.gold}
	var required: int = world.progression.required_experience()
	return {"hero": {"name": "%s · %d 级 · 占位美术" % [Profiles.PROFILES[actor.profile_id].name, actor.level],
		"level": actor.level, "skill_points": actor.skill_points, "damage": actor.damage,
		"portrait": BTN, "hp": actor.hp, "max_hp": actor.max_hp, "mp": actor.mana, "max_mp": actor.max_mana,
		"xp": actor.experience if required > 0 else 1, "xp_required": required if required > 0 else 1},
		"commands_blocked": blocked, "gold": combat.gold, "lumber": "—", "skills": skills, "items": items,
		"players": [player], "team": [player]}

func _icon(title: String, description: String, cooldown: float, disabled: bool, icon_name := "") -> Dictionary:
	return {"btn": Art.icon(icon_name) if use_original_art else BTN, "ahk": Art.highlight() if use_original_art else AHK,
		"disbtn": Art.icon(icon_name, true) if use_original_art else DIS, "title": title,
		"description": description, "cooldown": cooldown, "disabled": disabled}

func _description(actor: RefCounted, kind: String) -> String:
	var bonus := Training.bonus(actor, kind)
	var details := ""
	match kind:
		"strike": details = "伤害 %d；魔法 60；冷却 6 秒；眩晕 1.5 秒。" % (80 + 30 * bonus)
		"area": details = "伤害 %d；半径 5；魔法 70；冷却 8 秒。" % (70 + 25 * bonus)
		"summon": details = "新守卫生命 %d，攻击 %d。\n魔法 80；冷却 20 秒；持续 15 秒。" % [180 + 60 * bonus, 20 + 8 * bonus]
	return "训练技能 %d/4 级\n%s\n开发数值，非原版英雄技能。" % [bonus + 1, details]
