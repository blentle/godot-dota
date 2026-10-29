extends SceneTree
## 独立原始时钟必须支持精确序列、暂停、零推进和重复绑定。
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "res://ui/war3/scenes/retail_clock.tscn"
	if not ResourceLoader.exists(path):
		check(false,"缺少原始时钟组件")
		quit(1)
		return
	var clock = load(path).instantiate()
	root.add_child(clock)
	clock.set_process(false)
	check(clock.model != null,"必须加载原始模型")
	check(clock.model.surfaces.size()==13,"必须保留原始十三个网格")
	check(clock.model.skeleton.get_bone_count()==clock.model.data.Nodes.size(),"路径式原始骨名不得造成骨索引错位")
	check(clock.model.data.Sequences[0].Name=="Stand" and clock.model.data.Sequences[1].Name=="Stand Alternate","必须保留原始两段序列名称")
	for index in range(2):
		clock.sample_sequence(index,15)
		check(clock.model.sequence==index and is_equal_approx(clock.model.clock,15000),"应按准确序列取样")
	clock.paused=true
	clock.advance(1)
	check(is_equal_approx(clock.model.clock,15000),"暂停不得推进")
	clock.paused=false
	clock.advance(1)
	check(is_equal_approx(clock.model.clock,16000),"恢复应推进")
	clock.advance(0)
	check(is_equal_approx(clock.model.clock,16000),"零推进不得改变时钟")
	clock.sample_sequence(-1,100)
	check(is_equal_approx(clock.model.clock,16000),"无效序列不能改写当前时间")
	clock.configure_race("nightelf")
	check(clock.bind_model(clock.MODEL_PATH),"重复绑定应成功")
	check(clock.get_node("Viewport/World").get_child_count()==2,"重复绑定不得积累旧模型")
	check(clock.frame_race=="nightelf" and clock.dynamic,"重复绑定应保留近卫配置")
	clock.configure_race("undead")
	check(not clock.dynamic and not clock.texture is ViewportTexture,"未验证种族应保留静态入口")
	clock.queue_free()
	await process_frame
	print("原始时钟回归，失败数：",failures)
	quit(1 if failures else 0)
