class_name GameSession
extends Node
## Composition root for simulation. Views subscribe to signals and read this state.

signal message_added(text: String, color: Color)
signal pickup_collected(item: SoilCell.Item, position: Vector2i)
signal biome_entered(biome: BiomeDefinition)
signal returned_home()
signal ending_reached()
signal save_completed(success: bool)

@export var balance: GameBalance
@onready var world: WorldGenerator = $World as WorldGenerator
@onready var worm: WormController = $Worm as WormController
@onready var survival: SurvivalSystem = $Survival as SurvivalSystem
@onready var upgrades: UpgradeSystem = $Upgrades as UpgradeSystem

var active: bool = false
var deepest: int = 8
var distance_dug: int = 0
var relics: Array[Vector2i] = []
var has_heart: bool = false
var completed: bool = false
var pulse_remaining: float = 0.0
var pulse_cooldown: float = 0.0
var recall_remaining: float = 0.0
var elapsed_seconds: float = 0.0
var journal: Array[Dictionary] = []
var _save_elapsed: float = 0.0
var _biome_id: StringName = &""
var _last_direction: Vector2i = Vector2i.ZERO


func _ready() -> void:
	worm.step_started.connect(_on_step_started)
	survival.depleted.connect(_on_depleted)
	upgrades.stats_changed.connect(survival.set_stats)
	upgrades.purchased.connect(_on_purchase)
	new_journey(balance.seed_value)


func new_journey(world_seed: int) -> void:
	active = false
	world.configure(balance, world_seed)
	upgrades.configure()
	survival.configure(balance, upgrades.stats)
	worm.reset(balance.starting_position, balance.body_length)
	for position: Vector2i in worm.cells: world.dig(position)
	world.reveal(worm.cells[0], upgrades.stats.light_radius)
	deepest = balance.starting_position.y
	distance_dug = 0
	relics.clear()
	has_heart = false
	completed = false
	pulse_remaining = 0.0
	pulse_cooldown = 0.0
	recall_remaining = 0.0
	elapsed_seconds = 0.0
	_save_elapsed = 0.0
	_biome_id = &""
	_last_direction = Vector2i.ZERO
	journal.clear()
	log_message("A small life. A whole world beneath.", Color("c0cba4"))
	log_message("Follow the root-song. Bring its three echoes home.", Color("92968b"))


func _physics_process(delta: float) -> void:
	if not active: return
	elapsed_seconds += delta
	_save_elapsed += delta
	pulse_remaining = maxf(0.0, pulse_remaining - delta)
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	var position: Vector2i = worm.cells[0]
	var biome: BiomeDefinition = world.biome_at(position.y)
	if biome.id != _biome_id:
		_biome_id = biome.id
		biome_entered.emit(biome)
		log_message(biome.subtitle, biome.accent_color)
	if recall_remaining > 0.0:
		recall_remaining -= delta
		if recall_remaining <= 0.0: _return_home(false)
		return
	survival.tick(delta, position.y, world.get_cell(position), world.is_home(position))
	# A depletion callback can teleport the worm; do not advance an obsolete step.
	if worm.cells[0] != position: return
	var direction: Vector2i = InputBindings.direction()
	if direction != Vector2i.ZERO: _last_direction = direction
	worm.tick(delta, _resolve_direction(direction), Input.is_action_pressed(&"sprint"), world, upgrades.stats)
	if _save_elapsed >= 20.0:
		_save_elapsed = 0.0
		save_game()


func _resolve_direction(requested: Vector2i) -> Vector2i:
	if requested == Vector2i.ZERO: return Vector2i.ZERO
	if _last_direction != Vector2i.ZERO:
		var action: StringName = &""
		match _last_direction:
			Vector2i.UP: action = &"move_up"
			Vector2i.DOWN: action = &"move_down"
			Vector2i.LEFT: action = &"move_left"
			Vector2i.RIGHT: action = &"move_right"
		if action != &"" and Input.is_action_pressed(action): return _last_direction
	return requested


func sense() -> bool:
	if pulse_cooldown > 0.0 or recall_remaining > 0.0: return false
	var cost: float = 3.0 / upgrades.stats.pulse_efficiency
	if survival.energy <= cost:
		log_message("Rest first. Even a whisper needs energy.", Color("c4a87c"))
		return false
	survival.energy -= cost
	pulse_remaining = balance.pulse_seconds
	pulse_cooldown = balance.pulse_cooldown
	world.reveal(worm.cells[0], upgrades.stats.scan_radius)
	log_message("A quiet pulse. The earth answers.", Color("9bbcb0"))
	return true


func recall() -> bool:
	if world.is_home(worm.cells[0]) or recall_remaining > 0.0: return false
	recall_remaining = balance.recall_seconds
	log_message("Following the roots home…", Color("b8c898"))
	return true


func next_destination() -> Vector2i:
	for position: Vector2i in balance.relic_positions:
		if not relics.has(position): return position
	if not has_heart: return balance.goal_position
	return balance.starting_position


func objective_title() -> String:
	if completed: return "THE EARTH IS STILL OPEN"
	if has_heart: return "BRING THE LIGHT HOME"
	if relics.size() == 3: return "FIND THE QUIET HEART"
	return "LISTEN FOR THE ROOT-SONG"


func log_message(text: String, color: Color = Color("939c8c")) -> void:
	journal.append({"text": text, "color": color.to_html(false)})
	while journal.size() > 24: journal.pop_front()
	message_added.emit(text, color)


func save_game(path: String = SaveStore.DEFAULT_PATH) -> bool:
	var error: Error = SaveStore.write_save(snapshot(), path)
	save_completed.emit(error == OK)
	if error != OK: push_warning("Could not save burrow: " + error_string(error))
	return error == OK


func snapshot() -> Dictionary:
	var cells: Array = []
	var edits: Array = []
	var seen: Array = []
	var soft: Array = []
	var echoes: Array = []
	var saved_ranks: Dictionary = {}
	for cell: Vector2i in worm.cells: cells.append([cell.x, cell.y])
	for cell: Vector2i in world.modified: edits.append([cell.x, cell.y, world.modified[cell]])
	for cell: Vector2i in world.explored: seen.append([cell.x, cell.y])
	for cell: Vector2i in world.softened: soft.append([cell.x, cell.y, world.softened[cell]])
	for cell: Vector2i in relics: echoes.append([cell.x, cell.y])
	for id: StringName in upgrades.ranks: saved_ranks[String(id)] = upgrades.ranks[id]
	return {
		"seed": world.seed_value, "cells": cells, "facing": [worm.facing.x, worm.facing.y],
		"energy": survival.energy, "moisture": survival.moisture, "spores": upgrades.spores,
		"ranks": saved_ranks, "modified": edits, "explored": seen, "softened": soft,
		"relics": echoes, "heart": has_heart, "completed": completed, "deepest": deepest,
		"distance": distance_dug, "elapsed": elapsed_seconds, "journal": journal,
	}


func load_game(path: String = SaveStore.DEFAULT_PATH) -> bool:
	var data: Dictionary = SaveStore.read_save(path)
	if data.is_empty(): return false
	return restore(data)


func restore(data: Dictionary) -> bool:
	var raw_cells: Variant = data.get("cells", null)
	if not raw_cells is Array or (raw_cells as Array).size() != balance.body_length: return false
	var body: Array[Vector2i] = []
	for value: Variant in raw_cells:
		if not _valid_coordinate(value): return false
		var cell: Vector2i = _coordinate(value)
		if cell.y < 0: return false
		if not body.is_empty() and absi(cell.x - body[-1].x) + absi(cell.y - body[-1].y) > 1: return false
		body.append(cell)
	var seed_data: Variant = data.get("seed", balance.seed_value)
	if not seed_data is float and not seed_data is int: return false
	new_journey(_integer(seed_data, 0, 0x7fffffff))
	var raw_ranks: Variant = data.get("ranks", {})
	if raw_ranks is Dictionary:
		for skill: SkillDefinition in upgrades.catalog:
			var rank: int = _integer((raw_ranks as Dictionary).get(String(skill.id), 0), 0, skill.max_rank)
			if skill.prerequisite == &"" or upgrades.rank_of(skill.prerequisite) > 0:
				upgrades.ranks[skill.id] = rank
	upgrades.rebuild_stats()
	upgrades.spores = _integer(data.get("spores", 0), 0, 1000000)
	survival.energy = _number(data.get("energy", 100.0), 1.0, survival.stats.max_energy)
	survival.moisture = _number(data.get("moisture", 100.0), 1.0, survival.stats.max_moisture)
	_restore_world_arrays(data)
	var facing: Vector2i = Vector2i.DOWN
	if _valid_coordinate(data.get("facing", null)):
		var saved_facing: Vector2i = _coordinate(data["facing"])
		if absi(saved_facing.x) + absi(saved_facing.y) == 1: facing = saved_facing
	worm.restore(body, facing)
	var raw_relics: Variant = data.get("relics", [])
	if raw_relics is Array:
		for value: Variant in raw_relics:
			if _valid_coordinate(value):
				var relic: Vector2i = _coordinate(value)
				if balance.relic_positions.has(relic) and not relics.has(relic): relics.append(relic)
	has_heart = bool(data.get("heart", false)) and relics.size() == 3
	completed = bool(data.get("completed", false)) and has_heart
	deepest = maxi(body[0].y, _integer(data.get("deepest", body[0].y), 0, 1000000))
	distance_dug = _integer(data.get("distance", 0), 0, 100000000)
	elapsed_seconds = _number(data.get("elapsed", 0.0), 0.0, 100000000.0)
	var raw_journal: Variant = data.get("journal", [])
	if raw_journal is Array:
		journal.clear()
		for value: Variant in (raw_journal as Array).slice(-23):
			if not value is Dictionary: continue
			var entry: Dictionary = value as Dictionary
			if not entry.get("text", null) is String or not entry.get("color", null) is String: continue
			var color: String = String(entry["color"])
			journal.append({"text": String(entry["text"]).left(240), "color": color if Color.html_is_valid(color) else "939c8c"})
	world.reveal(worm.cells[0], upgrades.stats.light_radius)
	log_message("Your burrow remembers you.", Color("b8c898"))
	return true


func _restore_world_arrays(data: Dictionary) -> void:
	for field: String in ["modified", "explored", "softened"]:
		var values: Variant = data.get(field, [])
		if not values is Array: continue
		for entry: Variant in (values as Array).slice(0, 1000000):
			if not _valid_coordinate(entry): continue
			var cell: Vector2i = _coordinate(entry)
			var row: Array = entry as Array
			if field == "explored": world.explored[cell] = true
			elif row.size() >= 3 and field == "modified": world.modified[cell] = _integer(row[2], 0, 3)
			elif row.size() >= 3 and field == "softened": world.softened[cell] = _number(row[2], 0.0, 0.7)


static func _valid_coordinate(value: Variant) -> bool:
	if not value is Array: return false
	var row: Array = value as Array
	if row.size() < 2: return false
	for index: int in range(2):
		if not row[index] is float and not row[index] is int: return false
		if not is_finite(float(row[index])) or absf(float(row[index])) > 1000000.0: return false
	return true


static func _coordinate(value: Variant) -> Vector2i:
	var row: Array = value as Array
	return Vector2i(int(row[0]), int(row[1]))


static func _integer(value: Variant, minimum: int, maximum: int) -> int:
	return int(_number(value, float(minimum), float(maximum)))


static func _number(value: Variant, minimum: float, maximum: float) -> float:
	if not value is float and not value is int: return minimum
	var number: float = float(value)
	return clampf(number, minimum, maximum) if is_finite(number) else minimum


func _on_step_started(position: Vector2i, soil: SoilCell, sprinting: bool) -> void:
	# The grid step is one transaction; visual interpolation can safely resume later.
	survival.consume_step(soil, position.y, sprinting)
	if worm.cells[0] == position:
		_resolve_step(position)


func _resolve_step(position: Vector2i) -> void:
	distance_dug += 1
	deepest = maxi(deepest, position.y)
	if worm.cells[0] != position: return
	world.reveal(position, upgrades.stats.light_radius)
	var item: SoilCell.Item = world.get_cell(position).item
	if item == SoilCell.Item.HEART and relics.size() < 3:
		log_message("Three root echoes will wake this sleeping heart.", Color("cfb0cb"))
		return
	item = world.collect(position)
	if item != SoilCell.Item.NONE:
		survival.restore_pickup(item)
		match item:
			SoilCell.Item.FOOD: log_message("A little nourishment. +18 energy", Color("cebc89"))
			SoilCell.Item.DEW: log_message("A memory of rain. +%d moisture" % int(22.0 * upgrades.stats.moisture_gain), Color("8bb7c6"))
			SoilCell.Item.SPORE:
				upgrades.spores += 2
				log_message("Something to grow from. +2 spores", Color("b8c898"))
			SoilCell.Item.RELIC:
				relics.append(position)
				upgrades.spores += 9
				log_message("ROOT ECHO %d/3 — a forgotten warmth. +9 spores" % relics.size(), Color("d3b78e"))
			SoilCell.Item.HEART:
				has_heart = true
				log_message("You found the quiet heart. Bring its light home.", Color("cfb0cb"))
		pickup_collected.emit(item, position)
		save_game()
	if has_heart and not completed and world.is_home(position): _complete_journey()


func _on_depleted(reason: String) -> void:
	log_message(reason, Color("c4a87c"))
	_return_home(true)


func _return_home(collapsed: bool) -> void:
	worm.reset(balance.starting_position, balance.body_length)
	for position: Vector2i in worm.cells: world.dig(position)
	survival.refill()
	if collapsed:
		var lost: int = ceili(upgrades.spores * 0.3)
		upgrades.spores -= lost
		log_message("The roots cradle you. %d spores returned to the soil." % lost, Color("c4a87c"))
	else:
		log_message("Home again. Nothing has been lost.", Color("b8c898"))
	recall_remaining = 0.0
	world.reveal(worm.cells[0], upgrades.stats.light_radius)
	returned_home.emit()
	if has_heart and not completed: _complete_journey()
	save_game()


func _complete_journey() -> void:
	completed = true
	active = false
	log_message("And in the quiet, something begins to bloom.", Color("d3b78e"))
	save_game()
	ending_reached.emit()


func _on_purchase(skill: SkillDefinition) -> void:
	world.reveal(worm.cells[0], upgrades.stats.light_radius)
	log_message("You grew: " + skill.title.to_lower() + ".", Color("b8c898"))
	save_game()
