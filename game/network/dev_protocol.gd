extends RefCounted
## 本机网络切片的白名单协议；只使用 JSON，不反序列化对象。

const VERSION := 1
const BUILD := "m2-network-1"
const MAX_BYTES := 4096
const MATCH_ID := "local-development"

static func identity() -> Dictionary:
	return {"version": VERSION, "build": BUILD, "content": FileAccess.get_sha256("res://content/6.83d/manifest.json")}

static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_BYTES: return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary: return {}
	return json.data

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func command_error(message: Dictionary) -> String:
	for key in message:
		if key not in ["type", "match", "sequence", "command", "target"]: return "UNEXPECTED_FIELD"
	if message.get("match") != MATCH_ID: return "MATCH_MISMATCH"
	if not integer(message.get("sequence"), 1, 2147483647): return "BAD_SEQUENCE"
	var command: Variant = message.get("command")
	var target: Variant = message.get("target")
	match command:
		"move":
			if not target is Array or target.size() != 2: return "BAD_TARGET"
			for coordinate in target:
				if not (coordinate is int or coordinate is float): return "BAD_TARGET"
				if not is_finite(float(coordinate)) or absf(float(coordinate)) > 48: return "BAD_TARGET"
		"attack", "buy":
			if not target is String or target.is_empty() or target.length() > 64: return "BAD_TARGET"
		"sell":
			if not integer(target, 0, 5): return "BAD_TARGET"
		"cast":
			if target not in ["strike", "area", "summon"]: return "BAD_TARGET"
		"stop", "hold":
			if target != null: return "BAD_TARGET"
		_: return "UNKNOWN_COMMAND"
	return ""
