extends CharacterBody2D

@export var max_health: int = 40
@export var speed: float = 200.0
@export var follow_distance: float = 30.0
@export var distance_tolerance: float = 10.0
@export var attack_range: float = 15.0
@export var damage: int = 15
@export var attack_cooldown: float = 1.2
@export var attack_duration: float = 0.6
@export var enemy_detection_range: float = 300.0
@export var max_necro_energy: float = 30.0  # Durée de vie en secondes

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar_rect: ColorRect = $HealthBar/HealthBarRect
@onready var necro_bar_rect: ColorRect = $NecroBar/NecroBarRect

var necro_bar_target_width: float = 0.0
var current_health: int = max_health
var last_attack_time: float = 0.0
var attack_timer: float = 0.0
var is_attacking: bool = false
var target: CharacterBody2D = null
var attack_target: CharacterBody2D = null
var current_direction: String = "south"
var current_state: String = "idle"
var preferred_angle: float = 0.0 #angle de suivi du joueur
var current_necro_energy: float = 30.0 
var necro_drain_rate: float = 1.0  # 1 point par seconde
var merge_level: int = 0

func _ready():
	add_to_group("skeletons")
	# Trouver le joueur
	find_target()
	# Définir l'animation idle par défaut
	if animated_sprite:
		animated_sprite.play("idle_south")
		
	update_health_bar()
	update_necro_bar()
	
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
			
	# Gérer la décrémentation de l'énergie noire (de manière fluide)
	current_necro_energy -= necro_drain_rate * delta
	update_necro_bar()
	
	# Vérifier si l'énergie noire est épuisée
	if current_necro_energy <= 0:
		die()
		return
	
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
				# Appliquer le mouvement
		move_and_slide()
		
		# Vérifier si on est bloqué par une collision, calculer la direction de contournement pour le prochain frame
		if get_slide_collision_count() > 0:
			var collision = get_slide_collision(0)
			if collision:
				var normal = collision.get_normal()
				
				# En combat, essayer de contourner pour atteindre l'ennemi
				var direction_to_enemy = (attack_target.global_position - global_position).normalized()
				var perp_vector = Vector2(-normal.y, normal.x)  # Vecteur perpendiculaire
				
				# Choisir la direction qui rapproche le plus de l'ennemi
				var left_direction = (direction_to_enemy + perp_vector).normalized()
				var right_direction = (direction_to_enemy - perp_vector).normalized()
				
				var left_distance = (global_position + left_direction * 20.0).distance_to(attack_target.global_position)
				var right_distance = (global_position + right_direction * 20.0).distance_to(attack_target.global_position)
				
				var best_direction = left_direction if left_distance < right_distance else right_direction
				velocity = best_direction * speed
		
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
	
	# Obtenir la direction du joueur (où il regarde)
	var player_direction: Vector2 = Vector2.ZERO
	if target.has_method("get_direction_vector"):
		player_direction = target.get_direction_vector()
	else:
		# Fallback : utiliser la vélocité du joueur
		player_direction = target.velocity.normalized() if target.velocity.length() > 0.1 else Vector2(0, 1)
	
	# Calculer l'angle de la direction du joueur
	var player_angle = player_direction.angle()
	
	# Calculer l'angle opposé (derrière le joueur)
	var behind_angle = player_angle + PI
	
	# Obtenir tous les skeletons et trouver l'index de celui-ci
	var skeletons = get_tree().get_nodes_in_group("skeletons")
	var skeleton_list = []
	for skeleton in skeletons:
		if is_instance_valid(skeleton):
			skeleton_list.append(skeleton)
	
	# Trier les skeletons par leur instance_id pour avoir un ordre stable
	skeleton_list.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	
	# Trouver l'index de ce skeleton
	var skeleton_index = skeleton_list.find(self)
	var skeleton_count = skeleton_list.size()
	
	# Calculer l'angle préféré sur un demi-arc de cercle derrière le joueur
	# L'arc va de -90° à +90° par rapport à la direction opposée
	var arc_range = PI  # 180 degrés (demi-cercle)
	var start_angle = behind_angle - arc_range / 2  # Commence à -90° de derrière
	
	if skeleton_count > 1:
		# Répartir équitablement sur le demi-arc
		var angle_step = arc_range / (skeleton_count - 1)
		preferred_angle = start_angle + (angle_step * skeleton_index)
	else:
		# Un seul skeleton : directement derrière le joueur
		preferred_angle = behind_angle
	
	# Calculer la position cible sur le demi-arc derrière le joueur
	var target_position: Vector2
	
	# Si on est trop proche ou trop loin, ajuster vers la distance idéale
	if abs(distance_to_player - follow_distance) > distance_tolerance:
		# Calculer la direction actuelle du skeleton par rapport au joueur
		var direction_to_skeleton = (global_position - target.global_position).normalized()
		var current_angle = direction_to_skeleton.angle()
		
		# Utiliser un mélange entre l'angle actuel et l'angle préféré
		var target_angle = lerp_angle(current_angle, preferred_angle, 0.1)
		
		# Calculer la position cible sur le demi-arc
		target_position = target.global_position + Vector2(cos(target_angle), sin(target_angle)) * follow_distance
	else:
		# Si on est à la bonne distance, rester sur le demi-arc mais ajuster légèrement
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
		if distance_to_target > 0.001:  # Éviter la division par zéro
			move_direction = move_direction.normalized()
			velocity = move_direction * speed
			
			# Vérifier que la direction est valide (vérifier les composantes)
			if is_nan(move_direction.x) or is_nan(move_direction.y) or is_inf(move_direction.x) or is_inf(move_direction.y):
				# Direction invalide, utiliser la direction vers le joueur comme fallback
				var direction_to_player = (target.global_position - global_position)
				var dist_to_player = direction_to_player.length()
				if dist_to_player > 0.001:
					direction_to_player = direction_to_player.normalized()
					if not (is_nan(direction_to_player.x) or is_nan(direction_to_player.y)):
						velocity = direction_to_player * speed
					else:
						velocity = Vector2.ZERO
				else:
					velocity = Vector2.ZERO
			
			# Calculer la direction cardinale basée sur le mouvement
			update_direction(move_direction)
		else:
			velocity = Vector2.ZERO
	
	# Synchroniser la direction avec le joueur si possible (seulement si pas de combat)
	if attack_target == null and target.has_method("get_cardinal_direction"):
		current_direction = target.get_cardinal_direction()
	
	# Jouer l'animation appropriée selon l'état
	play_animation()
	
	# Appliquer le mouvement et vérifier les collisions
	move_and_slide()
	
		# Si le skeleton est bloqué par une collision, calculer la direction de contournement pour le prochain frame
	if get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		if collision:
			var normal = collision.get_normal()
			
			# Si on est en train de suivre le joueur (pas en combat)
			if attack_target == null:
				# Calculer une direction de contournement pour le prochain mouvement
				var slide_direction = velocity.slide(normal).normalized()
				if slide_direction.length() > 0.1:
					velocity = slide_direction * speed
			else:
				# En combat, essayer de contourner pour atteindre l'ennemi
				var direction_to_enemy = (attack_target.global_position - global_position).normalized()
				var perp_vector = Vector2(-normal.y, normal.x)  # Vecteur perpendiculaire
				
				# Choisir la direction qui rapproche le plus de l'ennemi
				var left_direction = (direction_to_enemy + perp_vector).normalized()
				var right_direction = (direction_to_enemy - perp_vector).normalized()
				
				var left_distance = (global_position + left_direction * 20.0).distance_to(attack_target.global_position)
				var right_distance = (global_position + right_direction * 20.0).distance_to(attack_target.global_position)
				
				var best_direction = left_direction if left_distance < right_distance else right_direction
				velocity = best_direction * speed

func move_towards_enemy():
	"""Se déplace vers l'ennemi"""
	if attack_target == null or not is_instance_valid(attack_target):
		velocity = Vector2.ZERO
		return
	
	# Calculer la direction vers l'ennemi
	var direction = (attack_target.global_position - global_position)
	var distance = direction.length()
	
	# Vérifier que la direction est valide
	if distance > 0.001:
		direction = direction.normalized()
		
		# Vérifier que les composantes ne sont pas NaN ou Inf
		if is_nan(direction.x) or is_nan(direction.y) or is_inf(direction.x) or is_inf(direction.y):
			velocity = Vector2.ZERO
			return
		
		# Appliquer la vitesse normale
		velocity = direction * speed
		
		# Mettre à jour la direction pour l'animation
		update_direction(direction)
		
		# Mettre à jour l'état
		if not is_attacking:
			current_state = "walk"
	else:
		velocity = Vector2.ZERO
		
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
		
		# Convertir les dégâts en énergie noire (dans la limite du maximum)
		var energy_gain = float(damage)  # 1 point d'énergie par point de dégât
		current_necro_energy = min(current_necro_energy + energy_gain, max_necro_energy)
		update_necro_bar()
	
	# S'arrêter pendant l'attaque
	velocity = Vector2.ZERO
	
	print("Skeleton attaque ", attack_target.name, " pour ", damage, " dégâts")
func take_damage(amount: int):
	"""Inflige des dégâts au skeleton"""
	current_health -= amount
	print("Skeleton prend ", amount, " dégâts. Santé: ", current_health, "/", max_health)
	
	update_health_bar()

	if current_health <= 0:
		die()

func update_health_bar():
	"""Met à jour l'affichage de la barre de vie"""
	if health_bar_rect:
		var health_percentage = float(current_health) / float(max_health)
		health_bar_rect.size.x = health_bar_rect.get_parent().size.x * health_percentage

func update_necro_bar():
	"""Met à jour l'affichage de la barre d'énergie noire"""
	if necro_bar_rect:
		var necro_percentage = current_necro_energy / max_necro_energy
		var parent_width = necro_bar_rect.get_parent().size.x
		necro_bar_target_width = parent_width * necro_percentage
		
		# Lisser la transition de la barre pour éviter les ticks visibles
		necro_bar_rect.size.x = lerp(necro_bar_rect.size.x, necro_bar_target_width, 0.3)

func die():
	"""Détruit le skeleton"""
	print("Skeleton détruit!")
	queue_free()

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
