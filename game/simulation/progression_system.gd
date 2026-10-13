extends RefCounted
## 单英雄开发成长规则：接收已分配经验并升级；离线死亡入口复用统一分配策略。

signal leveled(level: int)

const MAX_LEVEL := 10
const EXPERIENCE_RANGE := 12.0
const DAMAGE_GROWTH := 6.0
const HEALTH_GROWTH := 80.0
const MANA_GROWTH := 30.0
var player: RefCounted

func _init(hero: RefCounted) -> void:
	player = hero

func required_experience() -> int:
	return 0 if player.level >= MAX_LEVEL else player.level * 100

func reward_death(victim: RefCounted, ended: bool) -> void:
	preload("res://simulation/experience_distribution.gd").distribute(victim, [self], ended)

func grant(amount: int) -> void:
	if amount <= 0 or player.level >= MAX_LEVEL: return
	player.experience += amount
	while player.level < MAX_LEVEL and player.experience >= required_experience():
		player.experience -= required_experience()
		player.level += 1
		player.skill_points += 1
		player.damage += DAMAGE_GROWTH
		player.max_hp += HEALTH_GROWTH
		player.max_mana += MANA_GROWTH
		# 升级只增加上限，避免把成长顺便实现为免费治疗。
		leveled.emit(player.level)
	if player.level == MAX_LEVEL: player.experience = 0
