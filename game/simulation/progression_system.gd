extends RefCounted
## 单英雄开发成长规则：按死亡生命代次结算附近经验，与补刀金币独立。

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
	if victim == null or victim.alive(): return
	if victim.experience_claimed_life == victim.life_id: return
	# 无论是否有人能拿经验，本次死亡都只能处理一次。
	victim.experience_claimed_life = victim.life_id
	if ended or not player.alive() or player.level >= MAX_LEVEL: return
	if victim.team == player.team or victim.kind not in ["hero", "creep"]: return
	if player.position.distance_to(victim.position) > EXPERIENCE_RANGE: return
	if victim.experience_reward <= 0: return
	player.experience += victim.experience_reward
	while player.level < MAX_LEVEL and player.experience >= required_experience():
		player.experience -= required_experience()
		player.level += 1
		player.damage += DAMAGE_GROWTH
		player.max_hp += HEALTH_GROWTH
		player.max_mana += MANA_GROWTH
		# 升级只增加上限，避免把成长顺便实现为免费治疗。
		leveled.emit(player.level)
	if player.level == MAX_LEVEL: player.experience = 0
