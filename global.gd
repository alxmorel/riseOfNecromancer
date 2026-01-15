extends Node

## Global - Gestionnaire de données persistantes entre scènes
## Ce script est en AutoLoad et persiste entre les changements de scène

# Nom de la scène actuelle (pour référence)
var current_scene: String = ""

# Nom du dernier portail utilisé (pour éviter les boucles)
var last_portal_used: String = ""

# Données du joueur à conserver entre scènes
var player_health: int = 100
var player_max_health: int = 100
var player_necro_energy: float = 100.0
var player_max_necro_energy: float = 100.0

# Inventaire persistant (si nécessaire)
var player_inventory: Array = []

func _ready():
	print("🌐 Global initialisé")

func save_player_state(player: Node):
	"""Sauvegarde l'état du joueur avant un changement de scène"""

	if not player:
		return
	
	# Sauvegarder la santé si le composant existe
	if player.has_node("HealthComponent"):
		var health_comp = player.get_node("HealthComponent")
		player_health = health_comp.current_health
		player_max_health = health_comp.max_health
	
	# Sauvegarder l'énergie nécromantique si le composant existe
	if player.has_node("NecroEnergyComponent"):
		var necro_comp = player.get_node("NecroEnergyComponent")
		player_necro_energy = necro_comp.current_energy
		player_max_necro_energy = necro_comp.max_energy

func restore_player_state(player: Node):
	"""Restaure l'état du joueur après un changement de scène"""
	
	if not player:
		return
	
	# Restaurer la santé
	if player.has_node("HealthComponent"):
		var health_comp = player.get_node("HealthComponent")
		health_comp.current_health = player_health
		health_comp.max_health = player_max_health
		health_comp.health_changed.emit(player_health, player_max_health)
	
	# Restaurer l'énergie nécromantique
	if player.has_node("NecroEnergyComponent"):
		var necro_comp = player.get_node("NecroEnergyComponent")
		necro_comp.current_energy = player_necro_energy
		necro_comp.max_energy = player_max_necro_energy
		necro_comp.energy_changed.emit(player_necro_energy, player_max_necro_energy)
	

func change_scene_to(scene_path: String, portal_name: String = ""):
	current_scene = scene_path
	last_portal_used = portal_name
	
	# Vérifier si le chemin est un UID ou un chemin de fichier
	if scene_path.begins_with("uid://"):
		var resource_path = ResourceUID.get_id_path(ResourceUID.text_to_id(scene_path))
		if resource_path != "":
			scene_path = resource_path
		else:
			return
	
	var result = get_tree().change_scene_to_file(scene_path)
