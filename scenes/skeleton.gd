extends CharacterBody2D

# Vitesse de déplacement
@export var speed: float = 200.0

# Distance autour du joueur
@export var follow_distance: float = 50.0

# Tolérance pour la distance (évite les micro-mouvements)
@export var distance_tolerance: float = 10.0

# Distance d'attaque (portée de mêlée)
@export var attack_range: float = 30.0

# Dégâts infligés
@export var damage: int = 15

# Cooldown entre les attaques (en secondes)
@export var attack_cooldown: float = 1.2
var last_attack_time: float = 0.0

# Durée de l'animation d'attaque (en secondes)
@export var attack_duration: float = 0.6
var attack_timer: float = 0.0
var is_attacking: bool = false

# Portée de détection des ennemis
@export var enemy_detection_range: float = 50.0

# Référence au AnimatedSprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Référence au joueur
var target: CharacterBody2D = null

# Cible d'attaque (ennemi)
var attack_target: CharacterBody2D = null

# Direction actuelle (4 directions: north, south, east, west)
var current_direction: String = "south"

# État actuel (synchronisé avec le joueur si pas de combat)
var current_state: String = "idle"

# Angle préféré autour du joueur (en radians)
var preferred_angle: float = 0.0

func _ready():
	add_to_group("skeletons")
	# Trouver le joueur
	find_target()
	# Définir l'animation idle par défaut
	if animated_sprite:
		animated_sprite.play("idle_south")
	
	# Compter les skeletons existants pour répartition uniforme
	var skeletons = get_tree().get_nodes_in_group("skeletons")
	var skeleton_count = skeletons.size()
	
	# Calculer l'angle en fonction du nombre de skeletons
	if skeleton_count > 1:
		var angle_step = TAU / skeleton_count
		preferred_angle = angle_step * (skeleton_count - 1)
	else:
		preferred_angle = 0.0

func find_target():
	"""Trouve le joueur dans la scène"""
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		target = players[0]
	else:
		# Alternative : chercher par nom
		var scene_root = get_tree().current_scene
		if scene_root:
			target = scene_root.find_child("Player", true, false)

func find_enemy():
	"""Trouve un ennemi à portée"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= enemy_detection_range and distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	attack_target = closest_enemy

func _physics_process(delta):
	# Gérer le timer d'attaque
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			current_state = "idle"
	
	# Trouver le joueur si nécessaire
	if target == null:
		find_target()
		if target == null:
			return
	
	# Chercher un ennemi à portée
	find_enemy()
	
	# Si un ennemi est à portée, le combattre
	if attack_target != null and is_instance_valid(attack_target):
		var distance_to_enemy = global_position.distance_to(attack_target.global_position)
		
		# Si l'ennemi est à portée d'attaque
		if distance_to_enemy <= attack_range:
			# Attaquer l'ennemi
			try_attack_enemy()
		else:
			# Se déplacer vers l'ennemi
			move_towards_enemy()
		
		# Ne pas suivre le joueur pendant le combat
		play_animation()
		move_and_slide()
		return
	
	# Pas d'ennemi, suivre le joueur normalement
	# Synchroniser l'état avec le joueur
	if not is_attacking:
		if "current_state" in target:
			current_state = target.current_state
		else:
			# Fallback : déterminer l'état basé sur le mouvement
			current_state = "idle" if velocity.length() < 1.0 else "walk"
	
	# Calculer la distance actuelle au joueur
	var distance_to_player = global_position.distance_to(target.global_position)
	
	# Calculer la position cible sur le cercle autour du joueur
	var target_position: Vector2
	
	# Si on est trop proche ou trop loin, ajuster vers la distance idéale
	if abs(distance_to_player - follow_distance) > distance_tolerance:
		# Calculer la direction actuelle du skeleton par rapport au joueur
		var direction_to_skeleton = (global_position - target.global_position).normalized()
		var current_angle = direction_to_skeleton.angle()
		
		# Utiliser un mélange entre l'angle actuel et l'angle préféré
		var target_angle = lerp_angle(current_angle, preferred_angle, 0.1)
		
		# Calculer la position cible sur le cercle
		target_position = target.global_position + Vector2(cos(target_angle), sin(target_angle)) * follow_distance
	else:
		# Si on est à la bonne distance, rester sur le cercle mais ajuster légèrement
		var direction_to_skeleton = (global_position - target.global_position).normalized()
		var current_angle = direction_to_skeleton.angle()
		
		# Légèrement ajuster vers l'angle préféré
		var target_angle = lerp_angle(current_angle, preferred_angle, 0.05)
		target_position = target.global_position + Vector2(cos(target_angle), sin(target_angle)) * follow_distance
	
	# Calculer la direction de mouvement nécessaire
	var move_direction = (target_position - global_position)
	var distance_to_target = move_direction.length()
	
	# Si on est assez proche de la position cible, s'arrêter
	if distance_to_target <= distance_tolerance:
		velocity = Vector2.ZERO
	else:
		# Normaliser et appliquer la vitesse
		move_direction = move_direction.normalized()
		velocity = move_direction * speed
		
		# Calculer la direction cardinale basée sur le mouvement
		update_direction(move_direction)
	
	# Synchroniser la direction avec le joueur si possible (seulement si pas de combat)
	if attack_target == null and target.has_method("get_cardinal_direction"):
		current_direction = target.get_cardinal_direction()
	
	# Jouer l'animation appropriée selon l'état
	play_animation()
	
	# Appliquer le mouvement
	move_and_slide()

func move_towards_enemy():
	"""Se déplace vers l'ennemi"""
	if attack_target == null or not is_instance_valid(attack_target):
		return
	
	# Calculer la direction vers l'ennemi
	var direction = (attack_target.global_position - global_position).normalized()
	
	# Appliquer la vitesse
	velocity = direction * speed
	
	# Mettre à jour la direction pour l'animation
	update_direction(direction)
	
	# Mettre à jour l'état
	if not is_attacking:
		current_state = "walk"

func try_attack_enemy():
	"""Tente d'attaquer l'ennemi si le cooldown est terminé"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_attack_time >= attack_cooldown:
		# Attaquer
		attack_enemy()
		last_attack_time = current_time
		is_attacking = true
		attack_timer = attack_duration
		current_state = "attack"
	else:
		# En cooldown, s'arrêter et regarder l'ennemi
		velocity = Vector2.ZERO
		if not is_attacking:
			current_state = "idle"
		# Mettre à jour la direction vers l'ennemi
		if attack_target:
			var direction = (attack_target.global_position - global_position).normalized()
			update_direction(direction)

func attack_enemy():
	"""Attaque l'ennemi actuel"""
	if attack_target == null or not is_instance_valid(attack_target):
		return
	
	# Calculer la direction vers l'ennemi pour l'animation
	var direction = (attack_target.global_position - global_position).normalized()
	update_direction(direction)
	
	# Infliger des dégâts à l'ennemi
	if attack_target.has_method("take_damage"):
		attack_target.take_damage(damage)
	
	# S'arrêter pendant l'attaque
	velocity = Vector2.ZERO
	
	print("Skeleton attaque ", attack_target.name, " pour ", damage, " dégâts")

func update_direction(direction_vector: Vector2):
	"""
	Convertit un vecteur de direction en direction cardinale (4 directions)
	Utilisé comme fallback si le joueur n'expose pas sa direction
	"""
	if abs(direction_vector.x) > abs(direction_vector.y):
		# Mouvement principalement horizontal
		current_direction = "east" if direction_vector.x > 0 else "west"
	else:
		# Mouvement principalement vertical
		current_direction = "south" if direction_vector.y > 0 else "north"

func play_animation():
	"""Joue l'animation appropriée selon l'état et la direction"""
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
		
	var animation_name = current_state + "_" + current_direction
	
	# Vérifier si l'animation existe avant de la jouer
	if animated_sprite.sprite_frames.has_animation(animation_name):
		# Ne changer l'animation que si elle est différente
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)
	else:
		# Fallback vers idle si l'animation n'existe pas
		var fallback_name = "idle_" + current_direction
		if animated_sprite.sprite_frames.has_animation(fallback_name):
			if animated_sprite.animation != fallback_name:
				animated_sprite.play(fallback_name)
