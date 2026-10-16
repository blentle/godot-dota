extends RefCounted
## 本机存档原子替换与完整性校验；只解码值类型，不允许反序列化对象。

const LIMIT := 8 * 1024 * 1024
const MAGIC := "DOTA-CP1"
var error := ""

func write(path: String, data: Dictionary) -> bool:
	error = ""
	var payload := var_to_bytes(data)
	if payload.size() > LIMIT: return _fail("存档超过容量上限")
	var temporary := path + ".pending"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _fail("无法创建存档临时文件")
	if not OS.has_feature("windows"):
		if FileAccess.set_unix_permissions(temporary, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER) != OK:
			file.close()
			return _fail("无法限制存档文件权限")
	file.store_buffer(MAGIC.to_utf8_buffer())
	file.store_buffer(_digest(payload))
	file.store_buffer(payload)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK: return _fail("存档写入失败")
	if DirAccess.rename_absolute(temporary, path) != OK: return _fail("存档原子替换失败")
	return true

func read(path: String) -> Dictionary:
	error = ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("无法打开存档")
		return {}
	if file.get_length() < 40 or file.get_length() > LIMIT + 40:
		_fail("存档长度非法")
		return {}
	if file.get_buffer(8).get_string_from_utf8() != MAGIC:
		_fail("存档格式不支持")
		return {}
	var digest := file.get_buffer(32)
	var payload := file.get_buffer(file.get_length() - 40)
	if _digest(payload) != digest:
		_fail("存档校验失败")
		return {}
	var data: Variant = bytes_to_var(payload)
	if not data is Dictionary or not preload("res://network/checkpoint/state_fields.gd").values_safe(data):
		_fail("存档包含非法值")
		return {}
	return data

func _digest(payload: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish()

func _fail(reason: String) -> bool:
	error = reason
	return false
