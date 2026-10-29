extends RefCounted
## 表现连续性：首次绑定不算传送；生命代次变化和大幅位置跳变切断旧特效。

const SNAP_DISTANCE := 12.0
var initialized := false
var previous_position := Vector3.ZERO
var previous_life := 0

func observe(position: Vector3, life_id: int) -> bool:
	var discontinuous := initialized and (life_id != previous_life or position.distance_to(previous_position) > SNAP_DISTANCE)
	previous_position = position
	previous_life = life_id
	initialized = true
	return discontinuous
