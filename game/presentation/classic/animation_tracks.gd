extends RefCounted
## MDX 时间轨采样：区分全局序列、动作区间、步进、线性、Hermite 和 Bezier。

static func sample(track: Variant, time: float, fallback: Variant, interval: Vector2, quaternion := false) -> Variant:
	if not track is Dictionary: return fallback if track == null else track
	var keys: Array = track.get("Keys", [])
	var candidates: Array = []
	for key in keys:
		if key.Frame >= interval.x and key.Frame <= interval.y: candidates.append(key)
	if candidates.is_empty(): return fallback
	if candidates.size() == 1 or time <= candidates[0].Frame: return _value(candidates[0].Vector, quaternion)
	if time >= candidates[-1].Frame: return _value(candidates[-1].Vector, quaternion)
	var left: Dictionary = candidates[0]
	var right: Dictionary = candidates[-1]
	for index in range(candidates.size() - 1):
		if time >= candidates[index].Frame and time < candidates[index + 1].Frame:
			left = candidates[index]
			right = candidates[index + 1]
			break
	var mode := int(track.get("LineType", 0))
	var a: Variant = _value(left.Vector, quaternion)
	var b: Variant = _value(right.Vector, quaternion)
	if mode == 0: return a
	var t := clampf((time - left.Frame) / float(right.Frame - left.Frame), 0, 1)
	if quaternion:
		if mode == 1: return a.slerp(b, t)
		var out_tan: Quaternion = _value(left.OutTan, true)
		var in_tan: Quaternion = _value(right.InTan, true)
		return a.slerp(b, t).slerp(out_tan.slerp(in_tan, t), 2 * t * (1 - t)).normalized()
	if mode == 1: return lerp(a, b, t)
	var outgoing: Variant = _value(left.OutTan, false)
	var incoming: Variant = _value(right.InTan, false)
	if mode == 2:
		return a * (2*t*t*t - 3*t*t + 1) + outgoing * (t*t*t - 2*t*t + t) + b * (-2*t*t*t + 3*t*t) + incoming * (t*t*t - t*t)
	return a * pow(1-t, 3) + outgoing * (3*t*pow(1-t, 2)) + incoming * (3*t*t*(1-t)) + b * pow(t, 3)

static func _value(values: Array, quaternion: bool) -> Variant:
	if quaternion:
		var q := Quaternion(values[0], values[1], values[2], values[3])
		return q.normalized() if q.length_squared() > 0.00001 else Quaternion.IDENTITY
	if values.size() == 1: return float(values[0])
	return Vector3(values[0], values[1], values[2])
