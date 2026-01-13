extends Node
class_name NecroEnergyComponent

## Composant de gestion de l'énergie nécromantique
## Se draine ou se régénère automatiquement au fil du temps
## drain_rate positif = drain (skeletons), négatif = régénération (player)

signal energy_changed(current: float, maximum: float)
signal energy_depleted()
signal energy_consumed(amount: float, remaining: float)  # Nouveau signal

@export var max_energy: float = 30.0
@export var drain_rate: float = 1.0  # Points par seconde (positif = drain, négatif = régénération)
@export var auto_process: bool = true  # Active/désactive le traitement automatique

var current_energy: float
var target_width: float = 0.0  # Pour le lissage de l'animation de la barre

func _ready():
	current_energy = max_energy

func _process(delta):
	if auto_process and drain_rate != 0:
		if drain_rate > 0:
			# Drain mode (pour skeletons)
			drain_energy(drain_rate * delta)
		else:
			# Regeneration mode (pour player)
			add_energy(abs(drain_rate) * delta)

func drain_energy(amount: float) -> void:
	"""Draine de l'énergie"""
	current_energy = max(0.0, current_energy - amount)
	energy_changed.emit(current_energy, max_energy)
	
	if current_energy <= 0:
		energy_depleted.emit()

func add_energy(amount: float) -> void:
	"""Ajoute de l'énergie (plafonné au maximum)"""
	current_energy = min(max_energy, current_energy + amount)
	energy_changed.emit(current_energy, max_energy)

func consume_energy(amount: float) -> bool:
	"""Consomme de l'énergie si disponible. Retourne true si succès."""
	if current_energy >= amount:
		current_energy -= amount
		energy_changed.emit(current_energy, max_energy)
		energy_consumed.emit(amount, current_energy)
		
		if current_energy <= 0:
			energy_depleted.emit()
		
		return true
	return false

func can_consume(amount: float) -> bool:
	"""Vérifie si on peut consommer une quantité d'énergie"""
	return current_energy >= amount

func get_energy_percentage() -> float:
	"""Retourne le pourcentage d'énergie (0.0 à 1.0)"""
	return current_energy / max_energy if max_energy > 0 else 0.0

func has_energy() -> bool:
	"""Vérifie s'il reste de l'énergie"""
	return current_energy > 0
