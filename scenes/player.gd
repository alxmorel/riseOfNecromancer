extends CharacterBody2D

# Vitesse de déplacement
@export var speed: float = 200.0

# Référence au AnimatedSprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var skeleton_scene: PackedScene = preload("res://scenes/skeleton.tscn")

@export var summon_cooldown: float = 0.5
var last_summon_time: float = 0.0

# Direction actuelle (0-7 pour les 8 directions)
var current_direction: int = 0

var current_state: String = "idle"  # "idle", "walk", "attack"

# Noms des directions dans l'ordre
var directions = ["south", "south_east", "east", "north_east", 
				  "north", "north_west", "west", "south_west"]

func _ready():
	add_to_group("players")
	# Définir l'animation idle par défaut
	animated_sprite.play("idle_south")


func _unhandled_input(event):
	if event.is_action_pressed("sort1"):
		summon_skeleton()


func _physics_process(delta):
	# Récupérer l'input du joueur
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
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
	"""Invoque un nouveau skeleton derrière le joueur"""
	# Vérifier le cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_summon_time < summon_cooldown:
		return
	
	# Vérifier que la scène est chargée
	if not skeleton_scene:
		print("Erreur: Scène skeleton non chargée")
		return
	
	# Instancier le skeleton
	var skeleton_instance = skeleton_scene.instantiate()
	if not skeleton_instance:
		print("Erreur: Impossible d'instancier le skeleton")
		return
	
	# Obtenir la scène actuelle (parent)
	var scene_root = get_tree().current_scene
	if not scene_root:
		print("Erreur: Scène actuelle non trouvée")
		return
	
	# Calculer la position derrière le joueur
	var spawn_position = get_position_behind(60.0)  # 60 pixels derrière
	
	# Positionner le skeleton
	skeleton_instance.global_position = spawn_position
	
	# Ajouter le skeleton à la scène
	scene_root.add_child(skeleton_instance)
	
	# Mettre à jour le temps du dernier summon
	last_summon_time = current_time
	
	print("Skeleton invoqué à la position: ", spawn_position)
	

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
