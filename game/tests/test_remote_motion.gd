extends SceneTree
## 网络表现边界：生命代次变化、停包上限、重复事件及断线不能改变显示状态。

class Connection extends RefCounted:
	signal received(message: Dictionary)
	func send(_message: Dictionary) -> Error: return OK

var failures := 0

func _initialize() -> void:
	var session := preload("res://network/dev_session.gd").new()
	session.open_world("guardian")
	var remote := preload("res://network/remote_world.gd").new(Connection.new())
	remote.apply(_packet(session))
	var player: RefCounted = session.world.combat.player
	var start: Vector3 = remote.position
	player.position += Vector3(4, 0, 0)
	session.tick += 1
	remote.apply(_packet(session))
	remote.step(0.05)
	_check(remote.position.is_equal_approx(start + Vector3(2, 0, 0)), "普通移动必须平滑")
	player.life_id += 1
	player.position = start + Vector3(1, 0, 0)
	session.tick += 1
	remote.apply(_packet(session))
	_check(remote.position == player.position, "近距离复活也必须立即就位")
	var tower: RefCounted = session.world.combat.units.tower_1_0
	session.world.combat.projectiles.launch(tower, player)
	session.tick += 1
	remote.apply(_packet(session))
	remote.step(0.1)
	var shot: Dictionary = remote.combat.projectiles.active.values()[0]
	var at: Vector3 = shot.position
	remote.step(10)
	_check(shot.position == at, "停包后不得无限外推弹道")
	var observed: Array = []
	remote.combat.combat_event.connect(func(event: Dictionary) -> void: observed.append(event))
	session.world.combat.combat_event.emit({"type": "spell", "actor": "player", "position": player.position})
	session.tick += 1
	var events := _packet(session)
	remote.apply(events)
	_check(observed.size() == 1, "正常事件应显示一次")
	events.tick += 1
	remote.apply(events)
	_check(observed.size() == 1, "重复事件不能重复播放")
	session.tick = int(events.tick) + 1
	session.world.combat.combat_event.emit({"type": "spell", "actor": "player", "position": player.position})
	player.life_id += 1
	remote.apply(_packet(session))
	_check(observed.size() == 1, "上一生命代次的特效不能作用于复活单位")
	remote.disable()
	at = remote.position
	player.position += Vector3(3, 0, 0)
	session.tick += 1
	remote.apply(_packet(session))
	remote.step(5)
	_check(remote.position == at and not remote.economy.enabled, "断线后迟到快照不能恢复操作或继续运动")
	if failures == 0: print("远程表现边界通过：平滑、复活、停包、事件去重、生命隔离与断线冻结。")
	quit(1 if failures else 0)

func _packet(session: RefCounted) -> Dictionary:
	return JSON.parse_string(JSON.stringify(session.snapshot()))

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
