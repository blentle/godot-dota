extends Control
## 队友或计分板头像：死亡时叠加预导出的灰度图，大招 CD 使用独立数字层。

func update_state(btn: Texture2D, disbtn: Texture2D, alive: bool, ultimate_cd: float = 0.0) -> void:
	$Portrait.texture = btn
	$Dead.texture = disbtn
	$Dead.visible = not alive
	$Cooldown.text = str(ceili(ultimate_cd)) if alive and ultimate_cd > 0 else ""
