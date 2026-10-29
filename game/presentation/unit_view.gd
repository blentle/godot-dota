extends Node3D
## 单位视图：读取状态绘制临时模型、血条与攻击反馈，不修改规则数据。

const Geometry = preload("res://presentation/mesh_factory.gd")
var visual_resource := ""
var visual_tags: PackedStringArray = []
var visual_scale := 1.0
var visual_color := Color.WHITE
var classic_model: Node3D
var action_remaining := 0.0
var geometry := Geometry.new()
var model := Node3D.new()
var ring: MeshInstance3D
var health: MeshInstance3D
var health_back: MeshInstance3D
var hit_remaining := 0.0
var swing_remaining := 0.0
var effect_continuity := preload("res://presentation/classic/effect_continuity.gd").new()

func build(color: Color) -> void:
	add_child(model)
	if not visual_resource.is_empty():
		replace_classic_model()
	else:
		geometry.cylinder(model, Vector3(0, 1.1, 0), 0.48, 1.4, color, 0.64)
		geometry.box(model, Vector3(0, 1.4, 0.34), Vector3(0.85, 1.4, 0.13), color.darkened(0.45))
		geometry.cylinder(model, Vector3(0, 2.08, 0), 0.35, 0.55, Color("b4b8af"), 0.26)
		geometry.box(model, Vector3(0, 2.08, -0.29), Vector3(0.44, 0.12, 0.14), Color("172329"))
		for x in [-0.3, 0.3]:
			geometry.box(model, Vector3(x, 0.35, 0), Vector3(0.3, 0.7, 0.45), Color("444943"))
			geometry.cylinder(model, Vector3(x * 2, 1.55, 0), 0.3, 0.4, Color("a9b6b5"))
		geometry.box(model, Vector3(0.83, 1.05, -0.55), Vector3(0.13, 0.14, 1.7), Color("d9dcce"))
		geometry.box(model, Vector3(0.83, 1.05, 0.03), Vector3(0.6, 0.15, 0.12), Color("b89859"))
		geometry.box(model, Vector3(-0.8, 1.0, -0.1), Vector3(0.14, 1.0, 0.7), color)
	var shape := TorusMesh.new()
	shape.inner_radius = 0.90
	shape.outer_radius = 1.04
	ring = geometry.mesh(self, shape, Vector3(0, 0.12, 0), Color("99eb54"))
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("99eb54")
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	health_back = geometry.box(self, Vector3(0, 2.9, 0), Vector3(1.9, 0.13, 0.13), Color("151b13"))
	health = geometry.box(self, Vector3(0, 2.92, 0.06), Vector3(1.8, 0.09, 0.13), color)

func replace_classic_model() -> void:
	if is_instance_valid(classic_model):
		model.remove_child(classic_model)
		classic_model.queue_free()
	classic_model = preload("res://presentation/classic/model_view.gd").new()
	model.add_child(classic_model)
	if not classic_model.load_model(visual_resource, 1, visual_color): return
	classic_model.animation_tags = visual_tags
	classic_model.play("Stand")
	classic_model.advance(0)
	classic_model.scale *= visual_scale
	action_remaining = 0

func sync(state: RefCounted, selected: bool, delta: float, target: Vector3) -> void:
	# 同一单位标识复活或位置突然跳变时，旧飘带/粒子不能跨出生点连接。
	if effect_continuity.observe(state.position, state.life_id):
		action_remaining = 0
		if is_instance_valid(classic_model): classic_model.reset_effects()
	var direction: Vector3 = state.position - position
	position = state.position
	if state.windup > 0: direction = target - position
	if direction.length_squared() > 0.0001:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 14, 1))
	ring.visible = selected and state.alive()
	health.visible = state.alive()
	health_back.visible = state.alive()
	var ratio: float = maxf(0.001, state.hp / state.max_hp)
	health.scale.x = ratio
	health.position.x = -0.9 * (1 - ratio)
	hit_remaining = maxf(0, hit_remaining - delta)
	swing_remaining = maxf(0, swing_remaining - delta)
	if is_instance_valid(classic_model):
		action_remaining = maxf(0, action_remaining - delta)
		if not state.alive(): classic_model.play("Death")
		elif action_remaining <= 0: classic_model.play("Walk" if direction.length_squared() > 0.0001 and state.windup <= 0 else "Stand")
		classic_model.advance(delta)
		return
	model.rotation.z = PI / 2 if not state.alive() else 0.0
	model.rotation.x = -sin(swing_remaining * 14) * 0.2 if state.alive() else 0.0
	model.scale = Vector3.ONE * (1.08 if hit_remaining > 0 else 1.0)

func react(event: Dictionary) -> void:
	if event.type == "damage": hit_remaining = 0.12
	if event.type == "swing": swing_remaining = 0.28
	if is_instance_valid(classic_model) and event.type in ["swing", "spell", "area", "summon"]:
		classic_model.play("Attack" if event.type == "swing" else "Spell", true)
		if classic_model.sequence >= 0:
			var interval: Array = classic_model.data.Sequences[classic_model.sequence].Interval
			action_remaining = (interval[1] - interval[0]) / 1000.0
