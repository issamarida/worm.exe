class_name SoilCell
extends RefCounted
## A lightweight, generated value. Changes are stored separately by WorldGenerator.

enum Item { NONE, FOOD, DEW, SPORE, RELIC, HEART }

var glyph: String = "."
var color: Color = Color("665e4d")
var density: float = 1.0
var friction: float = 1.0
var dryness: float = 1.0
var cave: bool = false
var stone: bool = false
var item: Item = Item.NONE
var sanctuary: bool = false


func item_glyph() -> String:
	match item:
		Item.FOOD: return "%"
		Item.DEW: return "~"
		Item.SPORE: return "*"
		Item.RELIC: return "&"
		Item.HEART: return "Ω"
	return ""


func item_color() -> Color:
	match item:
		Item.FOOD: return Color("cebc89")
		Item.DEW: return Color("8bb7c6")
		Item.SPORE: return Color("adbc90")
		Item.RELIC: return Color("d3b78e")
		Item.HEART: return Color("cfb0cb")
	return Color.WHITE
