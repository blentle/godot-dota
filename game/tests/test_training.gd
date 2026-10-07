extends SceneTree

const Simulation = preload("res://simulation/training_world.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var world = Simulation.new()
	world.position = Vector3.ZERO
	world.block(Vector3(2, 0, 0), 0)
	check(not world.submit_move(Vector3(2, 0, 0)), "blocked destination must be rejected")
	check(world.submit_move(Vector3(4, 0, 0)), "path must route around obstacle")
	for point in world.path:
		check(point != Vector3(2, 0, 0), "path cannot cross blocked cell")
	for tick in range(90): world.step(1.0 / 30)
	check(world.position.distance_to(Vector3(4, 0, 0)) < 0.001, "movement must reach destination")
	check(world.submit_move(Vector3(12, 0, 0)), "second move accepted")
	world.step(0.1)
	world.submit_stop(true)
	var held: Vector3 = world.position
	world.step(1)
	check(world.position == held and world.order == "保持位置", "hold must cancel movement")
	world.submit_move(Vector3(500, 0, 500))
	check(world.path[-1] == Vector3(48, 0, 48), "map boundary must clamp commands")
	var small_steps = Simulation.new()
	var large_steps = Simulation.new()
	small_steps.submit_move(Vector3(-32, 0, 10))
	large_steps.submit_move(Vector3(-32, 0, 10))
	for tick in range(30): small_steps.step(1.0 / 30)
	large_steps.step(1)
	check(small_steps.position.distance_to(large_steps.position) < 0.001, "movement must not depend on step subdivision")
	if failures == 0: print("TRAINING TESTS PASS: obstacles, routing, arrival, hold, bounds, timestep")
	quit(1 if failures else 0)
