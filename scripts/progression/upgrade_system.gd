class_name UpgradeSystem
extends Node

signal purchased(skill: SkillDefinition)
signal stats_changed(stats: WormStats)

const EFFECT_KEYS: PackedStringArray = [
	"light_radius", "scan_radius", "reveal_items", "dig_efficiency", "soil_softening",
	"moisture_gain", "tunnel_speed", "moisture_efficiency", "max_energy", "max_moisture",
	"pressure_resistance", "rest_rate", "pulse_efficiency",
]
const SKILL_PATHS: PackedStringArray = [
	"phosphor", "echo", "spectra", "aurora", "jaw", "clay", "channels", "silk",
	"breath", "vessel", "skin", "haven",
]

var catalog: Array[SkillDefinition] = []
var ranks: Dictionary[StringName, int] = {}
var spores: int = 0
var stats: WormStats = WormStats.new()


func configure() -> void:
	catalog.clear()
	ranks.clear()
	spores = 0
	for id: String in SKILL_PATHS:
		var skill: SkillDefinition = load("res://data/skills/%s.tres" % id) as SkillDefinition
		assert(skill != null, "Missing skill: " + id)
		catalog.append(skill)
	rebuild_stats()


func skill_by_id(id: StringName) -> SkillDefinition:
	for skill: SkillDefinition in catalog:
		if skill.id == id:
			return skill
	return null


func rank_of(id: StringName) -> int:
	return ranks.get(id, 0)


func locked_reason(skill: SkillDefinition) -> String:
	var rank: int = rank_of(skill.id)
	if rank >= skill.max_rank:
		return "Fully evolved"
	if skill.prerequisite != &"" and rank_of(skill.prerequisite) == 0:
		var parent: SkillDefinition = skill_by_id(skill.prerequisite)
		return "Requires " + (parent.title if parent != null else String(skill.prerequisite))
	if spores < skill.cost(rank):
		return "Need %d more spores" % (skill.cost(rank) - spores)
	return ""


func purchase(id: StringName) -> bool:
	var skill: SkillDefinition = skill_by_id(id)
	if skill == null or not locked_reason(skill).is_empty():
		return false
	var rank: int = rank_of(id)
	spores -= skill.cost(rank)
	ranks[id] = rank + 1
	rebuild_stats()
	purchased.emit(skill)
	return true


func rebuild_stats() -> void:
	stats = WormStats.new()
	for skill: SkillDefinition in catalog:
		for key: StringName in skill.effects:
			assert(EFFECT_KEYS.has(String(key)), "Unknown skill effect: " + String(key))
			stats.apply_effect(key, skill.effects[key] * rank_of(skill.id))
	stats_changed.emit(stats)


func validate_catalog() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Dictionary[StringName, bool] = {}
	for skill: SkillDefinition in catalog:
		if seen.has(skill.id): errors.append("Duplicate skill " + String(skill.id))
		seen[skill.id] = true
		if skill.base_cost <= 0 or skill.max_rank <= 0: errors.append("Invalid cost/rank " + String(skill.id))
		if skill.prerequisite != &"" and skill_by_id(skill.prerequisite) == null:
			errors.append("Missing prerequisite " + String(skill.id))
		var current: SkillDefinition = skill
		var chain: Dictionary[StringName, bool] = {}
		while current != null and current.prerequisite != &"":
			if chain.has(current.id):
				errors.append("Prerequisite cycle " + String(skill.id))
				break
			chain[current.id] = true
			current = skill_by_id(current.prerequisite)
	return errors
