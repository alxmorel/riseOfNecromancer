extends CharacterBody2D

## Enemy - Ennemi qui attaque les skeletons et le joueur
## Architecture modulaire basée sur des composants

# Composants (optionnels pour migration progressive)
@onready var health: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var combat: CombatComponent = $CombatComponent if has_node("CombatComponent") else null
@onready var movement: MovementComponent = $MovementComponent if has_node("MovementComponent") else null
@onready var animation: AnimationComponent = $AnimationComponent if has_node("AnimationComponent") else null
@onready var target_detection: TargetDetectionComponent = $TargetDetectionComponent if has_node("TargetDetectionComponent") else null

# UI
@onready var health_bar_rect: ColorRect = $HealthBar/HealthBarRect

# Configuration export pour l'éditeur
@export var speed: float = 150.0

# État
enum State { IDLE, CHASING, ATTACKING }
var current_state: State = State.IDLE

func _ready():
	add_to_group("enemies")
	
	# Vérifier que les composants sont présents
	_check_components()
	
	_setup_components()
	_connect_signals()
	
	# Lancer l'animation idle par défaut
	if animation:
		animation.play("idle", "south")

func _check_components():
	"""Vérifie la présence des composants et affiche des avertissements"""
	var missing_components = []
	
	if not health:
		missing_components.append("HealthComponent")
	if not movement:
		missing_components.append("MovementComponent")
	if not animation:
		missing_components.append("AnimationComponent")
	if not combat:
		missing_components.append("CombatComponent")
	if not target_detection:
		missing_components.append("TargetDetectionComponent")
	
	if missing_components.size() > 0:
		push_warning("⚠️ Enemy: Composants manquants: " + ", ".join(missing_components))
		push_warning("   Ajoutez ces nœuds dans enemy.tscn pour activer toutes les fonctionnalités")
		push_warning("   Voir COMPOSANTS_MIGRATION_GUIDE.md pour les instructions")

func _setup_components():
	"""Configure les composants avec les valeurs appropriées"""
	# Configurer la détection de cibles (priorité: skeletons > joueur)
	if target_detection:
		target_detection.set_target_groups_by_priority(["skeletons", "players"])
	
	# Configurer le mouvement
	if movement:
		movement.speed = speed

func _connect_signals():
	"""Connecte les signaux des composants"""
	if health:
		health.died.connect(_on_died)
		health.health_changed.connect(_on_health_changed)
	
	if combat:
		combat.attack_started.connect(_on_attack_started)
		combat.attack_finished.connect(_on_attack_finished)
		combat.enemy_hit.connect(_on_enemy_hit)
	
	if target_detection:
		target_detection.target_acquired.connect(_on_target_acquired)
		target_detection.target_lost.connect(_on_target_lost)

func _physics_process(delta):
	_update_state()
	_process_current_state(delta)

func _update_state():
	"""Met à jour l'état en fonction du contexte"""
	if not combat or not target_detection:
		return
	
	# Synchroniser la cible du combat avec la détection
	var detected_target = target_detection.get_target()
	
	# Vérifier que la cible est valide avant de l'assigner
	if detected_target and is_instance_valid(detected_target) and not detected_target.is_queued_for_deletion():
		combat.target = detected_target
	else:
		combat.target = null
	
	# Déterminer le nouvel état
	if not target_detection.has_target():
		current_state = State.IDLE
	elif combat.is_in_range(global_position):
		current_state = State.ATTACKING
	else:
		current_state = State.CHASING

func _process_current_state(delta):
	"""Traite la logique de l'état actuel"""
	match current_state:
		State.IDLE:
			_process_idle()
		State.CHASING:
			_process_chasing()
		State.ATTACKING:
			_process_attacking()

func _process_idle():
	"""État idle - attendre"""
	if movement:
		movement.stop()
	
	if animation:
		animation.set_state("idle")

func _process_chasing():
	"""État de poursuite de la cible"""
	if not target_detection or not movement or not animation:
		return
	
	var target = target_detection.get_target()
	if not target:
		return
	
	# Se déplacer vers la cible
	movement.move_towards(target.global_position)
	movement.apply_movement()
	
	# Mettre à jour l'animation
	animation.set_state("walk")
	if movement.is_moving():
		animation.set_direction_from_vector(movement.get_direction())

func _process_attacking():
	"""État d'attaque"""
	if not combat or not movement or not animation:
		return
	
	# Tenter d'attaquer
	if combat.try_attack(global_position):
		movement.stop()
	else:
		# En cooldown, s'arrêter et regarder la cible
		movement.stop()
		if not combat.is_attacking:
			animation.set_state("idle")
		
		# Regarder vers la cible
		var direction = combat.get_direction_to_target(global_position)
		if direction != Vector2.ZERO:
			animation.set_direction_from_vector(direction)
	
	# Appliquer le mouvement (pour les collisions si nécessaire)
	if movement:
		movement.apply_movement()

# ========== Callbacks des signaux ==========

func _on_died():
	"""Appelé quand la santé atteint 0"""
	print("Ennemi détruit!")
	queue_free()

func _on_health_changed(current: int, maximum: int):
	"""Met à jour la barre de vie"""
	if health_bar_rect and health_bar_rect.get_parent():
		var health_percentage = float(current) / float(maximum)
		health_bar_rect.size.x = health_bar_rect.get_parent().size.x * health_percentage

func _on_attack_started():
	"""Appelé quand une attaque démarre"""
	if animation:
		animation.set_state("attack")

func _on_attack_finished():
	"""Appelé quand une attaque se termine"""
	pass

func _on_enemy_hit(enemy: Node, damage_dealt: int):
	"""Appelé quand un ennemi est touché"""
	print("Ennemi attaque ", enemy.name, " pour ", damage_dealt, " dégâts")

func _on_target_acquired(target: Node2D):
	"""Appelé quand une nouvelle cible est acquise"""
	print("Ennemi cible: ", target.name)

func _on_target_lost():
	"""Appelé quand la cible est perdue"""
	print("Ennemi a perdu sa cible")

# ========== API publique (pour compatibilité) ==========

func take_damage(amount: int):
	"""Inflige des dégâts à l'ennemi"""
	if health:
		health.take_damage(amount)
		print("Ennemi prend ", amount, " dégâts. Santé: ", health.current_health, "/", health.max_health)
