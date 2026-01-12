extends CharacterBody2D

# Vitesse de déplacement
@export var speed: float = 200.0

# Référence au AnimatedSprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Direction actuelle (0-7 pour les 8 directions)
var current_direction: int = 0

# Noms des directions dans l'ordre
var directions = ["south", "south_east", "east", "north_east", 
				  "north", "north_west", "west", "south_west"]

func _ready():
	# Définir l'animation idle par défaut
	animated_sprite.play("idle_south")

func _physics_process(delta):
	# Récupérer l'input du joueur
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	# Normaliser pour un mouvement uniforme en diagonale
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		velocity = input_vector * speed
		
		# Déterminer la direction basée sur l'input
		update_direction(input_vector)
		
		# Jouer l'animation de marche
		animated_sprite.play("walk_" + directions[current_direction])
	else:
		# Pas de mouvement, jouer l'animation idle
		velocity = Vector2.ZERO
		animated_sprite.play("idle_" + directions[current_direction])
	
	# Appliquer le mouvement
	move_and_slide()

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
