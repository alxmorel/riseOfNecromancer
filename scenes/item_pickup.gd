extends Area2D
class_name ItemPickup

## ItemPickup - Représente un item ramassable au sol
## Place ce nœud dans tes scènes pour créer des objets à ramasser

signal item_picked_up(item: Item, quantity: int)

# L'item que contient ce pickup
@export var item_resource: Item = null

# Quantité d'items
@export var quantity: int = 1

# Ramassage automatique ou manuel
@export var auto_pickup: bool = false

# Touche pour ramasser (si non automatique)
@export var pickup_key: String = "interact"

# Affichage du nom de l'item
@export var show_name: bool = true

# Effet visuel
@export var bob_animation: bool = true  # Animation flottante
@export var bob_height: float = 5.0
@export var bob_speed: float = 2.0

# Affichage du sprite
@export var show_sprite: bool = true
@export var sprite_scale: float = 1.0

# Label d'interaction
@export var show_interaction_prompt: bool = true
@export var interaction_text: String = "Appuyez sur [E]"

# État interne
var player_in_area: bool = false
var time: float = 0.0
var initial_position: Vector2
var label: Label = null
var sprite: Sprite2D = null
var interaction_label: Label = null

func _ready():
	# Connecter les signaux
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Sauvegarder la position initiale
	initial_position = position
	
	# Créer le sprite si l'item a une icône ET si show_sprite est true
	if item_resource and item_resource.icon and show_sprite:
		_create_sprite()
	
	# Créer le label de nom
	if show_name and item_resource:
		_create_label()
	
	# Créer le label d'interaction (seulement si pas en auto_pickup)
	if show_interaction_prompt and not auto_pickup:
		_create_interaction_label()
	
	# Vérifier la configuration
	if not item_resource:
		push_warning("⚠️ ItemPickup '", name, "' n'a pas d'item défini!")

func _create_sprite():
	"""Crée le sprite pour afficher l'icône de l'item"""
	if not show_sprite:
		return  # Ne pas créer le sprite si show_sprite est false
	
	sprite = Sprite2D.new()
	sprite.texture = item_resource.icon
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(sprite)

func _create_label():
	"""Crée un label pour afficher le nom de l'item"""
	label = Label.new()
	label.text = item_resource.name
	if quantity > 1:
		label.text += " x" + str(quantity)
	label.z_index = 100
	label.position = Vector2(-30, -30)  # Au-dessus de l'item
	
	# Style
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	
	add_child(label)

func _create_interaction_label():
	"""Crée un label pour afficher l'invite d'interaction"""
	interaction_label = Label.new()
	interaction_label.text = interaction_text
	interaction_label.visible = false
	interaction_label.z_index = 100
	interaction_label.position = Vector2(-5, -15)
	interaction_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Style
	interaction_label.add_theme_font_size_override("font_size", 8)
	interaction_label.add_theme_color_override("font_color", Color.WHITE)
	interaction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	interaction_label.add_theme_constant_override("outline_size", 1)
	
	add_child(interaction_label)

func _process(delta: float):
	# Animation de flottement
	if bob_animation:
		time += delta * bob_speed
		position.y = initial_position.y + sin(time) * bob_height

func _on_body_entered(body: Node2D):
	"""Appelé quand un corps entre dans la zone"""
	if not body.is_in_group("players"):
		return
	
	print("👜 Joueur près de l'item: ", item_resource.name if item_resource else "None")
	player_in_area = true
	
	# Afficher le label d'interaction
	if interaction_label:
		interaction_label.visible = true
	
	# Ramassage automatique
	if auto_pickup:
		_pickup_item(body)

func _on_body_exited(body: Node2D):
	"""Appelé quand un corps sort de la zone"""
	if not body.is_in_group("players"):
		return
	
	player_in_area = false
	
	# Cacher le label d'interaction
	if interaction_label:
		interaction_label.visible = false

func _input(event: InputEvent):
	"""Gère le ramassage manuel"""
	if not player_in_area or auto_pickup:
		return
	
	if event.is_action_pressed(pickup_key):
		var player = _get_player_in_area()
		if player:
			_pickup_item(player)

func _pickup_item(player: Node):
	"""Ramasse l'item et l'ajoute à l'inventaire"""
	if not item_resource:
		print("❌ Aucun item à ramasser!")
		return
	
	# Vérifier si le joueur a un inventaire
	if not player.has_node("InventoryComponent"):
		print("❌ Le joueur n'a pas d'InventoryComponent!")
		return
	
	var inventory = player.get_node("InventoryComponent")
	
	# Essayer d'ajouter l'item
	var success = inventory.add_item(item_resource, quantity)
	
	if success:
		print("✅ Item ramassé: ", item_resource.name, " x", quantity)
		item_picked_up.emit(item_resource, quantity)
		
		# Effet visuel/sonore (à ajouter plus tard)
		_play_pickup_effect()
		
		# Détruire l'item au sol
		queue_free()
	else:
		print("⚠️ Impossible d'ajouter l'item (inventaire plein?)")

func _play_pickup_effect():
	"""Joue un effet lors du ramassage"""
	# Animation de disparition simple
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)

func _get_player_in_area() -> Node:
	"""Récupère le joueur dans la zone"""
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("players"):
			return body
	return null
