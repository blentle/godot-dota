extends RefCounted
## 可复用粒子状态：只负责运动和生命周期，坐标按发射器标志区分世界/模型空间。

var emitter := 0
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var gravity := 0.0
var age := 0.0
var life := 1.0
var size_scale := 1.0
var local_space := false
var facing := 0.0

func step(delta: float) -> bool:
	age += delta
	if age + 0.000001 >= life: return false
	velocity += (Vector3(0, 0, -1) if local_space else Vector3.DOWN) * gravity * delta
	position += velocity * delta
	return true

func segment(source: Dictionary) -> Vector2:
	var middle := clampf(float(source.Time), 0, 1)
	var fraction := clampf(age / maxf(life, 0.0001), 0, 1)
	if fraction < middle:
		return Vector2(0, fraction / maxf(middle, 0.0001))
	return Vector2(1, (fraction-middle) / maxf(1-middle, 0.0001))

func color(source: Dictionary) -> Color:
	var part := segment(source)
	var index := int(part.x)
	var a: Array = source.SegmentColor[index]
	var b: Array = source.SegmentColor[index+1]
	return Color(a[0], a[1], a[2], source.Alpha[index]/255.0).lerp(
		Color(b[0], b[1], b[2], source.Alpha[index+1]/255.0), part.y)

func radius(source: Dictionary) -> float:
	var part := segment(source)
	return lerpf(source.ParticleScaling[int(part.x)], source.ParticleScaling[int(part.x)+1], part.y) * size_scale

func cell(source: Dictionary, tail: bool) -> int:
	var part := segment(source)
	var name: String = ["LifeSpanUVAnim", "DecayUVAnim", "TailUVAnim", "TailDecayUVAnim"][int(part.x) + (2 if tail else 0)]
	var interval: Array = source[name]
	var span := maxi(0, int(interval[1])-int(interval[0]))
	var cell_index := int(interval[0])
	if span > 0:
		cell_index += int(floor(span * float(interval[2]) * part.y)) % span
	return clampi(cell_index, 0, maxi(1, int(source.Rows)*int(source.Columns))-1)
