extends CharacterBody2D

## Player - Joueur contrôlé par l'utilisateur
## Architecture modulaire basée sur des composants

# Composants (optionnels pour migration progressive)
@onready var health: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var necro_energy: NecroEnergyComponent = $NecroEnergyComponent if has_node("NecroEnergyComponent") else null
@onready var movement: MovementComponent = $MovementComponent if has_node("MovementComponent") else null
@onready var animation: AnimationComponent = $AnimationComponent if has_node("AnimationComponent") else null
@onready var summoner: SummonerComponent = $SummonerComponent if has_node("SummonerComponent") else null
@onready var merge_manager: SkeletonMergeManager = $SkeletonMergeManager if has_node("SkeletonMergeManager") else null
@onready var inventory: InventoryComponent = $InventoryComponent if has_node("InventoryComponent") else null
@onready var inventory_ui: InventoryUI = $InventoryUI if has_node("InventoryUI") else null

# UI
@onready var health_bar_rect: ColorRect = $HealthBar/HealthBarRect
@onready var necro_bar_rect: ColorRect = $NecroBar/NecroBarRect

# Configuration export
@export var speed: float = 200.0
@export var skeleton_scene: PackedScene = preload("res://scenes/skeleton.tscn")
@export var summon_cooldown: float = 1
@export var summon_energy_cost: float = 40.0 
@export var merge_energy_cost: float = 50.0 

# État
enum State { IDLE, WALKING, ATTACKING }
var current_state: State = State.IDLE

func _ready():
	add_to_group("players")
	
	# Vérifier que les composants sont présents
	_check_components()
	
	_setup_components()
	_connect_signals()
	
	# Configurer l'inventaire UI
	if inventory and inventory_ui:
		inventory_ui.setup(inventory)
		
		# TEST : Ajouter quelques items de test
		_add_test_items()
	
	# Lancer l'animation idle par défaut
	if animation:
		animation.play("idle", "south")

func _check_components():
	"""Vérifie la présence des composants et affiche des avertissements"""
	var missing_components = []
	
	if not health:
		missing_components.append("HealthComponent")
	if not necro_energy:
		missing_components.append("NecroEnergyComponent")
	if not movement:
		missing_components.append("MovementComponent")
	if not animation:
		missing_components.append("AnimationComponent")
	if not summoner:
		missing_components.append("SummonerComponent")
	if not merge_manager:
		missing_components.append("SkeletonMergeManager")
	if not inventory:
		missing_components.append("InventoryComponent")
	if not inventory_ui:
		missing_components.append("InventoryUI")
	
	if missing_components.size() > 0:
		push_warning("⚠️ Player: Composants manquants: " + ", ".join(missing_components))
		push_warning("   Ajoutez ces nœuds dans player.tscn pour activer toutes les fonctionnalités")

func _setup_components():
	"""Configure les composants avec les valeurs appropriées"""
	if movement:
		movement.speed = speed
	
	if summoner:
		summoner.summon_scene = skeleton_scene
		summoner.summon_cooldown = summon_cooldown
		summoner.summoned_group = "skeletons"
	
	if animation:
		animation.use_8_directions = true
	
	if merge_manager:
		merge_manager.skeleton_scene = skeleton_scene
		merge_manager.merge_multiplier = 2.0
		merge_manager.sprite_scale_multiplier = 1.5

func _connect_signals():
	"""Connecte les signaux des composants"""
	if health:
		health.died.connect(_on_died)
		health.health_changed.connect(_on_health_changed)
	
	if necro_energy:
		necro_energy.energy_changed.connect(_on_necro_energy_changed)
		necro_energy.energy_consumed.connect(_on_necro_energy_consumed)
	
	if summoner:
		summoner.summon_completed.connect(_on_summon_completed)
		summoner.summon_failed.connect(_on_summon_failed)
	
	if merge_manager:
		merge_manager.merge_completed.connect(_on_merge_completed)
		merge_manager.merge_failed.connect(_on_merge_failed)

func _unhandled_input(event):
	"""Gère les inputs spéciaux (invocation, fusion, inventaire)"""
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
	elif event.is_action_pressed("sort1"):
		_summon_skeleton_in_direction()
	elif event.is_action_pressed("sort2"):
		_merge_skeletons()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_summon_skeleton_at_mouse()

func _physics_process(delta):
	# Invocation continue au clic souris
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_summon_skeleton_at_mouse()
	
	# Gestion du mouvement
	_handle_movement_input(delta)
	
	# Appliquer le mouvement
	if movement:
		movement.apply_movement()

func _handle_movement_input(delta):
	"""Gère les inputs de mouvement du joueur"""
	if not movement or not animation:
		return
	
	# Récupérer l'input du joueur
	var input_vector = Vector2.ZERO
	
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	# Clavier ZQSD
	if Input.is_key_pressed(KEY_Q):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_Z):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0
	
	# Logique d'attaque (à implémenter plus tard)
	var is_attacking = false
	
	# Déplacement
	if input_vector.length() > 0 and not is_attacking:
		movement.move_in_direction(input_vector)
		animation.set_state("walk")
		animation.set_direction_from_vector(input_vector)
		current_state = State.WALKING
	elif is_attacking:
		movement.stop()
		animation.set_state("attack")
		current_state = State.ATTACKING
	else:
		movement.stop()
		animation.set_state("idle")
		current_state = State.IDLE

func _summon_skeleton_in_direction():
	"""Invoque un skeleton dans la direction du joueur"""
	if not summoner or not animation:
		return
	
	# Vérifier si le sort peut être appliqué (cooldown, etc.)
	if not summoner.can_summon():
		return  # En cooldown, ne pas consommer d'énergie
	
	# Vérifier et consommer l'énergie UNIQUEMENT si le sort peut être lancé
	if necro_energy and not necro_energy.can_consume(summon_energy_cost):
		print("⚡ Pas assez d'énergie pour invoquer (", necro_energy.current_energy, "/", summon_energy_cost, ")")
		return
	
	# Consommer l'énergie
	if necro_energy:
		necro_energy.consume_energy(summon_energy_cost)
	
	var direction = get_direction_vector()
	summoner.summon_at_direction(direction)

func _summon_skeleton_at_mouse():
	"""Invoque un skeleton à la position de la souris"""
	if not summoner:
		return
	
	# Vérifier si le sort peut être appliqué (cooldown, etc.)
	if not summoner.can_summon():
		return  # En cooldown, ne pas consommer d'énergie
	
	# Vérifier et consommer l'énergie UNIQUEMENT si le sort peut être lancé
	if necro_energy and not necro_energy.can_consume(summon_energy_cost):
		print("⚡ Pas assez d'énergie pour invoquer (", necro_energy.current_energy, "/", summon_energy_cost, ")")
		return
	
	# Consommer l'énergie
	if necro_energy:
		necro_energy.consume_energy(summon_energy_cost)
	
	var mouse_position = get_global_mouse_position()
	summoner.summon_at_position(mouse_position)

func _merge_skeletons():
	"""Fusionne les skeletons par paires de même niveau"""
	if not merge_manager:
		print("⚠️ SkeletonMergeManager non trouvé")
		return
	
	# Vérifier s'il y a assez de skeletons AVANT de consommer l'énergie
	var skeleton_count = _count_valid_skeletons()
	if skeleton_count < 2:
		print("⚠️ Pas assez de skeletons pour fusionner (", skeleton_count, "/2)")
		return  # Ne pas consommer d'énergie
	
	# Vérifier et consommer l'énergie UNIQUEMENT si le sort peut être lancé
	if necro_energy and not necro_energy.can_consume(merge_energy_cost):
		print("⚡ Pas assez d'énergie pour fusionner (", necro_energy.current_energy, "/", merge_energy_cost, ")")
		return
	
	# Consommer l'énergie
	if necro_energy:
		necro_energy.consume_energy(merge_energy_cost)
	
	print("🔀 MERGE: Début de la fusion des skeletons")
	
	# Déléguer toute la logique de fusion au composant
	await merge_manager.merge_skeletons("skeletons")


# ========== Méthodes utilitaires ==========

func _count_valid_skeletons() -> int:
	"""Compte le nombre de skeletons valides dans le groupe"""
	var skeletons = get_tree().get_nodes_in_group("skeletons")
	var count = 0
	
	for skeleton in skeletons:
		if is_instance_valid(skeleton) and not skeleton.is_queued_for_deletion():
			count += 1
	
	return count

func get_direction_vector() -> Vector2:
	"""Retourne le vecteur de direction du joueur"""
	if animation:
		var direction = animation.get_current_direction()
		match direction:
			"south": return Vector2(0, 1)
			"south_east": return Vector2(1, 1).normalized()
			"east": return Vector2(1, 0)
			"north_east": return Vector2(1, -1).normalized()
			"north": return Vector2(0, -1)
			"north_west": return Vector2(-1, -1).normalized()
			"west": return Vector2(-1, 0)
			"south_west": return Vector2(-1, 1).normalized()
	
	return Vector2(0, 1)  # Défaut: sud

func get_cardinal_direction() -> String:
	"""Retourne la direction cardinale (4 directions)"""
	if animation:
		return animation.get_cardinal_direction()
	return "south"

# ========== Callbacks des signaux ==========

func _on_died():
	"""Appelé quand la santé atteint 0"""
	print("Joueur détruit! Game Over")
	queue_free()

func _on_health_changed(current: int, maximum: int):
	"""Met à jour la barre de vie"""
	if health_bar_rect and health_bar_rect.get_parent():
		var health_percentage = float(current) / float(maximum)
		health_bar_rect.size.x = health_bar_rect.get_parent().size.x * health_percentage

func _on_necro_energy_changed(current: float, maximum: float):
	"""Met à jour la barre d'énergie nécromantique"""
	if necro_bar_rect and necro_bar_rect.get_parent():
		var energy_percentage = current / maximum
		necro_bar_rect.size.x = necro_bar_rect.get_parent().size.x * energy_percentage

func _on_necro_energy_consumed(amount: float, remaining: float):
	"""Appelé quand de l'énergie est consommée"""
	print("⚡ Énergie consommée: -", amount, " (reste: ", remaining, ")")

func _on_summon_completed(summoned_entity: Node):
	"""Appelé quand une invocation réussit"""
	pass

func _on_summon_failed(reason: String):
	"""Appelé quand une invocation échoue"""
	pass

func _on_merge_completed(merged_count: int):
	"""Appelé quand une fusion réussit"""
	if merged_count > 0:
		print("✅ Fusion de ", merged_count, " paire(s) de skeletons effectuée")

func _on_merge_failed(reason: String):
	"""Appelé quand une fusion échoue"""
	print("⚠️ ", reason)

# ========== Gestion de l'inventaire ==========

func _toggle_inventory():
	"""Ouvre/ferme l'inventaire"""
	if not inventory_ui:
		return
	
	if inventory_ui.visible:
		inventory_ui.close_inventory()
	else:
		inventory_ui.open_inventory()

func _add_test_items():
	"""Ajoute quelques items de test à l'inventaire"""
	if not inventory:
		return
	
	# Potion de vie
	var health_potion = Item.new()
	health_potion.id = "health_potion"
	health_potion.name = "Potion de Vie"
	health_potion.description = "Restaure 50 HP"
	health_potion.item_type = Item.ItemType.POTION
	health_potion.stackable = true
	health_potion.max_stack = 10
	inventory.add_item(health_potion, 3)
	
	# Potion de mana
	var mana_potion = Item.new()
	mana_potion.id = "mana_potion"
	mana_potion.name = "Potion de Mana"
	mana_potion.description = "Restaure 30 énergie nécromantique"
	mana_potion.item_type = Item.ItemType.POTION
	mana_potion.stackable = true
	mana_potion.max_stack = 10
	inventory.add_item(mana_potion, 5)
	
	# Sort de feu
	var fire_spell = Item.new()
	fire_spell.id = "fire_spell"
	fire_spell.name = "Sort de Feu"
	fire_spell.description = "Lance une boule de feu dévastatrice"
	fire_spell.item_type = Item.ItemType.GRIMOIRE
	fire_spell.stackable = false
	inventory.add_item(fire_spell, 1)
	
	# Clé rouillée
	var rusty_key = Item.new()
	rusty_key.id = "rusty_key"
	rusty_key.name = "Clé Rouillée"
	rusty_key.description = "Une vieille clé qui pourrait ouvrir quelque chose..."
	rusty_key.item_type = Item.ItemType.OBJECT
	rusty_key.stackable = false
	inventory.add_item(rusty_key, 1)
	
	# Gemme rare
	var rare_gem = Item.new()
	rare_gem.id = "rare_gem"
	rare_gem.name = "Gemme d'Améthyste"
	rare_gem.description = "Une gemme précieuse qui brille d'une lueur violette"
	rare_gem.item_type = Item.ItemType.RARE_OBJECT
	rare_gem.stackable = true
	rare_gem.max_stack = 99
	inventory.add_item(rare_gem, 2)
	
	print("🎒 Items de test ajoutés à l'inventaire")

# ========== API publique (pour compatibilité) ==========

func take_damage(amount: int):
	"""Inflige des dégâts au joueur"""
	if health:
		health.take_damage(amount)
		print("Joueur prend ", amount, " dégâts. Santé: ", health.current_health, "/", health.max_health)
