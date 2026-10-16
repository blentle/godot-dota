extends RefCounted
## 存档生命周期；损坏文件阻止启动，过期凭据不会因重启重新延长。

const State = preload("res://network/checkpoint/authority_state.gd")
const Schema = preload("res://network/checkpoint/checkpoint_schema.gd")
var storage := preload("res://network/checkpoint/checkpoint_file.gd").new()
var path := ""
var error := ""
var unix_clock: Callable = Time.get_unix_time_from_system

func load_authority(fallback: RefCounted) -> RefCounted:
	error = ""
	if path.is_empty() or not FileAccess.file_exists(path): return fallback
	var data := storage.read(path)
	if not storage.error.is_empty():
		error = storage.error
		return null
	if not Schema.valid(data):
		error = "存档版本、字段或引用不兼容"
		return null
	if data.state.is_empty(): return fallback
	if data.state.teams != fallback.teams:
		error = "存档席位数与启动参数不一致"
		return null
	return State.restore(data, unix_clock.call())

func save(authority: RefCounted) -> bool:
	if path.is_empty(): return true
	var data := State.capture(authority, unix_clock.call())
	if not storage.write(path, data):
		error = storage.error
		return false
	return true
