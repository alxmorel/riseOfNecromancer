extends CharacterBody2D

@export var max_health: int = 100
@export var speed: float = 200.0
@export var skeleton_scene: PackedScene = preload("res://scenes/skeleton.tscn")
@export var summon_cooldown: float = 2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar_rect = $HealthBar/HealthBarRect
@onready var necro_bar_rect = $NecroBar/NecroBarRect

var is_summoning: bool = false
var current_health: int = max_health
var last_summon_time: float = 0.0
var current_direction: int = 0
var current_state: String = "idle"  # "idle", "walk", "attack"
var directions = ["south", "south_east", "east", "north_east", 
				  "north", "north_west", "west", "south_west"]

func _ready():
	add_to_group("players")
	# Définir l'animation idle par défaut
	animated_sprite.play("idle_south")
	update_health_bar()

func _unhandled_input(event):
	if event.is_action_pressed("sort1"):
		summon_skeleton()
	elif event.is_action_pressed("sort2"):
		merge_skeletons()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			summon_skeleton_at_mouse_position()

func _physics_process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		summon_skeleton_at_mouse_position()
		
	# Récupérer l'input du joueur
	var input_vector = Vector2.ZERO
	
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	if Input.is_key_pressed(KEY_Q):  # Q = gauche
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):  # D = droite
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_Z):  # Z = haut
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S):  # S = bas
		input_vector.y += 1.0
	
	# Vérifier si le joueur attaque (vous pouvez ajouter votre logique d'attaque ici)
	var is_attacking = false  # À remplacer par votre logique d'attaque
	
	# Normaliser pour un mouvement uniforme en diagonale
	if input_vector.length() > 0 and not is_attacking:
		input_vector = input_vector.normalized()
		velocity = input_vector * speed
		
		# Déterminer la direction basée sur l'input
		update_direction(input_vector)
		
		# Mettre à jour l'état
		current_state = "walk"
		
		# Jouer l'animation de marche
		animated_sprite.play("walk_" + directions[current_direction])
	elif is_attacking:
		# État d'attaque
		velocity = Vector2.ZERO
		current_state = "attack"
		animated_sprite.play("attack_" + directions[current_direction])
	else:
		# Pas de mouvement, jouer l'animation idle
		velocity = Vector2.ZERO
		current_state = "idle"
		animated_sprite.play("idle_" + directions[current_direction])
	
	# Appliquer le mouvement
	move_and_slide()

func summon_skeleton():
	"""Invoque un nouveau skeleton devant le joueur dans sa direction"""
	# Vérifier le cooldown et éviter les doubles invocations
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_summon_time < summon_cooldown or is_summoning:
		return
	
	is_summoning = true
	
	if not skeleton_scene:
		print("Erreur: Scène skeleton non chargée")
		is_summoning = false
		return
	
	var skeleton_instance = skeleton_scene.instantiate()
	if not skeleton_instance:
		print("Erreur: Impossible d'instancier le skeleton")
		is_summoning = false
		return
	
	var scene_root = get_tree().current_scene
	if not scene_root:
		print("Erreur: Scène actuelle non trouvée")
		is_summoning = false
		return
	
	var follow_distance = skeleton_instance.get("follow_distance")
	if follow_distance == null:
		follow_distance = 30.0
	
	var player_direction = get_direction_vector()
	
	# Ajouter un petit offset aléatoire pour éviter que plusieurs skeletons spawnent au même endroit
	var random_offset = Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
	var spawn_position = global_position + player_direction * follow_distance + random_offset
	
	# Vérifier qu'il n'y a pas déjà un skeleton à cette position
	var existing_skeletons = get_tree().get_nodes_in_group("skeletons")
	var min_distance = 10.0  # Distance minimale entre skeletons au spawn
	var valid_position = false
	var attempts = 0
	var max_attempts = 10
	
	while not valid_position and attempts < max_attempts:
		valid_position = true
		for skeleton in existing_skeletons:
			if is_instance_valid(skeleton):
				var dist = spawn_position.distance_to(skeleton.global_position)
				if dist < min_distance:
					# Position trop proche, générer un nouvel offset
					random_offset = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
					spawn_position = global_position + player_direction * follow_distance + random_offset
					valid_position = false
					attempts += 1
					break
		
		if valid_position:
			break
	
	scene_root.add_child(skeleton_instance)
	skeleton_instance.global_position = spawn_position
	
	await get_tree().process_frame
	
	last_summon_time = current_time
	is_summoning = false
	
	
func summon_skeleton_at_mouse_position():
	"""Invoque un skeleton à la position de la souris (dans la limite de follow_distance)"""
	# Vérifier le cooldown et éviter les doubles invocations
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_summon_time < summon_cooldown or is_summoning:
		return
	
	is_summoning = true
	
	if not skeleton_scene:
		print("Erreur: Scène skeleton non chargée")
		is_summoning = false
		return
	
	var skeleton_instance = skeleton_scene.instantiate()
	if not skeleton_instance:
		print("Erreur: Impossible d'instancier le skeleton")
		is_summoning = false
		return
	
	var scene_root = get_tree().current_scene
	if not scene_root:
		print("Erreur: Scène actuelle non trouvée")
		is_summoning = false
		return
	
	var follow_distance = skeleton_instance.get("follow_distance")
	if follow_distance == null:
		follow_distance = 30.0
	
	# Obtenir la position de la souris dans le monde
	var mouse_position = get_global_mouse_position()
	
	# Calculer la direction du joueur vers la souris
	var direction_to_mouse = (mouse_position - global_position).normalized()
	
	# Calculer la position de spawn à follow_distance du joueur dans la direction de la souris
	# Ajouter un petit offset aléatoire pour éviter les collisions
	var random_offset = Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
	var spawn_position = global_position + direction_to_mouse * follow_distance + random_offset
	
	# Vérifier qu'il n'y a pas déjà un skeleton à cette position
	var existing_skeletons = get_tree().get_nodes_in_group("skeletons")
	var min_distance = 10.0  # Distance minimale entre skeletons au spawn
	var valid_position = false
	var attempts = 0
	var max_attempts = 10
	
	while not valid_position and attempts < max_attempts:
		valid_position = true
		for skeleton in existing_skeletons:
			if is_instance_valid(skeleton):
				var dist = spawn_position.distance_to(skeleton.global_position)
				if dist < min_distance:
					# Position trop proche, générer un nouvel offset
					random_offset = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
					spawn_position = global_position + direction_to_mouse * follow_distance + random_offset
					valid_position = false
					attempts += 1
					break
		
		if valid_position:
			break
	
	scene_root.add_child(skeleton_instance)
	skeleton_instance.global_position = spawn_position
	
	await get_tree().process_frame
	
	last_summon_time = current_time
	is_summoning = false
	
	
func merge_skeletons():
	"""Fusionne les skeletons par paires de 2, uniquement ceux du même niveau de merge"""
	if not skeleton_scene:
		print("Erreur: Scène skeleton non chargée")
		return
	
	# Récupérer tous les skeletons dans la scène
	var skeletons = get_tree().get_nodes_in_group("skeletons")
	var valid_skeletons = []
	
	# Filtrer les skeletons valides
	for skeleton in skeletons:
		if is_instance_valid(skeleton):
			valid_skeletons.append(skeleton)
	
	# Il faut au moins 2 skeletons pour fusionner
	if valid_skeletons.size() < 2:
		print("Pas assez de skeletons pour fusionner (minimum 2 requis)")
		return
	
	# Grouper les skeletons par niveau de merge
	var skeletons_by_level = {}
	for skeleton in valid_skeletons:
		var level = skeleton.get("merge_level")
		if level == null:
			level = 0  # Par défaut niveau 0
		
		if not skeletons_by_level.has(level):
			skeletons_by_level[level] = []
		skeletons_by_level[level].append(skeleton)
	
	# Fusionner les skeletons niveau par niveau
	var total_merged = 0
	for level in skeletons_by_level.keys():
		var skeletons_at_level = skeletons_by_level[level]
		
		# Il faut au moins 2 skeletons de ce niveau pour fusionner
		if skeletons_at_level.size() < 2:
			continue
		
		# Grouper par paires (prendre les 2 premiers, puis les 2 suivants, etc.)
		var pairs_to_merge = []
		for i in range(0, skeletons_at_level.size(), 2):
			if i + 1 < skeletons_at_level.size():
				# Paire complète du même niveau
				pairs_to_merge.append([skeletons_at_level[i], skeletons_at_level[i + 1]])
		
		# Fusionner chaque paire de ce niveau
		for pair in pairs_to_merge:
			var skeleton1 = pair[0]
			var skeleton2 = pair[1]
			
			# Vérifier que les deux ont bien le même niveau (sécurité supplémentaire)
			var level1 = skeleton1.get("merge_level")
			var level2 = skeleton2.get("merge_level")
			if level1 == null:
				level1 = 0
			if level2 == null:
				level2 = 0
			
			if level1 != level2:
				print("Erreur: Les skeletons n'ont pas le même niveau de merge")
				continue
			
			# Calculer la position moyenne entre les 2 skeletons
			var merge_position = (skeleton1.global_position + skeleton2.global_position) / 2.0
			
			# Créer le nouveau skeleton mergé
			var merged_skeleton = skeleton_scene.instantiate()
			if not merged_skeleton:
				continue
			
			# Multiplier les stats par 2
			merged_skeleton.max_health = skeleton1.max_health * 2
			merged_skeleton.speed = skeleton1.speed
			merged_skeleton.follow_distance = skeleton1.follow_distance
			merged_skeleton.distance_tolerance = skeleton1.distance_tolerance
			merged_skeleton.attack_range = skeleton1.attack_range
			merged_skeleton.damage = skeleton1.damage * 2
			merged_skeleton.attack_cooldown = skeleton1.attack_cooldown
			merged_skeleton.attack_duration = skeleton1.attack_duration
			merged_skeleton.enemy_detection_range = skeleton1.enemy_detection_range
			merged_skeleton.max_necro_energy = skeleton1.max_necro_energy * 2.0
			
			# Initialiser la santé et l'énergie noire
			merged_skeleton.current_health = merged_skeleton.max_health
			merged_skeleton.current_necro_energy = merged_skeleton.max_necro_energy  # Reset à max
			
			# Doubler la taille (scale x2)
			merged_skeleton.scale = skeleton1.scale * 2.0
			
			# Incrémenter le niveau de merge
			merged_skeleton.merge_level = level1 + 1
			
			# Ajouter à la scène
			var scene_root = get_tree().current_scene
			if scene_root:
				scene_root.add_child(merged_skeleton)
				merged_skeleton.global_position = merge_position
				
				# Mettre à jour les barres après l'ajout
				await get_tree().process_frame
				merged_skeleton.update_health_bar()
				merged_skeleton.update_necro_bar()
			
			# Supprimer les 2 skeletons originaux
			skeleton1.queue_free()
			skeleton2.queue_free()
			total_merged += 1
	
	if total_merged > 0:
		print("Fusion de ", total_merged, " paire(s) de skeletons effectuée")
	else:
		print("Aucune fusion possible : pas assez de skeletons du même niveau")
		
		
func get_direction_vector() -> Vector2:
	"""
	Retourne le vecteur de direction normalisé basé sur current_direction
	"""
	match current_direction:
		0: return Vector2(0, 1)      # south
		1: return Vector2(1, 1).normalized()   # south_east
		2: return Vector2(1, 0)      # east
		3: return Vector2(1, -1).normalized()  # north_east
		4: return Vector2(0, -1)    # north
		5: return Vector2(-1, -1).normalized() # north_west
		6: return Vector2(-1, 0)     # west
		7: return Vector2(-1, 1).normalized()    # south_west
		_: return Vector2(0, 1)

func get_position_behind(distance: float = 50.0) -> Vector2:
	"""
	Calcule la position derrière le joueur selon sa direction actuelle
	"""
	var direction = get_direction_vector()
	# Inverser la direction pour obtenir "derrière"
	var behind_direction = -direction
	return global_position + (behind_direction * distance)

func get_cardinal_direction() -> String:
	"""
	Convertit les 8 directions en 4 directions cardinales
	Retourne: "north", "south", "east", "west"
	"""
	match current_direction:
		0: return "south"      # south
		1: return "south"      # south_east -> south
		2: return "east"       # east
		3: return "north"      # north_east -> north
		4: return "north"      # north
		5: return "north"      # north_west -> north
		6: return "west"       # west
		7: return "south"      # south_west -> south
		_: return "south"

func update_direction(input_vector: Vector2):
	"""
	Convertit un vecteur de direction en index de direction (0-7)
	Méthode basée sur les composantes X et Y plutôt que sur l'angle
	"""
	# Déterminer la direction principale (cardinale)
	var primary_x = 0
	var primary_y = 0
	
	if abs(input_vector.x) > abs(input_vector.y):
		# Mouvement principalement horizontal
		primary_x = sign(input_vector.x)
		primary_y = 0
	else:
		# Mouvement principalement vertical
		primary_x = 0
		primary_y = sign(input_vector.y)
	
	# Si les deux composantes sont significatives, c'est une diagonale
	if abs(input_vector.x) > 0.3 and abs(input_vector.y) > 0.3:
		primary_x = sign(input_vector.x)
		primary_y = sign(input_vector.y)
	
	# Mapper les composantes à l'index de direction
	# directions = ["south", "south_east", "east", "north_east", 
	#               "north", "north_west", "west", "south_west"]
	# Index:        0         1           2        3
	#               4         5           6        7
	
	if primary_y > 0:  # Sud
		if primary_x > 0:      # Sud-Est
			current_direction = 1
		elif primary_x < 0:     # Sud-Ouest
			current_direction = 7
		else:                  # Sud
			current_direction = 0
	elif primary_y < 0:  # Nord
		if primary_x > 0:      # Nord-Est
			current_direction = 3
		elif primary_x < 0:     # Nord-Ouest
			current_direction = 5
		else:                  # Nord
			current_direction = 4
	else:  # Horizontal uniquement
		if primary_x > 0:      # Est
			current_direction = 2
		else:                  # Ouest
			current_direction = 6

func update_health_bar():
	"""Met à jour l'affichage de la barre de vie"""
	if health_bar_rect:
		var health_percentage = float(current_health) / float(max_health)
		health_bar_rect.size.x = health_bar_rect.get_parent().size.x * health_percentage

func take_damage(amount: int):
	"""Inflige des dégâts au joueur"""
	current_health -= amount
	print("Joueur prend ", amount, " dégâts. Santé: ", current_health, "/", max_health)
	
	update_health_bar()
	
	if current_health <= 0:
		die()

func die():
	"""Détruit le joueur (game over)"""
	print("Joueur détruit! Game Over")
	queue_free()
