class_name SkillCard
extends TerminalButton

var definition: SkillDefinition
var upgrades: UpgradeSystem


func _ready() -> void:
	super._ready()
	text = ""
	disabled = not upgrades.locked_reason(definition).is_empty()


func _draw() -> void:
	if definition == null or upgrades == null: return
	var rank: int = upgrades.rank_of(definition.id)
	var color: Color = TerminalStyle.GREEN if not disabled else TerminalStyle.MUTED
	if rank > 0: color = TerminalStyle.INK
	TerminalStyle.text(self, Vector2(14, 25), definition.title, color, 13, true)
	var cost: String = "%d *" % definition.cost(rank) if rank < definition.max_rank else "MAX"
	TerminalStyle.text(self, Vector2(size.x - 47, 25), cost, TerminalStyle.GOLD if not disabled else TerminalStyle.FAINT, 11)
	TerminalStyle.wrapped(self, Vector2(14, 47), definition.description, size.x - 28, TerminalStyle.MUTED, 10, 15)
	var reason: String = upgrades.locked_reason(definition)
	TerminalStyle.text(self, Vector2(14, 90), "EVOLVE →" if reason.is_empty() else reason, TerminalStyle.GREEN if reason.is_empty() else TerminalStyle.FAINT, 9)
	TerminalStyle.text(self, Vector2(size.x - 55, 90), "%d / %d" % [rank, definition.max_rank], color, 9)
