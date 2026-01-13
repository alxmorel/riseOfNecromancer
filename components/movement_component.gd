extends Node
class_name MovementComponent

## Composant de gestion du mouvement
## Gère le déplacement, la vélocité et les collisions

signal movement_started()
signal movement_stopped()
signal collision_detected(collision: KinematicCollision2D)

@export var speed: float = 200.0
@export var enable_collision_avoidance: bool = true

var entity: CharacterBody2D = null
var current_velocity: Vector2 = Vector2.ZERO

func _ready():
	# Obtenir l'entité parente
	entity = get_parent() as CharacterBody2D
	if not entity:
		push_error("MovementComponent doit être enfant d'un CharacterBody2D")

func move_towards(target_position: Vector2, delta: float = 1.0) -> void:
	"""Déplace l'entité vers une position cible"""
	if not entity:
		return
	
	var direction = (target_position - entity.global_position)
	var distance = direction.length()
	
	if distance > 0.001:
		direction = CollisionHelper.safe_normalize(direction)
		if direction == Vector2.ZERO:
			stop()
			return
		
		set_velocity(direction * speed)
	else:
		stop()

func move_in_direction(direction: Vector2) -> void:
	"""Déplace l'entité dans une direction donnée"""
	if not entity:
		return
	
	var normalized_direction = CollisionHelper.safe_normalize(direction)
	if normalized_direction != Vector2.ZERO:
		set_velocity(normalized_direction * speed)
	else:
		stop()

func set_velocity(new_velocity: Vector2) -> void:
	"""Définit la vélocité de l'entité"""
	if not entity:
		return
	
	var was_moving = current_velocity.length() > 0.1
	current_velocity = new_velocity
	entity.velocity = new_velocity
	
	var is_moving = current_velocity.length() > 0.1
	
	if not was_moving and is_moving:
		movement_started.emit()
	elif was_moving and not is_moving:
		movement_stopped.emit()

func stop() -> void:
	"""Arrête le mouvement"""
	set_velocity(Vector2.ZERO)

func apply_movement() -> bool:
	"""Applique le mouvement et retourne true si une collision est détectée"""
	if not entity:
		return false
	
	entity.move_and_slide()
	
	if entity.get_slide_collision_count() > 0:
		var collision = entity.get_slide_collision(0)
		collision_detected.emit(collision)
		
		if enable_collision_avoidance:
			_handle_collision(collision)
		
		return true
	
	return false

func _handle_collision(collision: KinematicCollision2D) -> void:
	"""Gère les collisions avec évitement automatique"""
	if not collision or not entity:
		return
	
	var normal = collision.get_normal()
	
	# Essayer de glisser le long du mur
	var slide_direction = entity.velocity.slide(normal).normalized()
	if slide_direction.length() > 0.1:
		entity.velocity = slide_direction * speed
		current_velocity = entity.velocity

func get_velocity() -> Vector2:
	"""Retourne la vélocité actuelle"""
	return current_velocity

func is_moving() -> bool:
	"""Vérifie si l'entité est en mouvement"""
	return current_velocity.length() > 0.1

func get_direction() -> Vector2:
	"""Retourne la direction normalisée du mouvement"""
	if is_moving():
		return current_velocity.normalized()
	return Vector2.ZERO
