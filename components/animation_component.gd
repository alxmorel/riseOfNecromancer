extends Node
class_name AnimationComponent

## Composant de gestion des animations
## Gère le choix et la lecture des animations basées sur l'état et la direction

signal animation_changed(animation_name: String)

@export var animated_sprite_path: NodePath = NodePath("../AnimatedSprite2D")
@export var use_8_directions: bool = false  # true pour 8 directions (joueur), false pour 4 (skeleton/enemy)

var animated_sprite: AnimatedSprite2D = null
var current_state: String = "idle"
var current_direction: String = "south"
var current_animation: String = ""

# Mapping 8 directions vers 4 directions cardinales
var direction_8_to_4 = {
	"south": "south",
	"south_east": "east",
	"east": "east",
	"north_east": "north",
	"north": "north",
	"north_west": "west",
	"west": "west",
	"south_west": "south"
}

func _ready():
	# Obtenir le sprite animé
	animated_sprite = get_node_or_null(animated_sprite_path)
	if not animated_sprite:
		push_error("AnimationComponent: AnimatedSprite2D non trouvé au chemin: " + str(animated_sprite_path))

func set_state(state: String) -> void:
	"""Définit l'état actuel (idle, walk, attack, etc.)"""
	if state != current_state:
		current_state = state
		_update_animation()

func set_direction_from_vector(direction_vector: Vector2) -> void:
	"""Définit la direction basée sur un vecteur"""
	if direction_vector.length() < 0.1:
		return
	
	if use_8_directions:
		_update_8_direction(direction_vector)
	else:
		_update_4_direction(direction_vector)
	
	_update_animation()

func set_direction(direction: String) -> void:
	"""Définit directement la direction par son nom"""
	if direction != current_direction:
		current_direction = direction
		_update_animation()

func get_cardinal_direction() -> String:
	"""Retourne la direction cardinale (4 directions)"""
	if use_8_directions:
		return direction_8_to_4.get(current_direction, "south")
	return current_direction

func _update_4_direction(direction_vector: Vector2) -> void:
	"""Met à jour la direction pour un système à 4 directions"""
	var new_direction: String
	
	if abs(direction_vector.x) > abs(direction_vector.y):
		# Mouvement principalement horizontal
		new_direction = "east" if direction_vector.x > 0 else "west"
	else:
		# Mouvement principalement vertical
		new_direction = "south" if direction_vector.y > 0 else "north"
	
	if new_direction != current_direction:
		current_direction = new_direction

func _update_8_direction(direction_vector: Vector2) -> void:
	"""Met à jour la direction pour un système à 8 directions"""
	var angle = direction_vector.angle()
	var degrees = rad_to_deg(angle)
	
	# Normaliser l'angle entre 0 et 360
	if degrees < 0:
		degrees += 360
	
	# Déterminer la direction selon l'angle
	# 0° = Est, 90° = Sud, 180° = Ouest, 270° = Nord
	var new_direction: String
	
	if degrees >= 337.5 or degrees < 22.5:
		new_direction = "east"
	elif degrees >= 22.5 and degrees < 67.5:
		new_direction = "south_east"
	elif degrees >= 67.5 and degrees < 112.5:
		new_direction = "south"
	elif degrees >= 112.5 and degrees < 157.5:
		new_direction = "south_west"
	elif degrees >= 157.5 and degrees < 202.5:
		new_direction = "west"
	elif degrees >= 202.5 and degrees < 247.5:
		new_direction = "north_west"
	elif degrees >= 247.5 and degrees < 292.5:
		new_direction = "north"
	else:  # 292.5 to 337.5
		new_direction = "north_east"
	
	if new_direction != current_direction:
		current_direction = new_direction

func _update_animation() -> void:
	"""Met à jour l'animation en fonction de l'état et de la direction"""
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	var animation_name = current_state + "_" + current_direction
	
	# Vérifier si l'animation existe
	if animated_sprite.sprite_frames.has_animation(animation_name):
		_play_animation(animation_name)
	else:
		# Fallback vers idle si l'animation n'existe pas
		var fallback_name = "idle_" + current_direction
		if animated_sprite.sprite_frames.has_animation(fallback_name):
			_play_animation(fallback_name)

func _play_animation(animation_name: String) -> void:
	"""Joue une animation si elle est différente de celle en cours"""
	if animated_sprite and animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
		current_animation = animation_name
		animation_changed.emit(animation_name)

func play(state: String, direction: String = "") -> void:
	"""Joue directement une animation avec état et direction optionnelle"""
	current_state = state
	if direction != "":
		current_direction = direction
	_update_animation()

func get_current_animation() -> String:
	"""Retourne le nom de l'animation actuelle"""
	return current_animation

func get_current_direction() -> String:
	"""Retourne la direction actuelle"""
	return current_direction

func get_current_state() -> String:
	"""Retourne l'état actuel"""
	return current_state
