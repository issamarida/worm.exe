class_name WormController
extends Node
## Logical cells and render positions are separate. The tail follows historical cells.

signal stepped(position: Vector2i, soil: SoilCell, sprinting: bool)
signal step_started(position: Vector2i, soil: SoilCell, sprinting: bool)

var cells: Array[Vector2i] = []
var previous_cells: Array[Vector2i] = []
var facing: Vector2i = Vector2i.DOWN
var moving: bool = false
var progress: float = 1.0
var _duration: float = 0.12
var _destination_soil: SoilCell
var _sprinting: bool = false


func reset(position: Vector2i, length: int) -> void:
	cells.clear()
	for index: int in range(length):
		cells.append(position + Vector2i(-mini(index, 6), -maxi(0, index - 6)))
	previous_cells.assign(cells)
	facing = Vector2i.DOWN
	moving = false
	progress = 1.0


func tick(delta: float, direction: Vector2i, sprint: bool, world: WorldGenerator, stats: WormStats) -> void:
	if moving:
		progress = minf(1.0, progress + delta / _duration)
		if progress >= 1.0:
			moving = false
			stepped.emit(cells[0], _destination_soil, _sprinting)
	if not moving and direction != Vector2i.ZERO:
		_start_step(direction, sprint, world, stats)


func interpolated_body() -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var blend: float = smoothstep(0.0, 1.0, progress)
	for index: int in range(cells.size()):
		result.append(Vector2(previous_cells[index]).lerp(Vector2(cells[index]), blend))
	return result


func head_position() -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	return Vector2(previous_cells[0]).lerp(Vector2(cells[0]), smoothstep(0.0, 1.0, progress))


func restore(saved_cells: Array[Vector2i], direction: Vector2i) -> void:
	cells.assign(saved_cells)
	previous_cells.assign(cells)
	facing = direction
	moving = false
	progress = 1.0


func _start_step(direction: Vector2i, sprint: bool, world: WorldGenerator, stats: WormStats) -> void:
	var destination: Vector2i = cells[0] + direction
	if destination.y < 0:
		return
	_destination_soil = world.get_cell(destination)
	_sprinting = sprint
	var density: float = maxf(0.2, _destination_soil.density / stats.dig_efficiency)
	_duration = world.balance.step_seconds * (0.75 + sqrt(density) * 0.42)
	_duration /= stats.tunnel_speed
	if sprint:
		_duration *= 0.65
	previous_cells.assign(cells)
	for index: int in range(cells.size() - 1, 0, -1):
		cells[index] = cells[index - 1]
	cells[0] = destination
	facing = direction
	world.dig(destination, stats.soil_softening)
	progress = 0.0
	moving = true
	step_started.emit(destination, _destination_soil, sprint)
