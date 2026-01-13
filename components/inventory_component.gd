extends Node
class_name InventoryComponent

## Composant de gestion d'inventaire
## Gère les items par catégorie

signal item_added(item: Item, quantity: int)
signal item_removed(item: Item, quantity: int)
signal inventory_changed()

@export var max_slots: int = 50

# Structure: { "item_id": { "item": Item, "quantity": int } }
var items: Dictionary = {}

func add_item(item: Item, quantity: int = 1) -> bool:
	"""Ajoute un item à l'inventaire"""
	if not item:
		return false
	
	# Si l'item existe déjà et est stackable
	if items.has(item.id):
		if item.stackable:
			var current = items[item.id]
			var new_quantity = current["quantity"] + quantity
			
			# Vérifier le max stack
			if new_quantity <= item.max_stack:
				current["quantity"] = new_quantity
				item_added.emit(item, quantity)
				inventory_changed.emit()
				return true
			else:
				# Stack plein, ne pas ajouter
				return false
		else:
			# Item non stackable, ne pas ajouter si déjà présent
			return false
	else:
		# Vérifier s'il y a de la place
		if items.size() >= max_slots:
			return false
		
		# Nouvel item
		items[item.id] = {
			"item": item,
			"quantity": quantity
		}
		item_added.emit(item, quantity)
		inventory_changed.emit()
		return true

func remove_item(item_id: String, quantity: int = 1) -> bool:
	"""Retire un item de l'inventaire"""
	if not items.has(item_id):
		return false
	
	var current = items[item_id]
	var item = current["item"]
	
	if current["quantity"] > quantity:
		current["quantity"] -= quantity
		item_removed.emit(item, quantity)
		inventory_changed.emit()
		return true
	elif current["quantity"] == quantity:
		items.erase(item_id)
		item_removed.emit(item, quantity)
		inventory_changed.emit()
		return true
	else:
		# Pas assez d'items
		return false

func has_item(item_id: String, quantity: int = 1) -> bool:
	"""Vérifie si l'inventaire contient un item"""
	if not items.has(item_id):
		return false
	return items[item_id]["quantity"] >= quantity

func get_item_quantity(item_id: String) -> int:
	"""Retourne la quantité d'un item"""
	if items.has(item_id):
		return items[item_id]["quantity"]
	return 0

func get_items_by_category(category: Item.ItemType) -> Array:
	"""Retourne tous les items d'une catégorie"""
	var result = []
	for item_data in items.values():
		var item = item_data["item"]
		if item.item_type == category:
			result.append(item_data)
	return result

func get_all_items() -> Array:
	"""Retourne tous les items"""
	return items.values()

func clear() -> void:
	"""Vide l'inventaire"""
	items.clear()
	inventory_changed.emit()
