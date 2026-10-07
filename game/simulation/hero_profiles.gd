extends RefCounted
## 三种机制验证配置，共用训练技能；不对应正式英雄清单。

const PROFILES := {
	"guardian": {"name": "近战卫兵", "description": "近身攻击 · 较高生命", "hp": 600.0, "mana": 240.0, "damage": 55.0, "range": 2.4, "interval": 1.0, "speed": 7.0, "projectile": 0.0, "color": "6f98ac"},
	"ranger": {"name": "远程射手", "description": "追踪弹道 · 较长射程", "hp": 450.0, "mana": 240.0, "damage": 42.0, "range": 7.0, "interval": 1.2, "speed": 7.0, "projectile": 18.0, "color": "93a477"},
	"apprentice": {"name": "施法学徒", "description": "较多魔法 · 远程攻击", "hp": 480.0, "mana": 360.0, "damage": 38.0, "range": 5.5, "interval": 1.4, "speed": 6.5, "projectile": 15.0, "color": "a597bb"}
}

static func apply(hero: RefCounted, id: String) -> String:
	if not PROFILES.has(id): return "训练配置不存在"
	var profile: Dictionary = PROFILES[id]
	hero.profile_id = id
	hero.max_hp = profile.hp
	hero.max_mana = profile.mana
	hero.damage = profile.damage
	hero.attack_range = profile.range
	hero.attack_interval = profile.interval
	hero.move_speed = profile.speed
	hero.projectile_speed = profile.projectile
	hero.reset()
	return ""
