extends Control
## 红血、蓝魔法、经验均通过裁剪容器缩短，填充纹理宽度固定，不做拉伸比例动画。

@onready var full_width: float = $Clip.size.x

func set_value(current: float, maximum: float, show_numbers: bool = true) -> void:
	var valid := is_finite(current) and is_finite(maximum) and maximum > 0
	var ratio: float = clampf(current / maximum, 0, 1) if valid else 0.0
	$Clip.size.x = floorf(full_width * ratio)
	$Clip.visible = ratio > 0
	$Value.text = "%d / %d" % [maxi(0, int(current)), maxi(0, int(maximum))] if valid and show_numbers else ""
