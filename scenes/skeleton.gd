extends CharacterBody2D

## Skeleton - Créature invoquée qui suit le joueur et combat les ennemis
## Architecture modulaire basée sur des composants

# Composants (à ajouter dans la scène)
@onready var health: HealthComponent = $HealthComponent
@onready var necro_energy: NecroEnergyComponent = $NecroEnergyComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var formation: FormationFollower = $FormationFollower
@onready var state_manager: EntityStateManager = $EntityStateManager if has_node("EntityStateManager") else null

# UI
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar_rect: ColorRect = $HealthBar/HealthBarRect
@onready var necro_bar_rect: ColorRect = $NecroBar/NecroBarRect

# Configuration
@export var speed: float = 200.0

# État
enum State { IDLE, FOLLOWING, MOVING_TO_COMBAT, ATTACKING }
var current_state: State = State.IDLE
var current_direction: String = "south"
var merge_level: int = 0

# Variables pour le lissage de la barre d'énergie
var necro_bar_target_width: float = 0.0

func _ready():
	add_to_group("skeletons")
	_setup_components()
	_connect_signals()
	
	if animated_sprite:
		animated_sprite.play("idle_south")

func _setup_components():
	"""Configure les composants avec les valeurs par défaut"""
	if formation:
		formation.target = _find_player()
	
	# Configurer le state manager avec les callbacks
	if state_manager:
		state_manager.register_state_processor(EntityStateManager.State.IDLE, _process_idle)
		state_manager.register_state_processor(EntityStateManager.State.FOLLOWING, _process_following)
		state_manager.register_state_processor(EntityStateManager.State.MOVING_TO_COMBAT, _process_move_to_combat)
		state_manager.register_state_processor(EntityStateManager.State.ATTACKING, _process_attacking)

func _connect_signals():
	"""Connecte les signaux des composants"""
	if health:
		health.died.connect(_on_health_depleted)
		health.health_changed.connect(_on_health_changed)
	
	if necro_energy:
		necro_energy.energy_depleted.connect(_on_energy_depleted)
		necro_energy.energy_changed.connect(_on_necro_energy_changed)
	
	if combat:
		combat.attack_started.connect(_on_attack_started)
		combat.attack_finished.connect(_on_attack_finished)
		combat.enemy_hit.connect(_on_enemy_hit)

func _physics_process(delta):
	_update_state()
	
	# Utiliser le state manager si disponible, sinon fallback sur la logique legacy
	if state_manager:
		state_manager.process_current_state(delta)
	else:
		_process_current_state(delta)
	
	_apply_movement()
	_update_animation()

func _update_state():
	"""Met à jour l'état en fonction du contexte"""
	if not combat:
		return
	
	# Chercher un ennemi
	var detected_enemy = combat.find_closest_enemy(global_position)
	
	# Vérifier que l'ennemi est valide avant de l'assigner
	if detected_enemy and is_instance_valid(detected_enemy) and not detected_enemy.is_queued_for_deletion():
		combat.target = detected_enemy
	else:
		combat.target = null
	
	# Si un ennemi est détecté, aller au combat
	if combat.target != null and is_instance_valid(combat.target):
		var distance = global_position.distance_to(combat.target.global_position)
		if distance <= combat.attack_range:
			_set_state(State.ATTACKING)
		else:
			_set_state(State.MOVING_TO_COMBAT)
	else:
		# Pas d'ennemi : suivre le joueur en formation
		if formation and formation.target:
			var target_pos = formation.calculate_formation_position(self, "skeletons")
			# Si on est déjà à la position de formation, rester idle
			if formation.is_at_position(global_position, target_pos):
				_set_state(State.IDLE)
			else:
				_set_state(State.FOLLOWING)
		else:
			_set_state(State.IDLE)

func _set_state(new_state: State):
	"""Helper pour changer d'état avec support state_manager"""
	if state_manager:
		# Convertir l'enum local vers EntityStateManager.State
		var manager_state: EntityStateManager.State
		match new_state:
			State.IDLE:
				manager_state = EntityStateManager.State.IDLE
			State.FOLLOWING:
				manager_state = EntityStateManager.State.FOLLOWING
			State.MOVING_TO_COMBAT:
				manager_state = EntityStateManager.State.MOVING_TO_COMBAT
			State.ATTACKING:
				manager_state = EntityStateManager.State.ATTACKING
		state_manager.change_state(manager_state)
	
	# Toujours mettre à jour current_state pour la compatibilité
	current_state = new_state

func _process_current_state(delta):
	"""Traite la logique de l'état actuel (legacy fallback)"""
	match current_state:
		State.IDLE:
			_process_idle()
		State.FOLLOWING:
			_process_following()
		State.MOVING_TO_COMBAT:
			_process_move_to_combat()
		State.ATTACKING:
			_process_attacking()

func _process_idle(delta: float = 0.0):
	"""État idle - ne rien faire"""
	velocity = Vector2.ZERO
	if formation and formation.target:
		current_direction = formation.sync_direction_with_leader()

func _process_following(delta: float = 0.0):
	"""État de suivi du joueur en formation"""
	if not formation:
		return
	
	var target_position = formation.calculate_formation_position(self, "skeletons")
	_move_towards(target_position)
	
	# Synchroniser avec le joueur
	if formation.target:
		current_direction = formation.sync_direction_with_leader()

func _process_move_to_combat(delta: float = 0.0):
	"""État de déplacement vers un ennemi"""
	if combat and combat.target and is_instance_valid(combat.target):
		_move_towards(combat.target.global_position)

func _process_attacking(delta: float = 0.0):
	"""État d'attaque"""
	if not combat:
		return
	
	if combat.try_attack(global_position):
		velocity = Vector2.ZERO
		# Gagner de l'énergie noire en attaquant
		if necro_energy:
			necro_energy.add_energy(combat.damage)
	else:
		velocity = Vector2.ZERO
		# Regarder l'ennemi pendant le cooldown
		if combat.target and is_instance_valid(combat.target):
			var direction = combat.get_direction_to_target(global_position)
			_update_direction(direction)

func _move_towards(target_position: Vector2):
	"""Déplace le skeleton vers une position cible"""
	var direction = (target_position - global_position)
	var distance = direction.length()
	
	# Si on est déjà à destination
	if formation and formation.is_at_position(global_position, target_position):
		velocity = Vector2.ZERO
		return
	
	# Calculer la direction et vérifier qu'elle est valide
	if distance > 0.001:
		direction = CollisionHelper.safe_normalize(direction)
		
		if direction == Vector2.ZERO:
			velocity = Vector2.ZERO
			return
		
		velocity = direction * speed
		_update_direction(direction)
	else:
		velocity = Vector2.ZERO

func _apply_movement():
	"""Applique le mouvement et gère les collisions"""
	move_and_slide()
	_handle_collisions()

func _handle_collisions():
	"""Gère les collisions avec les obstacles"""
	if get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		if not collision:
			return
		
		var normal = collision.get_normal()
		var target_pos: Vector2
		
		# Déterminer la position cible en fonction de l'état
		if combat and combat.target and is_instance_valid(combat.target):
			target_pos = combat.target.global_position
		elif formation and formation.target:
			target_pos = formation.target.global_position
		else:
			return
		
		# Calculer la direction d'évitement
		var avoidance_dir = CollisionHelper.calculate_avoidance_direction(
			normal, velocity.normalized(), target_pos, global_position
		)
		velocity = avoidance_dir * speed

func _update_animation():
	"""Met à jour l'animation en fonction de l'état et de la direction"""
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	# Déterminer l'état d'animation
	var anim_state = "idle"
	if combat and combat.is_attacking:
		anim_state = "attack"
	elif velocity.length() > 1.0:
		anim_state = "walk"
	
	var animation_name = anim_state + "_" + current_direction
	
	# Jouer l'animation si elle existe
	if animated_sprite.sprite_frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)
	else:
		# Fallback vers idle
		var fallback_name = "idle_" + current_direction
		if animated_sprite.sprite_frames.has_animation(fallback_name):
			if animated_sprite.animation != fallback_name:
				animated_sprite.play(fallback_name)

func _update_direction(direction_vector: Vector2):
	"""Convertit un vecteur de direction en direction cardinale"""
	if direction_vector.length() < 0.1:
		return
	
	if abs(direction_vector.x) > abs(direction_vector.y):
		current_direction = "east" if direction_vector.x > 0 else "west"
	else:
		current_direction = "south" if direction_vector.y > 0 else "north"

func _find_player() -> Node2D:
	"""Trouve le joueur dans la scène"""
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		return players[0]
	
	var scene_root = get_tree().current_scene
	if scene_root:
		return scene_root.find_child("Player", true, false)
	
	return null

# ========== Callbacks des signaux ==========

func _on_health_depleted():
	"""Appelé quand la santé atteint 0"""
	print("Skeleton détruit par manque de santé!")
	queue_free()

func _on_energy_depleted():
	"""Appelé quand l'énergie nécromantique est épuisée"""
	print("Skeleton détruit par manque d'énergie nécromantique!")
	queue_free()

func _on_health_changed(current: int, maximum: int):
	"""Met à jour la barre de vie"""
	if health_bar_rect and health_bar_rect.get_parent():
		var health_percentage = float(current) / float(maximum)
		health_bar_rect.size.x = health_bar_rect.get_parent().size.x * health_percentage

func _on_necro_energy_changed(current: float, maximum: float):
	"""Met à jour la barre d'énergie nécromantique avec lissage"""
	if necro_bar_rect and necro_bar_rect.get_parent():
		var necro_percentage = current / maximum
		var parent_width = necro_bar_rect.get_parent().size.x
		necro_bar_target_width = parent_width * necro_percentage
		
		# Lisser la transition pour éviter les ticks visibles
		necro_bar_rect.size.x = lerp(necro_bar_rect.size.x, necro_bar_target_width, 0.3)

func _on_attack_started():
	"""Appelé quand une attaque démarre"""
	pass

func _on_attack_finished():
	"""Appelé quand une attaque se termine"""
	pass

func _on_enemy_hit(enemy: Node, damage_dealt: int):
	"""Appelé quand un ennemi est touché"""
	print("⚔️ Skeleton [niveau ", merge_level, "] attaque ", enemy.name, " pour ", damage_dealt, " dégâts")

# ========== API publique (pour compatibilité) ==========

func take_damage(amount: int):
	"""Inflige des dégâts au skeleton"""
	if health:
		health.take_damage(amount)
		print("Skeleton prend ", amount, " dégâts. Santé: ", health.current_health, "/", health.max_health)

func configure_merged_stats_from_data(data: Dictionary, multiplier: float = 2.0):
	"""Configure les stats pour un skeleton mergé à partir de données extraites
	Cette méthode permet de supprimer les skeletons sources immédiatement sans attendre"""
	# Si pas encore ready, attendre
	if not is_node_ready():
		await ready
	
	# Attendre une frame pour que les composants enfants @onready soient initialisés
	await get_tree().process_frame
	
	print("🔄 Configuration skeleton fusionné (niveau ", merge_level, ") avec multiplier x", multiplier)
	print("  📍 Components: health=", health != null, " combat=", combat != null, " necro=", necro_energy != null)
	
	# Configurer la santé
	if health and data.has("max_health"):
		var old_hp = data["max_health"]
		health.max_health = int(old_hp * multiplier)
		health.current_health = health.max_health
		print("  ❤️ HP: ", old_hp, " × ", multiplier, " = ", health.max_health)
	else:
		print("  ⚠️ Impossible de configurer HP - health:", health != null, " data_has:", data.has("max_health"))
	
	# Configurer le combat
	if combat:
		if data.has("damage"):
			var old_damage = data["damage"]
			combat.damage = int(old_damage * multiplier)
			print("  ⚔️ Dégâts: ", old_damage, " × ", multiplier, " = ", combat.damage)
		if data.has("attack_range"):
			combat.attack_range = data["attack_range"]
		if data.has("attack_cooldown"):
			combat.attack_cooldown = data["attack_cooldown"]
		if data.has("attack_duration"):
			combat.attack_duration = data["attack_duration"]
		if data.has("detection_range"):
			combat.detection_range = data["detection_range"]
	else:
		print("  ⚠️ CombatComponent non trouvé!")
	
	# Configurer l'énergie noire
	if necro_energy:
		if data.has("max_necro_energy"):
			var old_max_energy = data["max_necro_energy"]
			necro_energy.max_energy = old_max_energy * multiplier
			necro_energy.current_energy = necro_energy.max_energy
			print("  ⚡ Énergie max: ", old_max_energy, " × ", multiplier, " = ", necro_energy.max_energy)
		
		# IMPORTANT: Multiplier aussi le drain_rate pour que la barre s'écoule toujours en 30 secondes
		if data.has("drain_rate"):
			var old_drain_rate = data["drain_rate"]
			necro_energy.drain_rate = old_drain_rate * multiplier
			print("  ⏱️ Drain rate: ", old_drain_rate, " × ", multiplier, " = ", necro_energy.drain_rate, " pts/sec")
	
	# Configurer la formation
	if formation and data.has("follow_distance"):
		formation.follow_distance = data["follow_distance"]

func configure_merged_stats(source_skeleton: CharacterBody2D, multiplier: float = 2.0):
	"""Configure les stats pour un skeleton mergé (méthode legacy)
	DEPRECATED: Utilisez configure_merged_stats_from_data pour une gestion propre des ressources"""
	# Attendre que les composants soient prêts
	await ready
	
	# Si le skeleton source a les anciens attributs directs (skeleton_backup)
	if "max_health" in source_skeleton:
		if health:
			health.max_health = int(source_skeleton.max_health * multiplier)
			health.current_health = health.max_health
		if combat:
			combat.damage = int(source_skeleton.damage * multiplier)
			combat.attack_range = source_skeleton.attack_range
			combat.attack_cooldown = source_skeleton.attack_cooldown
			combat.attack_duration = source_skeleton.attack_duration
			combat.detection_range = source_skeleton.enemy_detection_range
		if necro_energy:
			necro_energy.max_energy = source_skeleton.max_necro_energy * multiplier
			necro_energy.current_energy = necro_energy.max_energy
			# IMPORTANT: Multiplier aussi le drain_rate
			if "drain_rate" in source_skeleton:
				necro_energy.drain_rate = source_skeleton.drain_rate * multiplier
		if formation:
			formation.follow_distance = source_skeleton.follow_distance
			formation.distance_tolerance = source_skeleton.distance_tolerance
		speed = source_skeleton.speed
	# Si le skeleton source utilise la nouvelle architecture
	else:
		if health and source_skeleton.get_node_or_null("HealthComponent"):
			var source_health = source_skeleton.get_node("HealthComponent")
			health.max_health = int(source_health.max_health * multiplier)
			health.current_health = health.max_health
		
		if combat and source_skeleton.get_node_or_null("CombatComponent"):
			var source_combat = source_skeleton.get_node("CombatComponent")
			combat.damage = int(source_combat.damage * multiplier)
			combat.attack_range = source_combat.attack_range
			combat.attack_cooldown = source_combat.attack_cooldown
			combat.attack_duration = source_combat.attack_duration
			combat.detection_range = source_combat.detection_range
		
		if necro_energy and source_skeleton.get_node_or_null("NecroEnergyComponent"):
			var source_necro = source_skeleton.get_node("NecroEnergyComponent")
			necro_energy.max_energy = source_necro.max_energy * multiplier
			necro_energy.current_energy = necro_energy.max_energy
			# IMPORTANT: Multiplier aussi le drain_rate
			necro_energy.drain_rate = source_necro.drain_rate * multiplier
		
		if formation and source_skeleton.get_node_or_null("FormationFollower"):
			var source_formation = source_skeleton.get_node("FormationFollower")
			formation.follow_distance = source_formation.follow_distance
			formation.distance_tolerance = source_formation.distance_tolerance
		
		speed = source_skeleton.speed
