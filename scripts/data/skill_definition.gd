class_name SkillDefinition
extends Resource
## Inspector-editable skill data. Effect keys are validated by UpgradeSystem.

enum Branch { PRISM, EARTH, CORE }

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var branch: Branch = Branch.PRISM
@export var tier: int = 0
@export var max_rank: int = 1
@export var base_cost: int = 3
@export var cost_per_rank: int = 2
@export var prerequisite: StringName = &""
@export var effects: Dictionary[StringName, float] = {}


func cost(rank: int) -> int:
	return base_cost + cost_per_rank * rank
