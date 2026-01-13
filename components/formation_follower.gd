extends Node
class_name FormationFollower

## Composant de suivi en formation
## Permet à des entités de suivre un leader en se positionnant en arc de cercle derrière lui

@export var follow_distance: float = 30.0
@export var distance_tolerance: float = 10.0
@export var angle_lerp_speed: float = 0.1  # Vitesse d'ajustement vers l'angle préféré

var target: Node2D = null
var preferred_angle: float = 0.0

func calculate_formation_position(entity: Node2D, group_name: String) -> Vector2:
	"""Calcule la position cible dans la formation pour cette entité"""
	if target == null or not is_instance_valid(target):
		return entity.global_position
	
	# Obtenir la direction du leader
	var leader_direction = _get_leader_direction()
	var behind_angle = leader_direction.angle() + PI
	
	# Calculer la position dans la formation
	var formation_angle = _calculate_formation_angle(entity, group_name, behind_angle)
	
	# Calculer la position exacte
	var distance_to_leader = entity.global_position.distance_to(target.global_position)
	
	# Si on est trop proche ou trop loin, ajuster vers la distance idéale
	if abs(distance_to_leader - follow_distance) > distance_tolerance:
		# Calculer l'angle actuel
		var direction_to_entity = (entity.global_position - target.global_position).normalized()
		var current_angle = direction_to_entity.angle()
		
		# Utiliser un mélange entre l'angle actuel et l'angle préféré
		var target_angle = lerp_angle(current_angle, formation_angle, angle_lerp_speed)
		preferred_angle = target_angle
		
		return target.global_position + Vector2(cos(target_angle), sin(target_angle)) * follow_distance
	else:
		# Si on est à la bonne distance, ajuster légèrement vers l'angle préféré
		var direction_to_entity = (entity.global_position - target.global_position).normalized()
		var current_angle = direction_to_entity.angle()
		
		# Légèrement ajuster vers l'angle préféré
		var target_angle = lerp_angle(current_angle, formation_angle, angle_lerp_speed * 0.5)
		preferred_angle = target_angle
		
		return target.global_position + Vector2(cos(target_angle), sin(target_angle)) * follow_distance

func is_at_position(entity_position: Vector2, target_position: Vector2) -> bool:
	"""Vérifie si l'entité est à la position cible"""
	return entity_position.distance_to(target_position) <= distance_tolerance

func _get_leader_direction() -> Vector2:
	"""Obtient la direction vers laquelle regarde le leader"""
	if target == null or not is_instance_valid(target):
		return Vector2(0, 1)
	
	# Essayer d'obtenir la direction via une méthode
	if target.has_method("get_direction_vector"):
		return target.get_direction_vector()
	
	# Fallback : utiliser la vélocité du leader
	if target is CharacterBody2D:
		if target.velocity.length() > 0.1:
			return target.velocity.normalized()
	
	# Fallback final : direction vers le bas
	return Vector2(0, 1)

func _calculate_formation_angle(entity: Node2D, group_name: String, behind_angle: float) -> float:
	"""Calcule l'angle de formation pour cette entité dans le groupe"""
	var members = get_tree().get_nodes_in_group(group_name)
	var valid_members = []
	
	# Filtrer les membres valides
	for member in members:
		if is_instance_valid(member):
			valid_members.append(member)
	
	# Trier par instance_id pour avoir un ordre stable
	valid_members.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	
	var index = valid_members.find(entity)
	var count = valid_members.size()
	
	# Si un seul membre ou pas trouvé, directement derrière
	if count <= 1 or index == -1:
		return behind_angle
	
	# Répartir sur un arc de 180 degrés derrière le leader
	var arc_range = PI  # 180 degrés
	var start_angle = behind_angle - arc_range / 2.0
	var angle_step = arc_range / (count - 1)
	
	return start_angle + (angle_step * index)

func sync_direction_with_leader() -> String:
	"""Retourne la direction cardinale du leader (si disponible)"""
	if target == null or not is_instance_valid(target):
		return "south"
	
	if target.has_method("get_cardinal_direction"):
		return target.get_cardinal_direction()
	
	return "south"

func sync_state_with_leader() -> String:
	"""Retourne l'état du leader (si disponible)"""
	if target == null or not is_instance_valid(target):
		return "idle"
	
	if "current_state" in target:
		return target.current_state
	
	return "idle"
