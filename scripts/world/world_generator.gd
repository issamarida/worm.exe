class_name WorldGenerator
extends Node
## Pure seed/coordinate generation + bounded chunk cache + sparse persistent edits.

signal cell_changed(position: Vector2i)

const BIOME_PATHS: PackedStringArray = [
	"res://data/biomes/loam.tres", "res://data/biomes/clay.tres",
	"res://data/biomes/mycelium.tres", "res://data/biomes/shale.tres",
	"res://data/biomes/abyss.tres",
]

var balance: GameBalance
var biomes: Array[BiomeDefinition] = []
var seed_value: int = 731204
var modified: Dictionary[Vector2i, int] = {}
var explored: Dictionary[Vector2i, bool] = {}
var softened: Dictionary[Vector2i, float] = {}
var _chunks: Dictionary[Vector2i, Array] = {}
var _chunk_order: Array[Vector2i] = []
var _caves: FastNoiseLite = FastNoiseLite.new()
var _strata: FastNoiseLite = FastNoiseLite.new()


func configure(config: GameBalance, world_seed: int) -> void:
	balance = config
	seed_value = world_seed
	_chunks.clear()
	_chunk_order.clear()
	modified.clear()
	explored.clear()
	softened.clear()
	biomes.clear()
	for path: String in BIOME_PATHS:
		biomes.append(load(path) as BiomeDefinition)
	_caves.seed = seed_value
	_caves.frequency = 0.062
	_caves.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_strata.seed = seed_value + 17
	_strata.frequency = 0.09
	_strata.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


func biome_at(depth: int) -> BiomeDefinition:
	var result: BiomeDefinition = biomes[0]
	for biome: BiomeDefinition in biomes:
		if depth >= biome.minimum_depth:
			result = biome
	return result


func get_cell(position: Vector2i) -> SoilCell:
	var chunk: Vector2i = Vector2i(floori(float(position.x) / balance.chunk_size), floori(float(position.y) / balance.chunk_size))
	if not _chunks.has(chunk):
		_load_chunk(chunk)
	var local: Vector2i = position - chunk * balance.chunk_size
	var base: SoilCell = _chunks[chunk][local.y * balance.chunk_size + local.x] as SoilCell
	# Return a copy only for changed cells: callers cannot corrupt generated cached data.
	if not modified.has(position) and not softened.has(position):
		return base
	var cell: SoilCell = SoilCell.new()
	cell.glyph = base.glyph
	cell.color = base.color
	cell.density = base.density
	cell.friction = base.friction
	cell.dryness = base.dryness
	cell.cave = base.cave
	cell.stone = base.stone
	cell.item = base.item
	cell.sanctuary = base.sanctuary
	if softened.has(position):
		cell.density *= maxf(0.3, 1.0 - softened[position])
	if modified.has(position):
		cell.cave = true
		cell.stone = false
		cell.density = 0.12
		cell.glyph = "·"
		if modified[position] & 2:
			cell.item = SoilCell.Item.NONE
	return cell


func dig(position: Vector2i, softness: float = 0.0) -> void:
	modified[position] = modified.get(position, 0) | 1
	if softness > 0.0:
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = position + offset
			softened[neighbor] = minf(0.7, maxf(softened.get(neighbor, 0.0), softness))
	cell_changed.emit(position)


func collect(position: Vector2i) -> SoilCell.Item:
	var item: SoilCell.Item = get_cell(position).item
	if item != SoilCell.Item.NONE:
		modified[position] = modified.get(position, 0) | 2
		cell_changed.emit(position)
	return item


func reveal(center: Vector2i, radius: float) -> void:
	var extent: int = ceili(radius)
	for y: int in range(-extent, extent + 1):
		for x: int in range(-extent, extent + 1):
			if x * x + y * y <= radius * radius:
				explored[center + Vector2i(x, y)] = true


func is_home(position: Vector2i) -> bool:
	return position.distance_to(balance.starting_position) < 5.0


func cache_count() -> int:
	return _chunks.size()


func coordinate_hash(position: Vector2i, salt: int = 0) -> int:
	# 31-bit arithmetic remains deterministic at large and negative world coordinates.
	var value: int = (position.x * 374761393 + position.y * 668265263 + seed_value * 31 + salt * 1447) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return (value ^ (value >> 16)) & 0x7fffffff


func _load_chunk(chunk: Vector2i) -> void:
	var cells: Array[SoilCell] = []
	for y: int in range(balance.chunk_size):
		for x: int in range(balance.chunk_size):
			cells.append(_generate_cell(chunk * balance.chunk_size + Vector2i(x, y)))
	_chunks[chunk] = cells
	_chunk_order.append(chunk)
	while _chunk_order.size() > balance.cache_limit:
		_chunks.erase(_chunk_order.pop_front())


func _generate_cell(position: Vector2i) -> SoilCell:
	var biome: BiomeDefinition = biome_at(position.y)
	var cell: SoilCell = SoilCell.new()
	var hashed: int = coordinate_hash(position)
	var noise: float = _strata.get_noise_2d(position.x, position.y)
	cell.color = biome.soil_color.lerp(Color("afb59e"), maxf(0.0, noise) * 0.28)
	cell.glyph = biome.glyphs.substr(hashed % biome.glyphs.length(), 1)
	cell.density = biome.density * (0.8 + float(hashed % 40) * 0.01)
	cell.friction = biome.friction
	cell.dryness = biome.dryness
	cell.cave = _caves.get_noise_2d(position.x, position.y) > biome.cave_threshold
	cell.stone = hashed % 97 < 3 and not cell.cave
	if cell.cave:
		cell.glyph = " " if hashed % 4 != 0 else "·"
		cell.density = 0.12
	elif cell.stone:
		cell.glyph = "▓"
		cell.density *= 2.2
		cell.color = Color("757b73")
	# Distinct resource bands are driven by position, never by discovery order.
	var roll: int = coordinate_hash(position, 9) % 1000
	if roll < 17: cell.item = SoilCell.Item.FOOD
	elif roll < 34: cell.item = SoilCell.Item.DEW
	elif roll < 55: cell.item = SoilCell.Item.SPORE
	if position.y < 0:
		cell.glyph = "╵" if hashed % 5 == 0 else " "
		cell.color = Color("4a5d46")
		cell.item = SoilCell.Item.NONE
		cell.density = 10.0
	if position.y >= 0 and position.y < 4 and hashed % 7 < 2:
		cell.glyph = "│" if hashed % 3 else "╲"
		cell.color = Color("7a8060")
	cell.sanctuary = is_home(position)
	if cell.sanctuary:
		cell.cave = true
		cell.stone = false
		cell.density = 0.1
		cell.glyph = " " if hashed % 5 != 0 else "·"
		cell.item = SoilCell.Item.NONE
	# An authored opening nested inside the procedural world teaches all pickups.
	if position == Vector2i(5, 10) or position == Vector2i(-8, 15): cell.item = SoilCell.Item.FOOD
	if position == Vector2i(8, 13) or position == Vector2i(-4, 20): cell.item = SoilCell.Item.DEW
	if position == Vector2i(3, 16) or position == Vector2i(10, 19): cell.item = SoilCell.Item.SPORE
	if balance.relic_positions.has(position):
		cell.item = SoilCell.Item.RELIC
		cell.stone = false
	if position == balance.goal_position:
		cell.item = SoilCell.Item.HEART
		cell.stone = false
	return cell
