extends Area2D
class_name Portal

## Portal - Zone de transition entre scènes
## Place ce nœud dans tes scènes pour créer des passages

# Scène de destination
@export_file("*.tscn") var target_scene: String = ""

# Nom unique du portail (pour éviter les boucles de téléportation)
@export var portal_name: String = ""

# Activation automatique ou manuelle
@export var auto_transition: bool = false

# Touche pour interagir (si non automatique)
@export var interaction_key: String = "ui_accept"

# Indicateur visuel
@export var show_prompt: bool = true
@export var prompt_text: String = "Appuyez sur [E] pour entrer"

# État interne
var player_in_area: bool = false
var can_use: bool = true
var label: Label = null

func _ready():
	# Connecter les signaux
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Créer le label de prompt si nécessaire
	if show_prompt and not auto_transition:
		_create_prompt_label()
	
	# Vérifier que le portail est configuré
	if target_scene == "":
		push_warning("⚠️ Portal '", name, "' n'a pas de scène cible définie!")
	else:
		print("🚪 Portal '", name, "' configuré:")
		print("   → Target Scene: ", target_scene)
		print("   → Portal Name: ", portal_name)
		print("   → Auto Transition: ", auto_transition)
		print("   → Position: ", global_position)
	
	# Empêcher l'utilisation si c'est le dernier portail utilisé
	if Global.last_portal_used == portal_name and portal_name != "":
		print("🔒 Portal '", name, "' temporairement désactivé (dernier utilisé)")
		can_use = false
		# Réactiver après un court délai
		await get_tree().create_timer(0.5).timeout
		can_use = true
		print("🔓 Portal '", name, "' réactivé")

func _create_prompt_label():
	"""Crée un label pour afficher le texte d'interaction"""
	label = Label.new()
	label.text = prompt_text
	label.visible = false
	label.z_index = 100
	label.position = Vector2(-50, -40)  # Au-dessus du portail
	
	# Style du label
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	
	add_child(label)

func _on_body_entered(body: Node2D):
	"""Appelé quand un corps entre dans la zone"""
	print("👤 Corps entré dans portal '", name, "': ", body.name)
	
	if not body.is_in_group("players"):
		print("   ⚠️ Ce n'est pas un joueur, ignoré")
		return
	
	print("   ✅ C'est un joueur!")
	player_in_area = true
	
	# Afficher le prompt
	if label:
		label.visible = true
	
	# Transition automatique
	if auto_transition:
		print("   🔄 Auto-transition activée")
		if can_use:
			print("   ➡️ Utilisation du portail...")
			_use_portal(body)
		else:
			print("   ⏸️ Portail en cooldown")

func _on_body_exited(body: Node2D):
	"""Appelé quand un corps sort de la zone"""
	if not body.is_in_group("players"):
		return
	
	print("👋 Joueur sorti du portal '", name, "'")
	player_in_area = false
	
	# Cacher le prompt
	if label:
		label.visible = false

func _input(event: InputEvent):
	"""Gère l'interaction manuelle avec le portail"""
	if not player_in_area or auto_transition or not can_use:
		return
	
	if event.is_action_pressed(interaction_key):
		print("⌨️ Touche ", interaction_key, " pressée près du portal '", name, "'")
		var player = _get_player_in_area()
		if player:
			print("   ✅ Joueur trouvé: ", player.name)
			_use_portal(player)
		else:
			print("   ❌ Aucun joueur trouvé dans la zone")

func _use_portal(player: Node):
	"""Active la transition vers la scène cible"""
	print("🔵 _use_portal appelé pour portal '", name, "'")
	print("   Target Scene: ", target_scene)
	print("   Can Use: ", can_use)
	
	if target_scene == "":
		print("   ❌ ERREUR: Target Scene vide!")
		return
	
	if not can_use:
		print("   ❌ ERREUR: Portal en cooldown!")
		return
	
	can_use = false
	print("   💾 Sauvegarde de l'état du joueur...")
	
	# Sauvegarder l'état du joueur
	Global.save_player_state(player)
	
	print("   🌍 Changement de scène vers: ", target_scene)
	
	# Changer de scène
	Global.change_scene_to(target_scene, portal_name)

func _get_player_in_area() -> Node:
	"""Récupère le joueur dans la zone"""
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("players"):
			return body
	return null
