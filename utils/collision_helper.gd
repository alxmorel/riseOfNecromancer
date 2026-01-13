class_name CollisionHelper

## Classe utilitaire pour la gestion des collisions
## Fournit des méthodes statiques pour calculer les directions d'évitement

static func calculate_avoidance_direction(
	collision_normal: Vector2, 
	desired_direction: Vector2,
	target_position: Vector2,
	current_position: Vector2
) -> Vector2:
	"""
	Calcule la meilleure direction pour contourner un obstacle
	
	Args:
		collision_normal: La normale de la collision
		desired_direction: La direction souhaitée (non utilisée directement)
		target_position: La position de la cible à atteindre
		current_position: La position actuelle de l'entité
	
	Returns:
		La direction normalisée optimale pour contourner l'obstacle
	"""
	var direction_to_target = (target_position - current_position).normalized()
	
	# Calculer le vecteur perpendiculaire à la normale
	var perp_vector = Vector2(-collision_normal.y, collision_normal.x)
	
	# Calculer deux directions possibles de contournement
	var left_direction = (direction_to_target + perp_vector).normalized()
	var right_direction = (direction_to_target - perp_vector).normalized()
	
	# Tester quelle direction rapproche le plus de la cible
	var probe_distance = 20.0  # Distance de test
	var left_distance = (current_position + left_direction * probe_distance).distance_to(target_position)
	var right_distance = (current_position + right_direction * probe_distance).distance_to(target_position)
	
	# Retourner la meilleure direction
	return left_direction if left_distance < right_distance else right_direction

static func slide_along_wall(velocity: Vector2, collision_normal: Vector2) -> Vector2:
	"""
	Calcule la direction pour glisser le long d'un mur
	
	Args:
		velocity: La vélocité actuelle
		collision_normal: La normale de la collision
	
	Returns:
		La nouvelle direction glissée le long du mur
	"""
	return velocity.slide(collision_normal).normalized()

static func is_valid_direction(direction: Vector2) -> bool:
	"""
	Vérifie si une direction est valide (pas de NaN ou Inf)
	
	Args:
		direction: Le vecteur direction à vérifier
	
	Returns:
		true si la direction est valide, false sinon
	"""
	return not (is_nan(direction.x) or is_nan(direction.y) or 
				is_inf(direction.x) or is_inf(direction.y))

static func safe_normalize(vector: Vector2, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	"""
	Normalise un vecteur de manière sécurisée
	
	Args:
		vector: Le vecteur à normaliser
		fallback: Le vecteur de repli si la normalisation échoue
	
	Returns:
		Le vecteur normalisé ou le vecteur de repli
	"""
	var length = vector.length()
	
	if length > 0.001:
		var normalized = vector.normalized()
		if is_valid_direction(normalized):
			return normalized
	
	return fallback
