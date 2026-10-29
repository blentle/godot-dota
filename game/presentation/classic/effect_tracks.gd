extends RefCounted
## 几何特效在固定子步内读取动作/全局时间轨，不改写模型和权威状态。

const Tracks = preload("res://presentation/classic/animation_tracks.gd")

static func sample(model: Node3D, track: Variant, fallback: Variant, clock: float, global_time: float, quaternion := false) -> Variant:
	if not track is Dictionary: return fallback if track == null else track
	var clip: Dictionary = model.data.Sequences[model.sequence]
	var interval := Vector2(clip.Interval[0], clip.Interval[1])
	var length := maxf(1, interval.y-interval.x)
	var frame := interval.x + (minf(clock, length) if clip.NonLooping else fposmod(clock, length))
	if track.get("GlobalSeqId") != null:
		var duration := float(model.data.GlobalSequences[int(track.GlobalSeqId)])
		interval = Vector2(0, duration)
		frame = fposmod(global_time, duration) if duration > 0 else 0
	return Tracks.sample(track, frame, fallback, interval, quaternion)
