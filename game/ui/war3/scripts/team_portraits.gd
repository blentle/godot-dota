extends Control
## 固定五个队友头像，死亡灰图和大招冷却互不替代。

func set_team(players: Array) -> void:
	for index in range(5):
		var cell: Control = get_node("Portrait%d" % index)
		cell.visible = index < players.size()
		if not cell.visible: continue
		var data: Dictionary = players[index]
		cell.update_state(data.get("portrait"), data.get("dead_portrait"), data.get("alive", true), float(data.get("ultimate_cd", 0)))
