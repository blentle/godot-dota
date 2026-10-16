# Warcraft III 风格 HUD · Godot 4.7.2 实现交付

## 交付边界与运行

本次按用户指定布局提供场景与交互模块，使用仓库固定 Godot 4.7.2。已移除中断期间建立的 4.3 独立工程与下载目录。默认训练入口暂时保留原 HUD；新增入口用于检查新 HUD，不伪装为已完成游戏数据接入或原版素材还原。

```sh
godot --path game -- --war3-hud
python3 tools/check_war3_hud_assets.py
godot --headless --path game --script res://tests/test_war3_hud.gd
godot --path game -- --war3-hud --capture=/绝对路径/war3-hud.png
```

PNG 目前为程序测试纹理，字体为关闭抗锯齿的系统宋体回退，均不是核验过的原版资源。不能据此声称 95% 还原。坐标实现以本次用户给定组件关系为准，尚未经过指定语言、种族皮肤和原版截图逐像素校对。后续需完成原版 HUD 皮肤、各技能/物品图标及字体来源核验；资源替换契约见 `game/ui/war3/assets/README.md`。

Godot 4 使用 `position`、`size`，没有可直接设置的旧版 `rect_position`、`rect_size`。场景将四个 anchor 固定为 0，并明确写出 offset_left/top/right/bottom，等价于固定 position/size。动态脚本只更新条宽、浮动位置或数据，不动态拼装面板布局。裁剪属性名为 `clip_contents`。

## 1. 场景树

```text
War3HUD (Control，1024×768，hud.tscn / hud.gd)
├── Resources (resources.tscn)
│   ├── Background / GoldIcon / LumberIcon (TextureRect)
│   └── Gold / Lumber (Label)
├── TeamPortraits (team_portraits.tscn)
│   └── Portrait0…4 (portrait_cell.tscn)
│       └── Portrait / Dead / Frame (TextureRect), Cooldown (Label)
├── Multiboard (multiboard.tscn)
│   ├── Background (TextureRect), Header… (Label)
│   └── Row0…9 (multiboard_row.tscn)
│       ├── Line (TextureRect), Icon (small_portrait.tscn)
│       └── PlayerName / Kills / Deaths / Assists / Gold (Label)
├── Minimap (minimap.tscn)
│   ├── MapTexture / Frame (TextureRect)
│   └── MapViewport (SubViewport，256×256)
│       ├── Map (TextureRect，仅独立预览的地图测试图)
│       └── Renderer (Control，真实训练地图与单位渲染)
├── HeroPanel (hero_panel.tscn)
│   ├── Background / Portrait / PortraitFrame (TextureRect)
│   ├── HeroName (Label)
│   ├── Health / Mana / Experience (*_bar.tscn)
│   │   ├── Background (TextureRect)
│   │   ├── Clip (Control，clip_contents=true)
│   │   │   └── Fill (TextureRect，始终保持完整宽度)
│   │   └── Value (Label)
│   ├── Attributes (attributes.tscn)
│   │   └── Strength / Agility / Intelligence (Control)
│   │       └── Icon (TextureRect), Value (Label)
│   ├── Skill0…3 (icon_button.tscn)
│   └── Item0…5 (icon_button.tscn)
│       └── BTN / AHK / DISBTN (TextureRect), CooldownText (Label)
├── Tooltip (tooltip.tscn)
│   └── Background (TextureRect), Title / Description (Label)
└── FloatingTextPool (Control)
    └── 64 个预分配 floating_text.tscn (Control → Text/Label)
```

`preview.tscn` 是独立测试场景，包含 HUD、测试背景和用于投影的相机/单位；其模拟倒计时不属于实际 HUD 的权威逻辑。浮字池在进入场景时预分配，复用既有场景实例，不在战斗中创建 Label。

## 2. 动态脚本与数据契约

| 模块 | 源文件，相对 `game/ui/war3/scripts/` | 职责 |
| --- | --- | --- |
| HUD 主脚本 | `hud.gd` | 接收状态，刷新组件，转发技能/物品点击 |
| 技能与物品按钮 | `icon_button.gd` | BTN/AHK/DISBTN 图层、CD 数字、点击及提示事件 |
| 血蓝经验条 | `clipped_bar.gd` | 校验比例、裁剪容器宽度、数值文字 |
| Multiboard | `multiboard.gd` | 固定十行数据刷新、死亡头像、空行隐藏 |
| 提示框 | `tooltip.gd` | 0.35 秒延迟、离开取消、固定画布边界约束 |
| 浮字池 | `floating_text_pool.gd` | 32 项伤害、32 项 ALT 血量、单位投影与弱引用 |
| 队友头像 | `team_portraits.gd`、`portrait_cell.gd` | 五头像、死亡图与大招 CD |
| 测试驱动 | `preview.gd` | 仅演示数据与截图，不作为游戏规则 |

实际接入调用 `hud.apply_state(data)`；字段示例见 `preview.gd.sample_state()`。技能与物品数据必须提供 `btn`、`ahk`、`disbtn` 三个 Texture2D，以及 title、description、cooldown、disabled。点击只发出 `skill_clicked(index)` 或 `item_clicked(index)`，调用方送入现有权威命令入口。

主 HUD 不自行递减 CD，不计算力量/敏捷/智力、助攻或大招规则；没有真实数据的属性与金币列可传 null 并显示“—”。现有训练规则未提供完整经典属性、助攻和第四技能，因此尚未将这些字段伪造后接入战斗默认界面。

血量显示调用浮字池 `set_health_targets([{target: weakref(unit_view), hp: 100, max_hp: 200}])`；伤害事件调用 `damage(unit_view, amount)`，相机设置为池的 `camera`。RenderTexture 对应 Godot 的 ViewportTexture；可使用当前 SubViewport，也可通过 `set_minimap_texture()` 注入已有小地图视口纹理。

所有脚本完整正文位于本文末尾，实际实现以同名 `.gd` 文件为准。

## 3. 资源导入与渲染设置

| 范围 | 设置 |
| --- | --- |
| 引擎 | Godot 4.7.2 Standard / GDScript |
| HUD 画布 | 1024×768，预览窗口固定大小；四锚点全部 0 |
| CanvasItem | `texture_filter = 1`（Nearest），`texture_repeat = 1`（Disabled） |
| PNG | 所有宽、高均为二次幂，`compress/mode=0`（Lossless） |
| Mipmap | `.png.import` 中 `mipmaps/generate=false` |
| Alpha | 非预乘，`process/premult_alpha=false`；测试纹理不自动扩边 |
| 视口抗锯齿 | MSAA 2D/3D Disabled、Screen Space AA Disabled、TAA false |
| 字体 | 当前 `SystemFont.antialiasing=0`、`subpixel_positioning=0`、MSDF false |
| 正式字体替换 | 以核验的 FontFile 或位图字体替换 `assets/font.tres`；保持无 AA、无 MSDF |
| LabelSettings | 主文字 #FFD200、提示 #FFFFFF、伤害 #FF2222；outline_size=0、shadow_size=0 |
| 背景与边框 | 仅 PNG + TextureRect；没有 Theme、StyleBox、圆角、shader 或自动布局 |

Godot 4 的 Filter/Repeat 属于 CanvasItem 采样设置，不是在 PNG 导入器里填写不存在的旧版开关。每张 PNG 的实际导入文件已保存；移动文件后由 4.7.2 重新生成导入路径。不要通过 `modulate` 或 shader 将 BTN 改成灰图。

默认行为：BTN 始终处于底层；可用且 hover 时显示透明 AHK 边框；CD>0 或 disabled 时顶层 DISBTN 可见，AHK 隐藏。只有 CD>0 时显示向上取整的 CD 数字；禁用但无 CD 时不伪造数字。

## 4. 固定坐标表

下表为屏幕绝对坐标，单位为像素。矩形记作 `(x, y, 宽, 高)`。重复项公式展开后就是每一个实际节点坐标；没有流式布局。

| 元素 | 坐标与尺寸 |
| --- | --- |
| HUD / 浮字池 | `(0, 0, 1024, 768)` |
| 资源面板 / 背景 | `(8, 8, 240, 32)` |
| 金币图标 / 数字 | `(12, 12, 24, 24)` / `(40, 14, 76, 20)` |
| 木头图标 / 数字 | `(132, 12, 24, 24)` / `(160, 14, 76, 20)` |
| 五头像栏根 | `(318, 8, 280, 48)` |
| 队友头像 i=0…4 / Frame / CD | `(318+56i, 8, 48, 48)` |
| 队友彩色与死亡图 i=0…4 | `(320+56i, 10, 44, 44)` |
| Multiboard 根 / 背景 | `(676, 72, 340, 268)` |
| 表头玩家 / 杀 / 死 / 助 / 金币 | x=`708/824/856/888/920`，y=`74`，宽=`112/32/32/32/88`，高=`20` |
| 第 i 行 i=0…9 / Line | `(680, 96+24i, 332, 24)` |
| 第 i 行头像根 / CD | `(680, 96+24i, 24, 24)` |
| 第 i 行彩色 / 死亡头像 | `(681, 97+24i, 22, 22)` |
| 第 i 行姓名 / K / D / A / 金币 | x=`708/824/856/888/920`，y=`98+24i`，宽=`112/32/32/32/88`，高=`20` |
| 小地图根 / Frame | `(4, 572, 192, 192)` |
| 小地图显示纹理 | `(12, 580, 176, 176)`；其内部渲染视口固定 256×256 |
| 英雄面板根 / Background | `(196, 552, 828, 216)` |
| 英雄名称 | `(212, 556, 530, 20)` |
| 头像框 / 内部头像 | `(212, 580, 128, 128)` / `(216, 584, 120, 120)` |
| HP 背景 / Clip / Fill | `(352, 580, 256, 16)`；仅 Clip 宽度随比例改变 |
| HP 数字 | `(352, 578, 256, 20)` |
| MP 背景 / Clip / Fill | `(352, 602, 256, 16)`；仅 Clip 宽度随比例改变 |
| MP 数字 | `(352, 600, 256, 20)` |
| 属性组根 | `(352, 634, 256, 32)` |
| 力/敏/智小组 i=0…2 | `(352+84i, 634, 80, 32)` |
| 力/敏/智图标 i=0…2 | `(352+84i, 634, 32, 32)` |
| 力/敏/智数字 i=0…2 | `(388+84i, 640, 44, 20)` |
| 四技能 i=0…3 | `(764+60i, 572, 48, 48)` |
| 六物品 i=0…5 | `(764+60(i%3), 632+60⌊i/3⌋, 48, 48)` |
| 技能/物品 BTN、AHK、DISBTN、CD | 与对应按钮矩形完全相同，按层叠放 |
| 经验条 Background / Clip / Fill | `(212, 748, 796, 8)`；Clip 宽度按经验比例取整 |
| 经验数值节点 | `(212, 746, 796, 20)`，当前调用关闭数字显示 |
| Tooltip 初始根 / 背景 | `(688, 368, 320, 160)`，初始隐藏 |
| Tooltip 标题 / 描述相对框的位置 | `(12, 10, 296, 22)` / `(12, 38, 296, 108)` |
| Tooltip 动态位置 | x=`clamp(mouse.x+16,0,704)`，y=`clamp(mouse.y-172,0,608)`，向下取整 |
| 浮字实例 / Text | `120×20`，实例位置由单位屏幕投影计算并取整，Text 相对 `(0,0)` |

浮字只显示在 `(0,0,1024,552)` 战场区，镜头后方或已销毁单位不显示；移动跟随单位视图，不将三维位置当作 UI 像素坐标。ALT 松开即隐藏血量文字，伤害超过 32 项时替换最旧项。

## 验证记录

2026-10-13，Godot 4.7.2 / macOS Apple Silicon：PNG 尺寸与导入检查通过；场景行为测试覆盖血量裁剪及零上限、BTN/AHK/DISBTN、CD 取整、视口鼠标点击、提示延迟取消及快照刷新不重置延迟、死亡头像、助攻文本、队友大招 CD、空行清理、ViewportTexture、浮字复用上限、ALT 输入及销毁单位清理。已查看真实窗口 1024×768 截图。

未验收：Windows/Linux/macOS Intel、真实 1.26 字体及资源匹配、原版像素相似度、默认战斗 HUD 替换与全部游戏字段接入。没有宣称 DirectX 8 后端；这里使用兼容渲染器和规定的采样/字体设置模拟其 UI 显示特征。

## 附：对应 GDScript 完整正文

### hud.gd

```gdscript
extends Control
## 固定 1024×768 HUD 的表现入口；收到快照后刷新，不推导助攻、属性或物品 CD。

signal skill_clicked(index: int)
signal item_clicked(index: int)

func _ready() -> void:
	for index in range(4):
		_bind($HeroPanel.get_node("Skill%d" % index), index, true)
	for index in range(6):
		_bind($HeroPanel.get_node("Item%d" % index), index, false)

func _bind(button: Control, index: int, skill: bool) -> void:
	button.tooltip_entered.connect($Tooltip.request)
	button.tooltip_exited.connect($Tooltip.cancel)
	button.activated.connect(func():
		if skill: skill_clicked.emit(index)
		else: item_clicked.emit(index))

func apply_state(data: Dictionary) -> void:
	var hero: Dictionary = data.get("hero", {})
	$HeroPanel/Portrait.texture = hero.get("portrait")
	$HeroPanel/HeroName.text = str(hero.get("name", ""))
	$HeroPanel/Health.set_value(float(hero.get("hp", 0)), float(hero.get("max_hp", 0)))
	$HeroPanel/Mana.set_value(float(hero.get("mp", 0)), float(hero.get("max_mp", 0)))
	$HeroPanel/Experience.set_value(float(hero.get("xp", 0)), float(hero.get("xp_required", 0)), false)
	for stat in ["Strength", "Agility", "Intelligence"]:
		var value: Variant = hero.get(stat.to_lower())
		$HeroPanel/Attributes.get_node(stat + "/Value").text = "—" if value == null else str(value)
	$Resources/Gold.text = str(data.get("gold", 0))
	$Resources/Lumber.text = str(data.get("lumber", 0))
	_refresh_slots("Skill", 4, data.get("skills", []))
	_refresh_slots("Item", 6, data.get("items", []))
	$TeamPortraits.set_team(data.get("team", []))
	$Multiboard.set_players(data.get("players", []))

func _refresh_slots(prefix: String, count: int, values: Array) -> void:
	for index in range(count):
		var button: Control = $HeroPanel.get_node(prefix + str(index))
		var data: Dictionary = values[index] if index < values.size() else {}
		button.set_icon(data.get("btn"), data.get("ahk"), data.get("disbtn"), str(data.get("title", "")), str(data.get("description", "")))
		button.set_state(float(data.get("cooldown", 0)), bool(data.get("disabled", true)))

func set_minimap_texture(texture: Texture2D) -> void:
	$Minimap/MapTexture.texture = texture
```

### icon_button.gd

```gdscript
extends Control
## 原版式 BTN/AHK/DISBTN 独立图层；只提交点击，不改权威技能或物品状态。

signal activated
signal tooltip_entered(owner: Control, title: String, description: String)
signal tooltip_exited(owner: Control)
var caption := ""
var description := ""
var cooldown := 0.0
var unavailable := false
var hovered := false
var pressed_inside := false

func _ready() -> void:
	mouse_entered.connect(_enter)
	mouse_exited.connect(_exit)
	focus_exited.connect(func(): pressed_inside = false)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): _exit())
	_refresh()

func set_icon(btn: Texture2D, ahk: Texture2D, disbtn: Texture2D, title: String, body: String) -> void:
	var changed := title != caption or body != description
	$BTN.texture = btn
	$AHK.texture = ahk
	$DISBTN.texture = disbtn
	caption = title
	description = body
	if hovered and changed: tooltip_entered.emit(self, caption, description)

func set_state(seconds: float, disabled: bool) -> void:
	# CD 由外部权威状态更新；显示层不倒计时决定技能可用性。
	cooldown = maxf(seconds, 0.0)
	unavailable = disabled
	_refresh()

func _refresh() -> void:
	# 按下期间变为冷却或禁用时取消该次点击，不能在解禁后补发。
	if unavailable or cooldown > 0: pressed_inside = false
	$BTN.visible = true
	$AHK.visible = hovered and not unavailable and cooldown <= 0
	$DISBTN.visible = unavailable or cooldown > 0
	$CooldownText.text = str(ceili(cooldown)) if cooldown > 0 else ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW if unavailable or cooldown > 0 else Control.CURSOR_POINTING_HAND

func _enter() -> void:
	hovered = true
	_refresh()
	tooltip_entered.emit(self, caption, description)

func _exit() -> void:
	hovered = false
	pressed_inside = false
	_refresh()
	tooltip_exited.emit(self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			pressed_inside = not unavailable and cooldown <= 0
			grab_focus()
		else:
			var allowed := pressed_inside and get_rect().has_point(position + event.position)
			pressed_inside = false
			if allowed and not unavailable and cooldown <= 0: activated.emit()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
		accept_event()
		if not unavailable and cooldown <= 0: activated.emit()
```

### clipped_bar.gd

```gdscript
extends Control
## 红血、蓝魔法、经验均通过裁剪容器缩短，填充纹理宽度固定，不做拉伸比例动画。

@onready var full_width: float = $Clip.size.x

func set_value(current: float, maximum: float, show_numbers: bool = true) -> void:
	var valid := is_finite(current) and is_finite(maximum) and maximum > 0
	var ratio: float = clampf(current / maximum, 0, 1) if valid else 0.0
	$Clip.size.x = floorf(full_width * ratio)
	$Clip.visible = ratio > 0
	$Value.text = "%d / %d" % [maxi(0, int(current)), maxi(0, int(maximum))] if valid and show_numbers else ""
```

### multiboard.gd

```gdscript
extends Control
## 固定十行 Multiboard；每行已有图标和文本节点，不动态改变表格布局。

func set_players(players: Array) -> void:
	for index in range(10):
		var row: Control = get_node("Row%d" % index)
		row.visible = index < players.size()
		if not row.visible: continue
		var data: Dictionary = players[index]
		row.get_node("Icon").update_state(data.get("portrait"), data.get("dead_portrait"), data.get("alive", true))
		row.get_node("PlayerName").text = str(data.get("name", ""))
		for field in ["Kills", "Deaths", "Assists", "Gold"]:
			# 未公开金币不能用零冒充实际值；数据适配器决定可见范围。
			var value: Variant = data.get(field.to_lower())
			row.get_node(field).text = "—" if value == null else str(value)
```

### tooltip.gd

```gdscript
extends Control
## 老式延迟提示：离开即隐藏，延迟期间移动到另一个图标不会弹出旧提示。

@export var delay := 0.35
var owner_ref: WeakRef
var remaining := 0.0
var pending := false

func request(owner: Control, title: String, body: String) -> void:
	owner_ref = weakref(owner)
	$Title.text = title
	$Description.text = body
	remaining = delay
	pending = not title.is_empty()
	hide()

func cancel(owner: Control) -> void:
	if owner_ref != null and owner_ref.get_ref() == owner: clear()

func clear() -> void:
	owner_ref = null
	pending = false
	hide()

func _process(delta: float) -> void:
	if owner_ref == null: return
	var owner: Control = owner_ref.get_ref()
	if not is_instance_valid(owner) or not owner.is_visible_in_tree():
		clear()
		return
	if not pending: return
	remaining -= delta
	if remaining > 0: return
	pending = false
	# 提示框宽高固定；只在固定画布内调整悬浮位置，保持整数像素。
	var mouse := get_global_mouse_position()
	position = Vector2(clampf(mouse.x + 16, 0, 1024 - size.x), clampf(mouse.y - size.y - 12, 0, 768 - size.y)).floor()
	show()
```

### floating_text_pool.gd

```gdscript
extends Control
## 固定上限浮字池：伤害最多 32 项，ALT 血量使用其余槽位；不在战斗中创建 Label。

const CAPACITY := 64
const DAMAGE_LIMIT := 32
const TEXT_SCENE = preload("res://ui/war3/scenes/floating_text.tscn")
var camera: Camera3D
var slots: Array[Dictionary] = []
var health_targets: Array[Dictionary] = []
var serial := 0

func _ready() -> void:
	for index in range(CAPACITY):
		var cell: Control = TEXT_SCENE.instantiate()
		add_child(cell)
		cell.hide()
		slots.append({"view": cell, "target": null, "life": 0.0, "serial": -1})

func damage(target: Node3D, amount: int) -> void:
	if not is_instance_valid(target): return
	var choice := 0
	for index in range(DAMAGE_LIMIT):
		if slots[index].life <= 0:
			choice = index
			break
		if slots[index].serial < slots[choice].serial: choice = index
	var slot: Dictionary = slots[choice]
	serial += 1
	slot.merge({"target": weakref(target), "life": 1.0, "serial": serial}, true)
	slot.view.get_node("Text").text = str(maxi(0, amount))
	slot.view.get_node("Text").label_settings = preload("res://ui/war3/assets/text_red.tres")

func set_health_targets(values: Array) -> void:
	# 数据中使用 WeakRef，不能因表现层持有对象而延长单位生命周期。
	health_targets.assign(values.slice(0, CAPACITY - DAMAGE_LIMIT))

func _process(delta: float) -> void:
	for index in range(DAMAGE_LIMIT):
		var slot: Dictionary = slots[index]
		slot.life = maxf(0, slot.life - delta)
		var target: Node3D = slot.target.get_ref() if slot.target != null else null
		_place(slot.view, target, slot.life > 0, (1.0 - slot.life) * 28)
	var show_health := Input.is_key_pressed(KEY_ALT)
	for index in range(CAPACITY - DAMAGE_LIMIT):
		var view: Control = slots[index + DAMAGE_LIMIT].view
		if not show_health or index >= health_targets.size():
			view.hide()
			continue
		var data: Dictionary = health_targets[index]
		var target: Node3D = data.target.get_ref()
		view.get_node("Text").text = "%d / %d" % [data.hp, data.max_hp]
		_place(view, target, true, 0)

func _place(view: Control, target: Node3D, enabled: bool, rise: float) -> void:
	if not enabled or not is_instance_valid(target) or not is_instance_valid(camera):
		view.hide()
		return
	var point := target.global_position + Vector3(0, 2.5, 0)
	if camera.is_position_behind(point):
		view.hide()
		return
	var at := camera.unproject_position(point)
	view.visible = Rect2(0, 0, 1024, 552).has_point(at)
	view.position = (at - Vector2(view.size.x / 2, rise + view.size.y)).floor()
```

### portrait_cell.gd

```gdscript
extends Control
## 队友或计分板头像：死亡时叠加预导出的灰度图，大招 CD 使用独立数字层。

func update_state(btn: Texture2D, disbtn: Texture2D, alive: bool, ultimate_cd: float = 0.0) -> void:
	$Portrait.texture = btn
	$Dead.texture = disbtn
	$Dead.visible = not alive
	$Cooldown.text = str(ceili(ultimate_cd)) if alive and ultimate_cd > 0 else ""
```

### team_portraits.gd

```gdscript
extends Control
## 固定五个队友头像，死亡灰图和大招冷却互不替代。

func set_team(players: Array) -> void:
	for index in range(5):
		var cell: Control = get_node("Portrait%d" % index)
		cell.visible = index < players.size()
		if not cell.visible: continue
		var data: Dictionary = players[index]
		cell.update_state(data.get("portrait"), data.get("dead_portrait"), data.get("alive", true), float(data.get("ultimate_cd", 0)))
```


## 真实训练接入（2026-10-15）

新增 `godot --path game -- --war3-training`，由 `live_training.tscn` 装配真实离线规则与经典 HUD。
`training_snapshot.gd` 只读取规则，`live_training.gd` 将按钮转发到现有 `battle.command()`，不自行扣费或递减冷却。
支持右键移动/攻击、Q/W/E、F1、M/A/S/H、方向键镜头、Esc/F10 暂停，以及实际伤害浮字和 ALT 血量。

当前为单对手训练接入：选人和技能升级按钮尚待接入；2026-10-16 已补齐实际小地图及商店，原入口保持可用。
被动装备支持查看和出售，没有主动使用或物品冷却；不存在的第四技能禁用，三围、助攻和木头显示“—”，不补造十名玩家。
顶部队友栏只显示实际本地训练玩家，没有大招数据时不显示虚构倒计时。美术与字体仍是占位资源。

`test_war3_training.gd` 验证按钮施法扣费与冷却、重复施法拒绝、暂停、死亡、真实生命金币与未知字段；新入口在 macOS Godot 4.7.2 无头回归通过。Windows/Linux 尚未验收。


## 真实小地图（2026-10-16）

`--war3-training` 的小地图现使用实际世界障碍、存活单位、阵营和相机投影；底图仍是开发地图示意，未校对原版地图，也没有战争迷雾。
地图显示区绝对位置 `(12,580)`、尺寸 `176×176`，内部 SubViewport 保持 `256×256`；固定坐标与原布局不变。
绘制只使用整数方块和关闭抗锯齿的线段，最终由 Nearest 的 TextureRect 显示视口纹理。
三条地面通路由 `terrain_layout.gd.paths()` 同时提供给场景地形和小地图，避免两个入口的地形显示不一致。

- `minimap_projection.gd`：统一世界 X/Z 与二维地图坐标转换，并裁剪越界拖拽。
- `minimap_renderer.gd`：读取真实障碍、单位、死亡/复活、阵营及相机可见区域，绘制视口内容。
- `minimap_controller.gd`：左键点击或拖动移动镜头，右键通过 `battle.issue_move()` 进入规则导航；暂停和未选中状态不能绕过命令限制。

真实地图绑定后隐藏 `map_test.png`；独立 `--war3-hud` 仍可用该图检查视口，不创建虚构单位。
`test_war3_minimap.gd` 通过真实视口鼠标事件覆盖镜头点击、拖拽、边框点击防穿透、导航路径终点、暂停、未选中、死亡复活和坐标边界。
本轮完成 macOS Godot 4.7.2 无头回归和实际窗口截图检查，Windows/Linux 尚未验收。


## 经典商店接入（2026-10-16）

在 `--war3-training` 按 B 或点击底部“商店 B”打开；点击已拥有的物品格可直接选中该装备。
商店提供四种开发装备，购买和出售通过真实 `submit_buy()` / `submit_sell()` 入口提交，出售返还原价的 50%。
金币不足、背包满、远离己方基地、阵亡和终局由现有规则拒绝；暂停在界面入口拒绝。
商店内展示六个真实背包格，选择后出售；被外部状态替换的槽位会取消选择，防止出售未经再次选择的装备。

打开商店后对局继续运行，但商店阻挡战场和小地图鼠标输入，并拦住 Q/W/E 等战场快捷键。
B / Esc 关闭商店；F10 先关闭商店再暂停。按钮关闭重开、禁用再启用都会取消未完成的按下操作。

| 场景或脚本 | 职责 |
| --- | --- |
| `scenes/shop.tscn` | 固定 1024×768 输入遮挡根和 640×440 面板布局 |
| `scenes/shop_row.tscn` | 固定物品名称、描述及购买按钮 |
| `scenes/shop_inventory.tscn` | 商店中的六个背包镜像格 |
| `scenes/text_action.tscn` | 复用 BTN/AHK/DISBTN 输入逻辑的文字按钮 |
| `scripts/shop.gd` | 规则状态刷新、交易提交、选中槽位与焦点恢复 |
| `tests/test_war3_shop.gd` | 实际鼠标和键盘交易、规则拒绝、暂停、防穿透及旧点击取消回归 |

| 商店元素 | 绝对坐标及尺寸 |
| --- | --- |
| 商店入口按钮 | `(620,700,112,36)` |
| 输入遮挡根 | `(0,0,1024,768)`，无暗色背景、无阴影 |
| 商店面板 | `(192,80,640,440)` |
| 标题 / 说明 / 状态 | `(208,92,440,24)` / `(208,120,608,20)` / `(208,148,608,24)` |
| 关闭按钮 | `(696,88,112,36)` |
| 物品行 i，0≤i<4 | `(208,184+56i,380,52)` |
| 每行名称 / 描述 | `(208,184+56i,252,20)` / `(208,206+56i,252,28)` |
| 购买按钮 i | `(476,188+56i,112,36)` |
| 六格背包 i，0≤i<6 | `(608+56(i%3),216+56⌊i/3⌋,48,48)` |
| 选中物品 / 返还说明 | `(608,332,208,24)` / `(608,360,208,24)` |
| 出售按钮 | `(608,392,112,36)` |
| 交易反馈 | `(208,448,608,56)` |

本轮已完成 macOS Godot 4.7.2 窗口截图检查和交易回归；Windows/Linux 尚未实测。
所有按钮使用既有独立 PNG 图层，文字沿用关闭 AA 的 LabelSettings，没有新增 Theme、shader、自动布局或动画。
原版商店布局、美术和正式物品目录仍未校对；这些开发装备不计入 DotA 6.83d 正式物品完成度。

### 交互检查记录

检查范围为 Godot 经典商店、背包入口和与战场的输入边界，使用既有 TextureRect / Label 体系。

| 类别 | 检查证据 | 结果 |
| --- | --- | --- |
| 字体 | 窗口截图中的名称、价格、状态、出售反馈 | 固定文本区域，无遮挡；字体仍为未核验回退字体 |
| 表面与命中区 | 静态场景、真实鼠标购买/出售与边框点击 | 没有新增圆角或阴影，输入遮挡通过 |
| 动画 | 场景与脚本 | 没有新增动画，不涉及慢放检查 |
| 图标状态 | 可购买、金币不足、背包满、阵亡、关闭重开 | 三层独立 PNG，旧按下操作取消通过 |
| 性能 | 固定四行与六格场景 | 刷新时复用既有节点；未做跨平台性能验收 |

未采用字体平滑、缩放按压或单图动态灰度，因为用户要求无 AA、固定像素布局和独立状态贴图。
交互检查未发现待修复问题；视觉还原度和 Windows/Linux 验收继续列为未完成。
