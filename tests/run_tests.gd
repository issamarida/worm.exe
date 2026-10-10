extends SceneTree
## Dependency-free integration suite; fails with a nonzero process exit code.

var _checks: int = 0
var _failures: int = 0
var _session: GameSession


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBindings.install()
	_session = (load("res://scenes/game/session.tscn") as PackedScene).instantiate() as GameSession
	root.add_child(_session)
	await process_frame
	_test_generation()
	_test_movement()
	_test_survival()
	_test_upgrades()
	_test_save_round_trip()
	_test_full_journey()
	_session.queue_free()
	await process_frame
	print("WORM TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)


func _test_generation() -> void:
	var config: GameBalance = _session.balance.duplicate() as GameBalance
	config.cache_limit = 5
	var a: WorldGenerator = WorldGenerator.new()
	var b: WorldGenerator = WorldGenerator.new()
	a.configure(config, 731204)
	b.configure(config, 731204)
	for position: Vector2i in [Vector2i(-25, 12), Vector2i(0, 93), Vector2i(25, 192), Vector2i(-9999, 8888)]:
		var first: SoilCell = a.get_cell(position)
		var second: SoilCell = b.get_cell(position)
		_check(first.glyph == second.glyph and first.item == second.item and is_equal_approx(first.density, second.density), "Seed/coordinate generation is deterministic at " + str(position))
	var sample: Vector2i = Vector2i(3, 16)
	_check(a.get_cell(sample).item == SoilCell.Item.SPORE, "Authored opening has a discoverable spore cluster")
	a.dig(sample, 0.36)
	_check(a.collect(sample) == SoilCell.Item.SPORE, "Pickup returns the correct item")
	for index: int in range(16): a.get_cell(Vector2i(index * 50, 550))
	_check(a.cache_count() <= config.cache_limit, "Chunk cache remains bounded")
	_check(a.get_cell(sample).cave and a.get_cell(sample).item == SoilCell.Item.NONE, "Edits and consumed items survive chunk eviction")
	var natural: SoilCell = b.get_cell(sample + Vector2i.DOWN)
	_check(a.get_cell(sample + Vector2i.DOWN).density <= natural.density * 0.65, "Earth-shaping modifies adjacent soil independently of chunk cache")
	_check(a.get_cell(Vector2i(-1, 0)) != null, "Negative coordinates use floor division across chunk boundaries")
	_check(a.biome_at(0).id == &"loam" and a.biome_at(90).id == &"mycelium" and a.biome_at(500000).id == &"abyss", "Biome progression supports indefinitely deeper coordinates")
	a.free()
	b.free()
	print("PASS generation and streaming")


func _test_movement() -> void:
	_session.new_journey(731204)
	var original: Array[Vector2i] = _session.worm.cells.duplicate()
	_session.worm.tick(0.0, Vector2i.RIGHT, false, _session.world, _session.upgrades.stats)
	_check(_session.worm.cells[0] == original[0] + Vector2i.RIGHT, "Grid head advances exactly one cell")
	_check(_session.worm.cells[1] == original[0] and _session.worm.cells[2] == original[1], "Body segments follow the historical path")
	_check(_session.worm.head_position().is_equal_approx(Vector2(original[0])), "Render position begins at the previous cell")
	var charged_energy: float = _session.survival.energy
	_check(charged_energy < _session.upgrades.stats.max_energy, "Movement cost is charged before a mid-step save can occur")
	_session.worm.tick(0.05, Vector2i.ZERO, false, _session.world, _session.upgrades.stats)
	_check(_session.worm.head_position().x > original[0].x and _session.worm.head_position().x < original[0].x + 1, "Head interpolates continuously between cells")
	_session.worm.tick(1.0, Vector2i.ZERO, false, _session.world, _session.upgrades.stats)
	_check(_session.distance_dug == 1, "A completed movement emits exactly one gameplay step")
	_check(is_equal_approx(_session.survival.energy, charged_energy), "Completion does not charge movement twice")
	for direction: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]:
		_step(direction)
	for index: int in range(1, _session.worm.cells.size()):
		var delta: Vector2i = _session.worm.cells[index] - _session.worm.cells[index - 1]
		_check(absi(delta.x) + absi(delta.y) <= 1, "Tail stays connected while cornering and crossing itself")
	_session.worm.reset(Vector2i(0, 0), _session.balance.body_length)
	_session.worm.tick(0.0, Vector2i.UP, false, _session.world, _session.upgrades.stats)
	_check(_session.worm.cells[0].y == 0 and not _session.worm.moving, "Surface boundary blocks upward motion")
	print("PASS segmented movement and interpolation")


func _test_survival() -> void:
	_session.new_journey(731204)
	var survival: SurvivalSystem = SurvivalSystem.new()
	var stats: WormStats = WormStats.new()
	survival.configure(_session.balance, stats)
	var light_soil: SoilCell = SoilCell.new()
	light_soil.density = 0.5
	survival.consume_step(light_soil, 10, false)
	var normal_cost: float = 100.0 - survival.energy
	survival.refill()
	light_soil.density = 2.0
	light_soil.friction = 1.5
	survival.consume_step(light_soil, 200, true)
	_check(100.0 - survival.energy > normal_cost * 4, "Depth, density, friction and hurry increase movement cost")
	var dry_cost: float = 100.0 - survival.moisture
	survival.refill()
	stats = WormStats.new()
	stats.moisture_efficiency = 2.0
	stats.pressure_resistance = 0.5
	survival.set_stats(stats)
	survival.consume_step(light_soil, 200, true)
	_check(100.0 - survival.moisture < dry_cost, "Resilient Core mitigates pressure and moisture loss")
	survival.energy = 25.0
	survival.moisture = 25.0
	survival.tick(2.0, 8, light_soil, true)
	_check(survival.energy > 25.0 and survival.moisture > 25.0, "Sanctuary resting refills both survival meters")
	_session.upgrades.spores = 10
	_session.survival.energy = 0.01
	_step(Vector2i.RIGHT)
	_check(_session.world.is_home(_session.worm.cells[0]), "Depletion rescues the worm to its sanctuary")
	_check(_session.upgrades.spores == 7, "Collapse returns 30 percent of unspent spores to the earth")
	_check(_session.survival.energy == 100.0, "Recovery restores survival resources")
	survival.free()
	print("PASS survival, pressure and recovery")


func _test_upgrades() -> void:
	_session.new_journey(731204)
	var upgrades: UpgradeSystem = _session.upgrades
	_check(upgrades.catalog.size() == 12 and upgrades.validate_catalog().is_empty(), "Twelve skill resources form a valid prerequisite graph")
	upgrades.spores = 1000
	_check(not upgrades.purchase(&"aurora"), "Prerequisites prevent buying deep skills early")
	var before: int = upgrades.spores
	_check(upgrades.purchase(&"phosphor"), "Root skill can be purchased")
	_check(upgrades.spores == before - 3 and upgrades.stats.light_radius == 19.0, "Purchase consumes spores and rebuilds derived stats")
	upgrades.spores = 0
	_check(not upgrades.purchase(&"jaw") and upgrades.rank_of(&"jaw") == 0, "Insufficient funds leave ranks unchanged")
	upgrades.spores = 1000
	for skill: SkillDefinition in upgrades.catalog:
		while upgrades.rank_of(skill.id) < skill.max_rank:
			_check(upgrades.purchase(skill.id), "Each declared rank can be purchased: " + String(skill.id))
	var maxed_spores: int = upgrades.spores
	_check(not upgrades.purchase(&"phosphor") and upgrades.spores == maxed_spores, "Maxed skills cannot consume additional spores")
	_check(upgrades.stats.light_radius == 27.0 and upgrades.stats.max_energy == 140.0 and upgrades.stats.max_moisture == 125.0, "All three branches have observable combined effects")
	_check(is_equal_approx(upgrades.stats.soil_softening, 0.36), "Earth-Shaper soil modifiers accumulate by rank")
	print("PASS data-driven evolution tree")


func _test_save_round_trip() -> void:
	var path: String = "user://tests-round-trip.json"
	_step(Vector2i.DOWN)
	_session.world.reveal(_session.worm.cells[0], 20)
	_session.upgrades.spores = 14
	var previous: Dictionary = _session.snapshot()
	_check(_session.save_game(path), "Save writes a valid envelope")
	_session.upgrades.spores = 19
	_check(_session.save_game(path), "Second save atomically creates a last-good backup")
	var body_before: Vector2i = _session.worm.cells[0]
	_session.new_journey(444)
	_check(_session.load_game(path), "A new session can load a saved journey")
	_check(_session.world.seed_value == 731204 and _session.worm.cells[0] == body_before, "Save restores seed and complete body position")
	_check(_session.upgrades.spores == 19 and _session.upgrades.stats.light_radius == 27, "Save restores currency, ranks and derived effects")
	_check(_session.world.modified.size() == (previous["modified"] as Array).size(), "Sparse edits round-trip intact")
	var corrupt: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{broken save}")
	corrupt.close()
	var recovered: Dictionary = SaveStore.read_save(path)
	_check(int(recovered.get("spores", 0)) == 14, "A corrupt primary recovers the last-good backup")
	var invalid: Dictionary = _session.snapshot()
	invalid["cells"] = [["bad", null]]
	_check(not _session.restore(invalid), "Malformed body data is rejected without crashing")
	_check(SaveStore.read_save("user://a-nonexistent-burrow.json").is_empty(), "Missing saves safely return an empty state")
	print("PASS save integrity, round-trip and recovery")


func _test_full_journey() -> void:
	_session.new_journey(731204)
	_session.upgrades.spores = 200
	for skill: SkillDefinition in _session.upgrades.catalog:
		_session.upgrades.purchase(skill.id)
	_walk_to(_session.balance.goal_position)
	_check(not _session.has_heart, "Quiet heart remains asleep before three echoes are found")
	_session.new_journey(731204)
	_session.upgrades.spores = 1000
	for skill: SkillDefinition in _session.upgrades.catalog:
		while _session.upgrades.rank_of(skill.id) < skill.max_rank: _session.upgrades.purchase(skill.id)
	for position: Vector2i in _session.balance.relic_positions:
		_walk_to(position)
	_check(_session.relics.size() == 3, "An actual movement route can collect all three root echoes")
	_walk_to(_session.balance.goal_position)
	_check(_session.has_heart, "Collecting all echoes unlocks the quiet heart")
	_check(_session.recall(), "Return-home channel can begin from the deep")
	_session.active = true
	_session._physics_process(_session.balance.recall_seconds + 0.1)
	_check(_session.completed and not _session.active, "Returning the heart home reaches and pauses at the ending")
	_check(_session.world.is_home(_session.worm.cells[0]), "The ending returns the body to the root cradle")
	_session.active = false
	_step(Vector2i.DOWN)
	_check(_session.completed and _session.distance_dug > 0, "The completed world supports continued exploration")
	print("PASS complete root-song journey and ending")


func _step(direction: Vector2i) -> void:
	_session.worm.tick(0.0, direction, false, _session.world, _session.upgrades.stats)
	_session.worm.tick(1.0, Vector2i.ZERO, false, _session.world, _session.upgrades.stats)


func _walk_to(target: Vector2i) -> void:
	var safety: int = 0
	while _session.worm.cells[0] != target and safety < 4000:
		var delta: Vector2i = target - _session.worm.cells[0]
		_step(Vector2i(signi(delta.x), 0) if delta.x != 0 else Vector2i(0, signi(delta.y)))
		safety += 1
	_check(_session.worm.cells[0] == target, "Route reaches " + str(target))
