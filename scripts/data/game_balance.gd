class_name GameBalance
extends Resource
## All simulation tuning lives here rather than in rendering or interface code.

@export var seed_value: int = 731204
@export var chunk_size: int = 24
@export var cache_limit: int = 64
@export var starting_position: Vector2i = Vector2i(0, 8)
@export var body_length: int = 12
@export var step_seconds: float = 0.115
@export var idle_energy_decay: float = 0.055
@export var idle_moisture_decay: float = 0.095
@export var dig_energy_cost: float = 0.30
@export var dig_moisture_cost: float = 0.065
@export var pressure_per_cell: float = 0.003
@export var recall_seconds: float = 2.0
@export var pulse_cooldown: float = 8.0
@export var pulse_seconds: float = 5.0
@export var goal_position: Vector2i = Vector2i(0, 206)
@export var relic_positions: Array[Vector2i] = [Vector2i(-14, 44), Vector2i(20, 94), Vector2i(-18, 150)]
