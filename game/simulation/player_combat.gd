extends RefCounted
## 玩家战斗视角：共享实体和伤害裁定，私有账本和施法者固定为已分配英雄。

signal combat_event(event: Dictionary)
var core: RefCounted
var player: RefCounted
var score: Dictionary
var units: Dictionary:
	get: return core.units
var enemy: RefCounted:
	get: return core.enemy
var chain: RefCounted:
	get: return core.chain
var projectiles: RefCounted:
	get: return core.projectiles
var gold: int:
	get: return score.gold
	set(value): score.gold = value
var kills: int:
	get: return score.kills
var deaths: int:
	get: return score.deaths
var last_hits: int:
	get: return score.last_hits

func _init(shared: RefCounted, hero: RefCounted) -> void:
	core = shared
	player = hero
	score = core.accounts[player.id]
	core.combat_event.connect(_forward)

func _forward(event: Dictionary) -> void:
	combat_event.emit(event)

func attack(actor: RefCounted, target: RefCounted) -> String:
	return core.attack(actor, target)

func cast_strike(target: RefCounted) -> String:
	return core.cast_strike(target, player)

func cancel_attack(actor: RefCounted) -> void:
	core.cancel_attack(actor)

func apply_damage(actor: RefCounted, target: RefCounted, damage: float) -> void:
	core.apply_damage(actor, target, damage)

func register(unit: RefCounted) -> void:
	core.register(unit)

func nearest_enemy(actor: RefCounted, reach: float, prefer_creeps: bool = false) -> RefCounted:
	return core.nearest_enemy(actor, reach, prefer_creeps)

func dispose() -> void:
	core.combat_event.disconnect(_forward)
