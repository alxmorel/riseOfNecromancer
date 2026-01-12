extends CharacterBody2D

@export var max_health: int = 60
var current_health: int = max_health

# Vitesse de déplacement
@export var speed: float = 150.0

# Distance d'attaque (portée de mêlée)
@export var attack_range: float = 30.0

# Dégâts infligés
@export var damage: int = 10

# Cooldown entre les attaques (en secondes)
@export var attack_cooldown: float = 1.5
var last_attack_time: float = 0.0

# Durée de l'animation d'attaque (en secondes)
@export var attack_duration: float = 0.6
var attack_timer: float = 0.0
var is_attacking: bool = false

# Portée de détection (distance à laquelle l'ennemi détecte les cibles)
@export var detection_range: float = 300.0

# Référence au AnimatedSprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Cible actuelle (skeleton ou joueur)
var target: CharacterBody2D = null

# Direction actuelle (4 directions: north, south, east, west)
var current_direction: String = "south"

# État actuel
var current_state: String = "idle"  # "idle", "walk", "attack"

# Timer pour recalculer la cible périodiquement
var target_update_timer: float = 0.0
var target_update_interval: float = 0.5  # Mettre à jour la cible toutes les 0.5 secondes

func take_damage(amount: int):
	"""Inflige des dégâts à l'ennemi"""
	current_health -= amount
	print("Ennemi prend ", amount, " dégâts. Santé: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func die():
	"""Détruit l'ennemi"""
	print("Ennemi détruit!")
	queue_free()
	
	
func _ready():
	add_to_group("enemies")
	# Définir l'animation idle par défaut
	if animated_sprite:
		animated_sprite.play("idle_south")

func _physics_process(delta):
	# Gérer le timer d'attaque
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			current_state = "idle"
	
	# Mettre à jour le timer de recherche de cible
	target_update_timer += delta
	if target_update_timer >= target_update_interval:
		find_target()
		target_update_timer = 0.0
	
	# Si pas de cible, rester en idle
	if target == null:
		if not is_attacking:
			current_state = "idle"
		velocity = Vector2.ZERO
		play_animation()
		return
	
	# Vérifier si la cible est toujours valide (pas détruite)
	if not is_instance_valid(target):
		target = null
		return
	
	# Si on est en train d'attaquer, ne pas bouger
	if is_attacking:
		velocity = Vector2.ZERO
		play_animation()
		move_and_slide()
		return
	
	# Calculer la distance à la cible
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Vérifier si on est à portée d'attaque
	if distance_to_target <= attack_range:
		# Attaquer la cible
		try_attack()
	else:
		# Se déplacer vers la cible
		move_towards_target(delta)
	
	# Appliquer le mouvement
	move_and_slide()
	
	# Jouer l'animation appropriée
	play_animation()

func find_target():
	"""
	Trouve une cible selon la priorité :
	1. Acolytes (skeletons) en priorité
	2. Joueur si aucun acolyte
	"""
	var skeletons = get_tree().get_nodes_in_group("skeletons")
	var players = get_tree().get_nodes_in_group("players")
	
	# Filtrer les skeletons valides et à portée
	var valid_skeletons = []
	for skeleton in skeletons:
		if is_instance_valid(skeleton):
			var distance = global_position.distance_to(skeleton.global_position)
			if distance <= detection_range:
				valid_skeletons.append(skeleton)
	
	# Priorité 1 : Attaquer les acolytes (skeletons) s'il y en a
	if valid_skeletons.size() > 0:
		# Trouver le skeleton le plus proche
		var closest_skeleton = null
		var closest_distance = INF
		
		for skeleton in valid_skeletons:
			var distance = global_position.distance_to(skeleton.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_skeleton = skeleton
		
		target = closest_skeleton
		return
	
	# Priorité 2 : Attaquer le joueur s'il n'y a plus d'acolytes
	if players.size() > 0:
		var player = players[0]
		if is_instance_valid(player):
			var distance = global_position.distance_to(player.global_position)
			if distance <= detection_range:
				target = player
				return
	
	# Pas de cible trouvée
	target = null

func move_towards_target(delta):
	"""Se déplace vers la cible"""
	if target == null or not is_instance_valid(target):
		return
	
	# Calculer la direction vers la cible
	var direction = (target.global_position - global_position).normalized()
	
	# Appliquer la vitesse
	velocity = direction * speed
	
	# Mettre à jour la direction pour l'animation
	update_direction(direction)
	
	# Mettre à jour l'état
	current_state = "walk"

func try_attack():
	"""Tente d'attaquer la cible si le cooldown est terminé"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_attack_time >= attack_cooldown:
		# Attaquer
		attack_target()
		last_attack_time = current_time
		is_attacking = true
		attack_timer = attack_duration
		current_state = "attack"
	else:
		# En cooldown, s'arrêter et regarder la cible
		velocity = Vector2.ZERO
		if not is_attacking:
			current_state = "idle"
		# Mettre à jour la direction vers la cible
		if target:
			var direction = (target.global_position - global_position).normalized()
			update_direction(direction)

func attack_target():
	"""Attaque la cible actuelle"""
	if target == null or not is_instance_valid(target):
		return
	
	# Calculer la direction vers la cible pour l'animation
	var direction = (target.global_position - global_position).normalized()
	update_direction(direction)
	
	# Infliger des dégâts à la cible
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	# S'arrêter pendant l'attaque
	velocity = Vector2.ZERO
	
	print("Ennemi attaque ", target.name, " pour ", damage, " dégâts")

func update_direction(direction_vector: Vector2):
	"""
	Convertit un vecteur de direction en direction cardinale (4 directions)
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
