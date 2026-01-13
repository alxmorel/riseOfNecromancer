extends Node
class_name HealthComponent

## Composant de gestion de la santé
## Émet des signaux pour notifier les changements de santé

signal health_changed(current: int, maximum: int)
signal died()

@export var max_health: int = 100
var current_health: int

func _ready():
	current_health = max_health

func take_damage(amount: int) -> void:
	"""Inflige des dégâts à l'entité"""
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		died.emit()

func heal(amount: int) -> void:
	"""Soigne l'entité"""
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func get_health_percentage() -> float:
	"""Retourne le pourcentage de santé (0.0 à 1.0)"""
	return float(current_health) / float(max_health) if max_health > 0 else 0.0

func is_alive() -> bool:
	"""Vérifie si l'entité est toujours en vie"""
	return current_health > 0
