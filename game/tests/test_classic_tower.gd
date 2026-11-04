extends SceneTree
## 防御塔只替换外观：形态、死亡、暂停和命中状态不得改写规则。
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "res://presentation/classic/tower_view.gd"
	if not ResourceLoader.exists(path):
		check(false, "缺少原始防御塔视图")
		quit(1)
		return
	for team in [0, 1]:
		var tower = load(path).new()
		root.add_child(tower)
		check(tower.build(team), "两阵营原始塔必须加载成功")
		var state = load("res://simulation/combat/unit_state.gd").new()
		state.hp = 500
		state.max_hp = 500
		tower.sync_state(state, 0.5)
		var name: String = tower.model.data.Sequences[tower.model.sequence].Name
		check(name == ("Stand" if team == 0 else "Stand Upgrade First"), "必须使用扎根大树或灵魂塔形态")
		var clock: float = tower.model.clock
		tower.sync_state(state, 0)
		check(tower.model.clock == clock, "暂停不能推进建筑动画")
		tower.react({"type": "swing"})
		check("Attack" in str(tower.model.data.Sequences[tower.model.sequence].Name), "攻击事件应播放原始动画")
		state.hp = 0
		tower.sync_state(state, 0.1)
		check("Death" in str(tower.model.data.Sequences[tower.model.sequence].Name), "死亡应播放原始动画而非压扁模型")
		check(tower.scale == Vector3.ONE and state.hp == 0, "表现不得改变规则生命或压缩建筑")
		if team == 1:
			tower.model.animation_tags = PackedStringArray(["upgrade", "second"])
			tower.model.play("Stand", true)
			check(tower.model.data.Sequences[tower.model.sequence].Name == "Stand Upgrade Second", "四级源配置不得误选第一级升级形态")
		tower.free()
	# 比较两种表现路径，确保只替换六座塔，不重复登记障碍或改动状态。
	var terrain_script = load("res://world/terrain_builder.gd")
	var world_script = load("res://simulation/training_world.gd")
	var legacy = terrain_script.new()
	var classic = terrain_script.new()
	var baseline = world_script.new()
	var world = world_script.new()
	root.add_child(legacy)
	root.add_child(classic)
	classic.classic_art = true
	legacy.build(baseline)
	classic.build(world)
	check(classic.building_views.size() == 8, "必须保留六座塔及两个训练基地")
	var towers := 0
	for position in classic.building_views:
		var view = classic.building_views[position]
		if view.has_method("sync_state"): towers += 1
	check(towers == 6, "仅六座防御塔替换为原始模型")
	check(world.obstacles == baseline.obstacles, "外观替换不得改变障碍登记")
	classic.free()
	legacy.free()
	print("原始防御塔检查：", failures)
	quit(0 if failures == 0 else 1)
