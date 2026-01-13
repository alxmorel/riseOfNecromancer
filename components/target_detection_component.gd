extends Node
class_name TargetDetectionComponent

## Composant de détection de cibles
## Gère la recherche et le suivi de cibles selon des priorités configurables

signal target_acquired(target: Node2D)
signal target_lost()

@export var detection_range: float = 300.0
@export var update_interval: float = 0.5  # Fréquence de mise à jour en secondes
@export var target_groups: Array[String] = []  # Groupes de cibles par ordre de priorité
@export var auto_update: bool = true  # Mise à jour automatique dans _process

var entity: Node2D = null
var current_target: Node2D = null
var update_timer: float = 0.0

func _ready():
	entity = get_parent() as Node2D
	if not entity:
		push_error("TargetDetectionComponent doit être enfant d'un Node2D")

func _process(delta):
	if not auto_update:
		return
	
	update_timer += delta
	if update_timer >= update_interval:
		update_target()
		update_timer = 0.0

func update_target() -> void:
	"""Met à jour la cible actuelle"""
	var previous_target = current_target
	current_target = find_best_target()
	
	# Émettre les signaux appropriés
	if current_target != previous_target:
		if current_target != null:
			target_acquired.emit(current_target)
		elif previous_target != null:
			target_lost.emit()

func find_best_target() -> Node2D:
	"""Trouve la meilleure cible selon les priorités configurées"""
	if not entity:
		return null
	
	# Parcourir les groupes par ordre de priorité
	for group_name in target_groups:
		var target = _find_closest_in_group(group_name)
		if target != null:
			return target
	
	return null

func _find_closest_in_group(group_name: String) -> Node2D:
	"""Trouve la cible la plus proche dans un groupe donné"""
	var nodes = get_tree().get_nodes_in_group(group_name)
	var closest_node: Node2D = null
	var closest_distance = INF
	
	for node in nodes:
		# Vérifier que le nœud est valide et pas en cours de suppression
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		
		if node == entity:  # Ne pas se cibler soi-même
			continue
		
		var node_2d = node as Node2D
		if not node_2d:
			continue
		
		var distance = entity.global_position.distance_to(node_2d.global_position)
		
		if distance <= detection_range and distance < closest_distance:
			closest_distance = distance
			closest_node = node_2d
	
	return closest_node

func get_target() -> Node2D:
	"""Retourne la cible actuelle (peut être null)"""
	# Vérifier que la cible est toujours valide et pas en cours de suppression
	if current_target:
		if not is_instance_valid(current_target) or current_target.is_queued_for_deletion():
			current_target = null
			target_lost.emit()
	
	return current_target

func has_target() -> bool:
	"""Vérifie si une cible valide existe"""
	return get_target() != null

func get_distance_to_target() -> float:
	"""Retourne la distance à la cible actuelle (INF si pas de cible)"""
	if not has_target() or not entity:
		return INF
	
	return entity.global_position.distance_to(current_target.global_position)

func get_direction_to_target() -> Vector2:
	"""Retourne la direction normalisée vers la cible (ZERO si pas de cible)"""
	if not has_target() or not entity:
		return Vector2.ZERO
	
	return (current_target.global_position - entity.global_position).normalized()

func is_target_in_range(range: float) -> bool:
	"""Vérifie si la cible est dans une certaine portée"""
	return get_distance_to_target() <= range

func set_target_groups_by_priority(groups: Array[String]) -> void:
	"""Définit les groupes de cibles par ordre de priorité"""
	target_groups = groups

func clear_target() -> void:
	"""Efface la cible actuelle"""
	if current_target != null:
		current_target = null
		target_lost.emit()

func force_update() -> void:
	"""Force une mise à jour immédiate de la cible"""
	update_target()
