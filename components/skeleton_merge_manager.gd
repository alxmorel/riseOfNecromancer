extends Node
class_name SkeletonMergeManager

## SkeletonMergeManager
## Gère la fusion de skeletons par paires de même niveau
## Responsabilité : Extraction de données, création et configuration de skeletons fusionnés

signal merge_started()
signal merge_completed(merged_count: int)
signal merge_failed(reason: String)

@export var skeleton_scene: PackedScene
@export var merge_multiplier: float = 2.0  # Stats × 2 à chaque fusion
@export var sprite_scale_multiplier: float = 1.5  # Sprite × 1.5 à chaque fusion

## Fusionne les skeletons d'un groupe par paires de même niveau
func merge_skeletons(group_name: String = "skeletons") -> int:
	merge_started.emit()
	
	if not skeleton_scene:
		merge_failed.emit("Skeleton scene non définie")
		return 0
	
	# Récupérer tous les skeletons valides
	var skeletons = _get_valid_skeletons(group_name)
	
	if skeletons.size() < 2:
		merge_failed.emit("Pas assez de skeletons pour fusionner (minimum 2 requis)")
		return 0
	
	# Grouper par niveau de merge
	var skeletons_by_level = _group_by_level(skeletons)
	
	# Fusionner par paires
	var total_merged = 0
	for level in skeletons_by_level.keys():
		var merged_count = await _merge_level(level, skeletons_by_level[level])
		total_merged += merged_count
	
	merge_completed.emit(total_merged)
	return total_merged

## Récupère les skeletons valides d'un groupe
func _get_valid_skeletons(group_name: String) -> Array:
	var all_skeletons = get_tree().get_nodes_in_group(group_name)
	var valid_skeletons = []
	
	for skeleton in all_skeletons:
		if is_instance_valid(skeleton) and not skeleton.is_queued_for_deletion():
			valid_skeletons.append(skeleton)
	
	return valid_skeletons

## Groupe les skeletons par niveau de merge
func _group_by_level(skeletons: Array) -> Dictionary:
	var by_level = {}
	
	for skeleton in skeletons:
		var level = skeleton.get("merge_level") if "merge_level" in skeleton else 0
		
		if not by_level.has(level):
			by_level[level] = []
		by_level[level].append(skeleton)
	
	return by_level

## Fusionne tous les skeletons d'un niveau donné
func _merge_level(level: int, skeletons: Array) -> int:
	if skeletons.size() < 2:
		return 0
	
	var merged_count = 0
	
	# Traiter par paires : i=0,1 puis i=2,3 puis i=4,5 etc.
	for i in range(0, skeletons.size(), 2):
		if i + 1 >= skeletons.size():
			break  # Pas de paire, on arrête
		
		var skeleton1 = skeletons[i]
		var skeleton2 = skeletons[i + 1]
		
		# Vérifier à nouveau que les deux sont valides
		if not is_instance_valid(skeleton1) or skeleton1.is_queued_for_deletion():
			continue
		if not is_instance_valid(skeleton2) or skeleton2.is_queued_for_deletion():
			continue
		
		# Fusionner la paire
		var merged = await _merge_pair(skeleton1, skeleton2, level)
		if merged:
			merged_count += 1
	
	return merged_count

## Fusionne une paire de skeletons
func _merge_pair(skeleton1: CharacterBody2D, skeleton2: CharacterBody2D, level: int) -> Node:
	# EXTRAIRE toutes les données nécessaires AVANT de supprimer
	var merge_position = (skeleton1.global_position + skeleton2.global_position) / 2.0
	var skeleton_scale = skeleton1.scale * 2.0
	var sprite_scale = _get_sprite_scale(skeleton1) * sprite_scale_multiplier
	var skeleton_data = _extract_skeleton_data(skeleton1, level)
	
	# IMPORTANT: Retirer du groupe IMMÉDIATEMENT
	skeleton1.remove_from_group("skeletons")
	skeleton2.remove_from_group("skeletons")
	
	# Créer LE skeleton mergé (1 seul pour 2 supprimés)
	var merged = skeleton_scene.instantiate()
	if not merged:
		# Si échec, remettre dans le groupe
		skeleton1.add_to_group("skeletons")
		skeleton2.add_to_group("skeletons")
		return null
	
	# Créer et configurer le skeleton fusionné
	merged.merge_level = level + 1
	merged.scale = skeleton_scale
	
	# IMPORTANT: Désactiver le skeleton pour éviter qu'il agisse avant la config
	merged.set_physics_process(false)
	merged.set_process(false)
	
	# Ajouter à la scène (inactif)
	var scene_root = get_tree().current_scene
	if not scene_root:
		skeleton1.add_to_group("skeletons")
		skeleton2.add_to_group("skeletons")
		merged.queue_free()
		return null
	
	scene_root.add_child(merged)
	
	# Positionner AU CENTRE entre les 2 skeletons d'origine (APRÈS add_child)
	merged.global_position = merge_position
	
	# Scaler UNIQUEMENT le sprite (pas la hitbox)
	if merged.has_node("AnimatedSprite2D"):
		merged.get_node("AnimatedSprite2D").scale = sprite_scale
		print("📏 Sprite du skeleton fusionné (niveau ", level + 1, "): scale ", sprite_scale)
	
	print("🔧 Configuration du skeleton fusionné niveau ", level + 1, " à la position ", merge_position)
	
	# SUPPRIMER les 2 originaux APRÈS avoir positionné le nouveau
	skeleton1.free()
	skeleton2.free()
	
	# Configurer les stats (le skeleton est inactif)
	await _apply_merged_stats(merged, skeleton_data)
	
	print("✅ Configuration terminée! Activation du skeleton...")
	
	# RÉACTIVER le skeleton maintenant qu'il a les bonnes stats
	merged.set_physics_process(true)
	merged.set_process(true)
	
	return merged

## Extrait les données d'un skeleton avant sa suppression
func _extract_skeleton_data(skeleton: CharacterBody2D, level: int) -> Dictionary:
	var data = {}
	data["level"] = level
	
	# Essayer d'extraire depuis les composants (nouvelle architecture)
	if skeleton.has_node("HealthComponent"):
		var health = skeleton.get_node("HealthComponent")
		data["max_health"] = health.max_health
	elif "max_health" in skeleton:
		data["max_health"] = skeleton.max_health
	else:
		data["max_health"] = 40  # Valeur par défaut
	
	if skeleton.has_node("CombatComponent"):
		var combat = skeleton.get_node("CombatComponent")
		data["damage"] = combat.damage
		data["attack_range"] = combat.attack_range
		data["attack_cooldown"] = combat.attack_cooldown
		data["attack_duration"] = combat.attack_duration
		data["detection_range"] = combat.detection_range
	elif "damage" in skeleton:
		data["damage"] = skeleton.damage
		data["attack_range"] = skeleton.attack_range
		data["attack_cooldown"] = skeleton.attack_cooldown
		data["attack_duration"] = skeleton.attack_duration
		data["detection_range"] = skeleton.enemy_detection_range
	else:
		data["damage"] = 15
		data["attack_range"] = 15.0
		data["attack_cooldown"] = 1.5
		data["attack_duration"] = 0.5
		data["detection_range"] = 300.0
	
	if skeleton.has_node("NecroEnergyComponent"):
		var necro_energy = skeleton.get_node("NecroEnergyComponent")
		data["max_necro_energy"] = necro_energy.max_energy
		data["drain_rate"] = necro_energy.drain_rate
	elif "max_necro_energy" in skeleton:
		data["max_necro_energy"] = skeleton.max_necro_energy
		data["drain_rate"] = skeleton.drain_rate if "drain_rate" in skeleton else 1.0
	else:
		data["max_necro_energy"] = 30.0
		data["drain_rate"] = 1.0
	
	if skeleton.has_node("FormationFollower"):
		var formation = skeleton.get_node("FormationFollower")
		data["follow_distance"] = formation.follow_distance
	elif "follow_distance" in skeleton:
		data["follow_distance"] = skeleton.follow_distance
	else:
		data["follow_distance"] = 30.0
	
	print("📦 Extraction données skeleton niveau ", level, ": HP=", data["max_health"], " DMG=", data["damage"])
	
	return data

## Récupère le scale du sprite d'un skeleton
func _get_sprite_scale(skeleton: CharacterBody2D) -> Vector2:
	if skeleton.has_node("AnimatedSprite2D"):
		return skeleton.get_node("AnimatedSprite2D").scale
	return Vector2(1.0, 1.0)

## Applique les stats fusionnées à un skeleton
func _apply_merged_stats(skeleton: Node, data: Dictionary) -> void:
	# Attendre que le skeleton soit prêt
	if skeleton.has_method("configure_merged_stats_from_data"):
		await skeleton.configure_merged_stats_from_data(data, merge_multiplier)
	else:
		push_warning("SkeletonMergeManager: Le skeleton n'a pas la méthode configure_merged_stats_from_data")
