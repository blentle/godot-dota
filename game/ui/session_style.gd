extends RefCounted
## 选人与结算共用材质色和文字组件，保持与战斗控制台一致。

const GOLD := Color("c6ab70")
const TEXT := Color("e1d7bb")
const MUTED := Color("aaa58e")

# 界面只读共享打包字体，避免每个控件重复扫描系统字体而阻塞网络主循环。
static var shared_font: Font

static func font() -> Font:
	if shared_font == null:
		shared_font = preload("res://ui/war3/assets/font.tres")
	return shared_font

static func box(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(2)
	return result

static func background(parent: Control) -> void:
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", box(Color("18221c"), GOLD.darkened(0.3)))
	parent.add_child(panel)

static func label(parent: Control, value: String, at: Vector2, size: int = 18, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = value
	result.position = at
	result.add_theme_font_override("font", font())
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result

static func button(parent: Control, value: String, rect: Rect2) -> Button:
	var result := Button.new()
	result.text = value
	result.position = rect.position
	result.size = rect.size
	result.add_theme_font_override("font", font())
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", TEXT)
	result.add_theme_color_override("font_disabled_color", MUTED)
	result.add_theme_stylebox_override("disabled", box(Color("202b23"), Color("595c46")))
	result.add_theme_stylebox_override("normal", box(Color("29372c"), Color("776947")))
	result.add_theme_stylebox_override("hover", box(Color("414d37"), GOLD))
	result.add_theme_stylebox_override("pressed", box(Color("394932"), GOLD))
	result.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), Color("dfcf99")))
	parent.add_child(result)
	return result
