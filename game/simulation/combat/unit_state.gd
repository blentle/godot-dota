extends RefCounted
## 战斗单位的权威状态；当前数值仅用于训练，不代表 6.83d 英雄。

var id := ""
var team := 0
var kind := "hero"
var role := "melee"
var projectile_speed := 0.0
var life_id := 0
var can_respawn := true
var invulnerable := false
var reward := 50
var radius := 0.0
var corpse_time := 0.0
var position := Vector3.ZERO
var spawn := Vector3.ZERO
var max_hp := 600.0
var hp := 600.0
var max_mana := 240.0
var mana := 240.0
var damage := 55.0
var move_speed := 7.0
var attack_interval := 1.0
var attack_range := 2.4
var attack_cooldown := 0.0
var skill_cooldown := 0.0
var windup := 0.0
var pending_target_id := ""
var stunned := 0.0
var respawn_remaining := 0.0

func alive() -> bool:
	return hp > 0.0

func reset() -> void:
	life_id += 1
	corpse_time = 0.0
	hp = max_hp
	mana = max_mana
	position = spawn
	attack_cooldown = 0.0
	skill_cooldown = 0.0
	windup = 0.0
	pending_target_id = ""
	stunned = 0.0
	respawn_remaining = 0.0
