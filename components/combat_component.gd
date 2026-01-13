extends Node
class_name CombatComponent

## Composant de gestion du combat
## Gère la détection d'ennemis, le cooldown d'attaque et les dégâts

signal attack_started()
signal attack_finished()
signal enemy_hit(enemy: Node, damage_dealt: int)

@export var damage: int = 15
@export var attack_range: float = 15.0
@export var attack_cooldown: float = 1.2
@export var attack_duration: float = 0.6
@export var detection_range: float = 300.0

var target: CharacterBody2D = null
var is_attacking: bool = false
var last_attack_time: float = 0.0
var attack_timer: float = 0.0

func _process(delta):
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			attack_finished.emit()

func find_closest_enemy(from_position: Vector2, enemy_group: String = "enemies") -> CharacterBody2D:
	"""Trouve l'ennemi le plus proche dans la portée de détection"""
	var enemies = get_tree().get_nodes_in_group(enemy_group)
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies:
		# Vérifier que l'ennemi est valide et pas en cours de suppression
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			var distance = from_position.distance_to(enemy.global_position)
			if distance <= detection_range and distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	return closest_enemy

func can_attack() -> bool:
	"""Vérifie si on peut attaquer (cooldown terminé)"""
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_attack_time >= attack_cooldown

func is_in_range(attacker_position: Vector2) -> bool:
	"""Vérifie si la cible est à portée d'attaque"""
	if not _is_target_valid():
		return false
	
	var distance = attacker_position.distance_to(target.global_position)
	return distance <= attack_range

func try_attack(attacker_position: Vector2) -> bool:
	"""Tente d'attaquer si toutes les conditions sont remplies"""
	if not _is_target_valid():
		return false
	
	if not is_in_range(attacker_position):
		return false
	
	if not can_attack():
		return false
	
	perform_attack()
	return true

func _is_target_valid() -> bool:
	"""Vérifie si la cible est valide et pas en cours de suppression"""
	if target == null:
		return false
	
	if not is_instance_valid(target):
		target = null
		return false
	
	if target.is_queued_for_deletion():
		target = null
		return false
	
	return true

func perform_attack() -> void:
	"""Exécute l'attaque sur la cible"""
	if not _is_target_valid():
		return
	
	# Infliger les dégâts
	if target.has_method("take_damage"):
		target.take_damage(damage)
		enemy_hit.emit(target, damage)
	
	# Mettre à jour les timers
	var current_time = Time.get_ticks_msec() / 1000.0
	last_attack_time = current_time
	is_attacking = true
	attack_timer = attack_duration
	attack_started.emit()

func get_direction_to_target(from_position: Vector2) -> Vector2:
	"""Retourne la direction normalisée vers la cible"""
	if not _is_target_valid():
		return Vector2.ZERO
	
	return (target.global_position - from_position).normalized()
