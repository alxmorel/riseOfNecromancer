extends Resource
class_name Item

## Classe de base pour tous les items de l'inventaire

enum ItemType {
	POTION,
	OBJECT,
	SORTILEGE,
	RARE_OBJECT
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var item_type: ItemType = ItemType.OBJECT
@export var stackable: bool = true
@export var max_stack: int = 99
@export var value: int = 0

func get_category_name() -> String:
	"""Retourne le nom de la catégorie"""
	match item_type:
		ItemType.POTION:
			return "Potions"
		ItemType.OBJECT:
			return "Objets"
		ItemType.SORTILEGE:
			return "Sortilège"
		ItemType.RARE_OBJECT:
			return "Objets Rares"
	return "Inconnu"

func duplicate_item() -> Item:
	"""Duplique l'item"""
	var new_item = Item.new()
	new_item.id = id
	new_item.name = name
	new_item.description = description
	new_item.icon = icon
	new_item.item_type = item_type
	new_item.stackable = stackable
	new_item.max_stack = max_stack
	new_item.value = value
	return new_item
