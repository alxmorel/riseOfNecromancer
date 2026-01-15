extends Node
class_name ItemDropper

## Helper pour donner des items au joueur
## Peut être attaché à des coffres, ennemis, NPCs, etc.

signal item_dropped(item: Item, quantity: int)

@export var items_to_drop: Array[Item] = []
@export var quantities: Array[int] = []
@export var auto_drop_on_ready: bool = false

var player: CharacterBody2D = null

func _ready():
	if auto_drop_on_ready:
		await get_tree().create_timer(0.1).timeout  # Attendre que le joueur soit prêt
		drop_items()

func drop_items(custom_player: CharacterBody2D = null):
	"""Drop tous les items configurés au joueur"""
	var target = custom_player if custom_player else _find_player()
	
	if not target:
		push_warning("ItemDropper: Joueur non trouvé")
		return
	
	if not target.has_node("InventoryComponent"):
		push_warning("ItemDropper: Le joueur n'a pas d'InventoryComponent")
		return
	
	var inventory = target.get_node("InventoryComponent")
	
	for i in range(items_to_drop.size()):
		var item = items_to_drop[i]
		var quantity = quantities[i] if i < quantities.size() else 1
		
		if item and inventory.add_item(item, quantity):
			print("🎁 Item obtenu: ", item.name, " x", quantity)
			item_dropped.emit(item, quantity)
		else:
			print("⚠️ Impossible d'ajouter: ", item.name if item else "null")

func drop_single_item(item: Item, quantity: int = 1, custom_player: CharacterBody2D = null):
	"""Drop un seul item au joueur"""
	var target = custom_player if custom_player else _find_player()
	
	if not target or not target.has_node("InventoryComponent"):
		return false
	
	var inventory = target.get_node("InventoryComponent")
	
	if inventory.add_item(item, quantity):
		print("🎁 Item obtenu: ", item.name, " x", quantity)
		item_dropped.emit(item, quantity)
		return true
	
	return false

func _find_player() -> CharacterBody2D:
	"""Trouve le joueur dans la scène"""
	if player and is_instance_valid(player):
		return player
	
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player = players[0]
		return player
	
	return null
