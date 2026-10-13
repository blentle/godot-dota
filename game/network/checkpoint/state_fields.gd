extends RefCounted
## 权威存档字段白名单；不保存对象、脚本或信号连接。

const UNIT := ["id", "owner_id", "profile_id", "team", "kind", "role", "projectile_speed", "life_id",
	"level", "experience", "experience_reward", "experience_claimed_life", "can_respawn", "invulnerable",
	"reward", "radius", "corpse_time", "position", "spawn", "max_hp", "hp", "max_mana", "mana", "damage",
	"move_speed", "attack_interval", "attack_range", "attack_cooldown", "skill_cooldown", "area_cooldown",
	"summon_cooldown", "windup", "pending_target_id", "stunned", "respawn_remaining"]
const WORLD := ["path", "order", "elapsed", "attacking", "target_id", "chase_refresh", "_result"]
const ECONOMY := ["slots", "bonus", "income_remaining"]
const SUMMON := ["active_id", "remaining", "serial", "path", "refresh"]
const MATCH := ["phase", "winner", "wave", "next_wave"]
const SESSION := ["sequence", "tick", "last_reply", "event_sequence", "dropped_events"]

static func capture(object: RefCounted, fields: Array) -> Dictionary:
	var result := {}
	for field in fields: result[field] = object.get(field)
	return result.duplicate(true)

static func matches(object: RefCounted, fields: Array, data: Variant) -> bool:
	if not data is Dictionary or data.size() != fields.size(): return false
	for field in fields:
		if not data.has(field) or typeof(data[field]) != typeof(object.get(field)): return false
	return values_safe(data)

static func apply(object: RefCounted, fields: Array, data: Dictionary) -> void:
	for field in fields:
		# 赋值时保留 GDScript 的带类型数组声明。
		if object.get(field) is Array: object.get(field).assign(data[field])
		else: object.set(field, data[field])

static func values_safe(value: Variant, depth: int = 0) -> bool:
	if depth > 20: return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_VECTOR3: return value.is_finite()
		TYPE_PACKED_VECTOR3_ARRAY:
			for point in value:
				if not point.is_finite(): return false
			return true
		TYPE_ARRAY:
			for item in value:
				if not values_safe(item, depth + 1): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not (key is String or key is int) or not values_safe(value[key], depth + 1): return false
			return true
	return false
