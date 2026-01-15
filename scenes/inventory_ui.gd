extends CanvasLayer
class_name InventoryUI

## Interface d'inventaire avec catégories et pause du jeu

signal closed()

@onready var panel: Panel = $Panel
@onready var category_label: Label = $Panel/VBoxContainer/Header/CategoryLabel
@onready var close_button: Button  = $Panel/CloseButton
@onready var items_grid: GridContainer = $Panel/VBoxContainer/ScrollContainer/ItemsGrid
@onready var category_buttons: VBoxContainer = $Panel/Categories

var inventory: InventoryComponent
var current_category: Item.ItemType = Item.ItemType.POTION

func _ready():
	hide()
	process_mode = PROCESS_MODE_ALWAYS  # Fonctionne même en pause
	
	# Connecter le bouton de fermeture
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Connecter les boutons de catégorie
	if category_buttons:
		var buttons = category_buttons.get_children()
		for i in range(buttons.size()):
			if buttons[i] is Button:
				buttons[i].pressed.connect(_on_category_selected.bind(i))

func setup(inventory_component: InventoryComponent):
	"""Configure l'UI avec un composant d'inventaire"""
	inventory = inventory_component
	if inventory:
		inventory.inventory_changed.connect(_refresh_display)

func open_inventory():
	"""Ouvre l'inventaire et met le jeu en pause"""
	show()
	get_tree().paused = true
	_refresh_display()
	print("📦 Inventaire ouvert")

func close_inventory():
	"""Ferme l'inventaire et reprend le jeu"""
	hide()
	get_tree().paused = false
	closed.emit()
	print("📦 Inventaire fermé")

func _on_close_pressed():
	close_inventory()

func _on_category_selected(category_index: int):
	"""Change la catégorie affichée"""
	current_category = category_index as Item.ItemType
	_refresh_display()

func _refresh_display():
	"""Rafraîchit l'affichage des items"""
	if not inventory or not items_grid:
		return
	
	# Nettoyer la grille
	for child in items_grid.get_children():
		child.queue_free()
	
	# Mettre à jour le label de catégorie
	if category_label:
		var category_name = _get_category_name(current_category)
		category_label.text = category_name
	
	# Afficher les items de la catégorie
	var items_in_category = inventory.get_items_by_category(current_category)
	
	if items_in_category.is_empty():
		# Message si vide
		var empty_label = Label.new()
		empty_label.text = "Aucun item dans cette catégorie"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_grid.add_child(empty_label)
	else:
		for item_data in items_in_category:
			var item = item_data["item"]
			var quantity = item_data["quantity"]
			_create_item_slot(item, quantity)

func _create_item_slot(item: Item, quantity: int):
	"""Crée un slot d'item dans la grille"""
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(80, 80)
	
	var vbox = VBoxContainer.new()
	slot.add_child(vbox)
	
	# Nom
	var name_label = Label.new()
	name_label.text = item.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)
	
	# Quantité
	if item.stackable and quantity > 1:
		var qty_label = Label.new()
		qty_label.text = "x" + str(quantity)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(qty_label)
	
	# Tooltip
	slot.tooltip_text = item.description
	
	items_grid.add_child(slot)

func _get_category_name(category: Item.ItemType) -> String:
	match category:
		Item.ItemType.POTION:
			return "Potions"
		Item.ItemType.OBJECT:
			return "Objets"
		Item.ItemType.SORTILEGE:
			return "Sortilèges"
		Item.ItemType.RARE_OBJECT:
			return "Objets Rares"
	return "Inconnu"

func _input(event):
	# Fermer avec Echap
	if event.is_action_pressed("ui_cancel") and visible:
		close_inventory()
		get_viewport().set_input_as_handled()
