extends Node
class_name EntityStateManager

## EntityStateManager
## Gère la machine à états d'une entité (IDLE, FOLLOWING, ATTACKING, etc.)
## Responsabilité : Transitions d'états et logique d'état centralisée

signal state_changed(old_state: String, new_state: String)

## États disponibles
enum State {
	IDLE,
	FOLLOWING,
	MOVING_TO_COMBAT,
	ATTACKING,
	CHASING,
	WALKING
}

@export var initial_state: State = State.IDLE

var current_state: State = State.IDLE
var parent_entity: CharacterBody2D
var state_processors: Dictionary = {}  # Callbacks pour chaque état

func _ready():
	if owner is CharacterBody2D:
		parent_entity = owner
	else:
		push_error("EntityStateManager must be a child of a CharacterBody2D.")
		set_process(false)
		return
	
	current_state = initial_state

## Enregistre un callback pour un état spécifique
func register_state_processor(state: State, callback: Callable) -> void:
	state_processors[state] = callback

## Change l'état de l'entité
func change_state(new_state: State) -> void:
	if current_state != new_state:
		var old_state = current_state
		current_state = new_state
		state_changed.emit(_state_to_string(old_state), _state_to_string(new_state))

## Traite l'état actuel (appelé depuis _physics_process de l'entité)
func process_current_state(delta: float) -> void:
	if state_processors.has(current_state):
		state_processors[current_state].call(delta)

## Obtient l'état actuel
func get_current_state() -> State:
	return current_state

## Vérifie si l'entité est dans un état donné
func is_in_state(state: State) -> bool:
	return current_state == state

## Retourne le nom de l'état actuel (pour debug/animation)
func get_state_name() -> String:
	return _state_to_string(current_state)

## Convertit un état en string
func _state_to_string(state: State) -> String:
	match state:
		State.IDLE: return "idle"
		State.FOLLOWING: return "following"
		State.MOVING_TO_COMBAT: return "moving_to_combat"
		State.ATTACKING: return "attacking"
		State.CHASING: return "chasing"
		State.WALKING: return "walking"
	return "unknown"

## Helper : Vérifie si l'entité devrait attaquer une cible
func should_attack_target(target: Node2D, attack_range: float) -> bool:
	if not is_instance_valid(parent_entity):
		return false
	if not target or not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	
	var distance = parent_entity.global_position.distance_to(target.global_position)
	return distance <= attack_range

## Helper : Vérifie si l'entité devrait se déplacer vers une cible
func should_move_to_target(target: Node2D) -> bool:
	if not target or not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	return true

## Helper : Vérifie si l'entité est à une position donnée
func is_at_position(target_position: Vector2, tolerance: float = 10.0) -> bool:
	if not is_instance_valid(parent_entity):
		return false
	return parent_entity.global_position.distance_to(target_position) <= tolerance
