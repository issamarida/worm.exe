class_name WormStats
extends Resource
## A fresh instance is rebuilt from purchased ranks. Never mutate catalog resources.

@export var light_radius: float = 17.0
@export var scan_radius: float = 23.0
@export var reveal_items: float = 0.0
@export var dig_efficiency: float = 1.0
@export var soil_softening: float = 0.0
@export var moisture_gain: float = 1.0
@export var tunnel_speed: float = 1.0
@export var moisture_efficiency: float = 1.0
@export var max_energy: float = 100.0
@export var max_moisture: float = 100.0
@export var pressure_resistance: float = 0.0
@export var rest_rate: float = 1.0
@export var pulse_efficiency: float = 1.0


func apply_effect(key: StringName, amount: float) -> void:
	match key:
		&"light_radius": light_radius += amount
		&"scan_radius": scan_radius += amount
		&"reveal_items": reveal_items += amount
		&"dig_efficiency": dig_efficiency += amount
		&"soil_softening": soil_softening += amount
		&"moisture_gain": moisture_gain += amount
		&"tunnel_speed": tunnel_speed += amount
		&"moisture_efficiency": moisture_efficiency += amount
		&"max_energy": max_energy += amount
		&"max_moisture": max_moisture += amount
		&"pressure_resistance": pressure_resistance += amount
		&"rest_rate": rest_rate += amount
		&"pulse_efficiency": pulse_efficiency += amount
