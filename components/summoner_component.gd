extends Node
class_name SummonerComponent

## Composant d'invocation
## Gère l'invocation d'entités (skeletons, etc.) avec cooldown et validation de position

signal summon_started()
signal summon_completed(summoned_entity: Node)
signal summon_failed(reason: String)

@export var summon_scene: PackedScene = null
@export var summon_cooldown: float = 0.5
@export var spawn_distance: float = 30.0
@export var min_spawn_distance_between_entities: float = 10.0
@export var max_spawn_attempts: int = 10
@export var summoned_group: String = "summoned"  # Groupe pour les entités invoquées

var summoner: Node2D = null
var is_summoning: bool = false
var last_summon_time: float = 0.0

func _ready():
	summoner = get_parent() as Node2D
	if not summoner:
		push_error("SummonerComponent doit être enfant d'un Node2D")

func can_summon() -> bool:
	"""Vérifie si on peut invoquer (cooldown respecté)"""
	if is_summoning:
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_summon_time >= summon_cooldown

func summon_at_direction(direction: Vector2) -> Node:
	"""Invoque une entité dans une direction donnée"""
	if not can_summon():
		return null
	
	var spawn_position = summoner.global_position + direction.normalized() * spawn_distance
	return _perform_summon(spawn_position)

func summon_at_position(target_position: Vector2) -> Node:
	"""Invoque une entité à une position spécifique (limitée par spawn_distance)"""
	if not can_summon():
		return null
	
	# Calculer la direction vers la position cible
	var direction = (target_position - summoner.global_position).normalized()
	var spawn_position = summoner.global_position + direction * spawn_distance
	
	return _perform_summon(spawn_position)

func merge_summoned(merge_function: Callable):
	"""
	Fusionne les entités invoquées en utilisant une fonction de fusion personnalisée
	Retourne le nombre de fusions effectuées (via await)
	"""
	if not summon_scene:
		summon_failed.emit("Scène d'invocation non définie")
		return 0
	
	# Récupérer toutes les entités invoquées
	var summoned_entities = get_tree().get_nodes_in_group(summoned_group)
	var valid_entities = []
	
	for entity in summoned_entities:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion():
			valid_entities.append(entity)
	
	if valid_entities.size() < 2:
		summon_failed.emit("Pas assez d'entités pour fusionner (minimum 2 requis)")
		return 0
	
	# Appeler la fonction de fusion personnalisée (peut être async)
	return await merge_function.call(valid_entities, summon_scene)

func _perform_summon(desired_position: Vector2) -> Node:
	"""Effectue l'invocation avec validation de position"""
	if not summon_scene:
		summon_failed.emit("Scène d'invocation non définie")
		return null
	
	is_summoning = true
	summon_started.emit()
	
	# Créer l'instance
	var instance = summon_scene.instantiate()
	if not instance:
		is_summoning = false
		summon_failed.emit("Impossible d'instancier la scène")
		return null
	
	# Trouver une position valide
	var spawn_position = _find_valid_spawn_position(desired_position)
	if spawn_position == Vector2.ZERO:
		instance.queue_free()
		is_summoning = false
		summon_failed.emit("Aucune position valide trouvée")
		return null
	
	# Ajouter à la scène
	var scene_root = get_tree().current_scene
	if not scene_root:
		instance.queue_free()
		is_summoning = false
		summon_failed.emit("Scène actuelle non trouvée")
		return null
	
	scene_root.add_child(instance)
	
	# Positionner l'entité
	if instance is Node2D:
		instance.global_position = spawn_position
	
	# Mettre à jour les temps
	last_summon_time = Time.get_ticks_msec() / 1000.0
	is_summoning = false
	
	summon_completed.emit(instance)
	return instance

func _find_valid_spawn_position(desired_position: Vector2) -> Vector2:
	"""Trouve une position valide pour le spawn, en évitant les collisions"""
	var existing_entities = get_tree().get_nodes_in_group(summoned_group)
	var attempts = 0
	
	while attempts < max_spawn_attempts:
		var is_valid = true
		
		# Vérifier qu'il n'y a pas d'entité trop proche
		for entity in existing_entities:
			if not is_instance_valid(entity):
				continue
			
			var entity_node = entity as Node2D
			if not entity_node:
				continue
			
			var distance = desired_position.distance_to(entity_node.global_position)
			if distance < min_spawn_distance_between_entities:
				# Position trop proche, générer un nouvel offset aléatoire
				var random_offset = Vector2(
					randf_range(-10.0, 10.0),
					randf_range(-10.0, 10.0)
				)
				desired_position += random_offset
				is_valid = false
				attempts += 1
				break
		
		if is_valid:
			return desired_position
	
	# Aucune position valide trouvée après max_attempts
	return Vector2.ZERO

func get_summoned_count() -> int:
	"""Retourne le nombre d'entités invoquées actuellement actives"""
	var entities = get_tree().get_nodes_in_group(summoned_group)
	var count = 0
	
	for entity in entities:
		if is_instance_valid(entity):
			count += 1
	
	return count

func get_summoned_entities() -> Array:
	"""Retourne la liste des entités invoquées valides"""
	var entities = get_tree().get_nodes_in_group(summoned_group)
	var valid_entities = []
	
	for entity in entities:
		if is_instance_valid(entity):
			valid_entities.append(entity)
	
	return valid_entities

func get_cooldown_remaining() -> float:
	"""Retourne le temps restant avant de pouvoir invoquer à nouveau"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last = current_time - last_summon_time
	return max(0.0, summon_cooldown - time_since_last)
