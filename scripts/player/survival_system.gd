class_name SurvivalSystem
extends Node

signal depleted(reason: String)

var energy: float = 100.0
var moisture: float = 100.0
var stats: WormStats = WormStats.new()
var balance: GameBalance
var _depletion_sent: bool = false


func configure(config: GameBalance, attributes: WormStats) -> void:
	balance = config
	stats = attributes
	refill()


func refill() -> void:
	energy = stats.max_energy
	moisture = stats.max_moisture
	_depletion_sent = false


func set_stats(attributes: WormStats) -> void:
	var energy_gain: float = attributes.max_energy - stats.max_energy
	var moisture_gain: float = attributes.max_moisture - stats.max_moisture
	stats = attributes
	energy = clampf(energy + energy_gain, 0.0, stats.max_energy)
	moisture = clampf(moisture + moisture_gain, 0.0, stats.max_moisture)


func tick(delta: float, depth: int, soil: SoilCell, at_home: bool) -> void:
	if at_home:
		energy = minf(stats.max_energy, energy + delta * 6.0 * stats.rest_rate)
		moisture = minf(stats.max_moisture, moisture + delta * 8.0 * stats.rest_rate)
		return
	var pressure: float = pressure_at(depth)
	energy = maxf(0.0, energy - delta * balance.idle_energy_decay * (1.0 + pressure))
	moisture = maxf(0.0, moisture - delta * balance.idle_moisture_decay * soil.dryness * (1.0 + pressure) / stats.moisture_efficiency)
	_check_depleted()


func consume_step(soil: SoilCell, depth: int, sprint: bool) -> void:
	var friction: float = soil.friction * (1.5 if sprint else 1.0)
	var pressure: float = 1.0 + pressure_at(depth)
	energy = maxf(0.0, energy - balance.dig_energy_cost * soil.density * friction * pressure / stats.dig_efficiency)
	moisture = maxf(0.0, moisture - balance.dig_moisture_cost * soil.dryness * friction * pressure / stats.moisture_efficiency)
	_check_depleted()


func pressure_at(depth: int) -> float:
	return maxf(0.0, depth * balance.pressure_per_cell) * (1.0 - minf(0.85, stats.pressure_resistance))


func restore_pickup(item: SoilCell.Item) -> void:
	match item:
		SoilCell.Item.FOOD: energy = minf(stats.max_energy, energy + 18.0)
		SoilCell.Item.DEW: moisture = minf(stats.max_moisture, moisture + 22.0 * stats.moisture_gain)
		SoilCell.Item.RELIC, SoilCell.Item.HEART:
			energy = minf(stats.max_energy, energy + 35.0)
			moisture = minf(stats.max_moisture, moisture + 35.0)


func _check_depleted() -> void:
	if _depletion_sent:
		return
	if energy <= 0.0 or moisture <= 0.0:
		_depletion_sent = true
		depleted.emit("Your little body needs rest." if energy <= 0.0 else "The dry earth asks too much.")
