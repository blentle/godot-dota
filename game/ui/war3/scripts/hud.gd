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
