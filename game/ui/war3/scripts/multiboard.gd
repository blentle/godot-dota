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
