extends Node3D
## Cœur de la logique du jeu "Une Souris Verte".
##
## Chaque étape de la comptine est décrite par un dictionnaire dans STEPS.
## Le script construit dynamiquement des objets 3D en primitives pour
## chaque étape (pas besoin d'assets .glb externes), écoute le texte via
## VoiceNarrator, et attend que l'enfant tape sur l'élément en surbrillance
## avant de passer à l'étape suivante.

@onready var stage_root: Node3D = $StageRoot
@onready var camera: Camera3D = $Camera3D
@onready var progress_dots: HBoxContainer = $UI/MarginContainer/VBoxContainer/ProgressDots
@onready var restart_button: Button = $UI/RestartButton
@onready var hint_timer: Timer = $HintTimer

const TARGET_GROUP := "tappable"

# Chaque étape : texte narré, couleur du halo, et une fonction "builder"
# qui construit les objets 3D de la scène. build_fn reçoit le Node3D
# parent (stage_root) et doit retourner le Node3D "target" à taper.
var STEPS: Array = []

var current_target: Node3D = null
var awaiting_tap: bool = false
var hint_pulses: int = 0

func _ready() -> void:
	_define_steps()
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.visible = false
	hint_timer.timeout.connect(_on_hint_timeout)
	GameState.step_changed.connect(_on_step_changed)
	GameState.rhyme_completed.connect(_on_rhyme_completed)
	GameState.reset()
	_load_step(0)

func _define_steps() -> void:
	STEPS = [
		{
			"text": "Une souris verte...",
			"halo_color": Color(0.2, 0.9, 0.3),
			"build": Callable(self, "_build_step_mouse_intro"),
		},
		{
			"text": "...qui courait dans l'herbe.",
			"halo_color": Color(0.3, 0.8, 0.2),
			"build": Callable(self, "_build_step_grass"),
		},
		{
			"text": "Je l'attrape par la queue.",
			"halo_color": Color(0.9, 0.7, 0.2),
			"build": Callable(self, "_build_step_tail"),
		},
		{
			"text": "Je la montre à ces messieurs.",
			"halo_color": Color(0.9, 0.5, 0.2),
			"build": Callable(self, "_build_step_messieurs"),
		},
		{
			"text": "Ces messieurs me disent : trempez-la dans l'huile.",
			"halo_color": Color(0.8, 0.6, 0.1),
			"build": Callable(self, "_build_step_huile"),
		},
		{
			"text": "Trempez-la dans l'eau.",
			"halo_color": Color(0.2, 0.6, 0.9),
			"build": Callable(self, "_build_step_eau"),
		},
		{
			"text": "Ça fera un escargot tout chaud !",
			"halo_color": Color(0.8, 0.4, 0.7),
			"build": Callable(self, "_build_step_escargot"),
		},
	]

# ----------------------------------------------------------------
# Gestion de la progression
# ----------------------------------------------------------------

func _on_step_changed(new_step: int) -> void:
	_load_step(new_step)

func _load_step(index: int) -> void:
	awaiting_tap = false
	hint_pulses = 0
	hint_timer.stop()
	_clear_stage()
	_update_progress_dots(index)

	var step: Dictionary = STEPS[index]
	current_target = step["build"].call(stage_root)
	if current_target:
		current_target.add_to_group(TARGET_GROUP)
		_ensure_tappable_collider(current_target)
		_apply_halo(current_target, step["halo_color"])

	VoiceNarrator.speak(step["text"])
	awaiting_tap = true
	hint_timer.start(9.0)

func _clear_stage() -> void:
	for child in stage_root.get_children():
		child.queue_free()

func _update_progress_dots(index: int) -> void:
	for i in progress_dots.get_child_count():
		var dot: ColorRect = progress_dots.get_child(i)
		dot.color = Color(1, 1, 1, 0.9) if i <= index else Color(1, 1, 1, 0.25)

func _on_hint_timeout() -> void:
	# Pas d'avancement automatique : on renforce juste le halo pour guider
	# l'enfant, sans jamais faire progresser la scène toute seule.
	if current_target and awaiting_tap:
		hint_pulses += 1
		var tw := create_tween()
		tw.tween_property(current_target, "scale", current_target.scale * 1.15, 0.25)
		tw.tween_property(current_target, "scale", current_target.scale, 0.25)
	hint_timer.start(4.0)

func _on_rhyme_completed() -> void:
	awaiting_tap = false
	restart_button.visible = true
	VoiceNarrator.speak("Bravo ! Tu veux recommencer ?")

func _on_restart_pressed() -> void:
	restart_button.visible = false
	GameState.restart()

# ----------------------------------------------------------------
# Détection du tap / clic en 3D (raycast depuis la caméra)
# ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not awaiting_tap:
		return
	var tap_pos: Vector2
	if event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
	else:
		return

	var from: Vector3 = camera.project_ray_origin(tap_pos)
	var to: Vector3 = from + camera.project_ray_normal(tap_pos) * 1000.0
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)

	if result and result.collider:
		var hit: Node = result.collider
		var check: Node = hit
		# Remonte jusqu'à 3 niveaux pour retrouver le node taggé "tappable"
		for i in range(3):
			if check == null:
				break
			if check.is_in_group(TARGET_GROUP):
				_on_target_tapped()
				return
			check = check.get_parent()

func _on_target_tapped() -> void:
	if not awaiting_tap:
		return
	awaiting_tap = false
	hint_timer.stop()
	_play_success_reaction()
	await get_tree().create_timer(1.1).timeout
	GameState.advance()

func _play_success_reaction() -> void:
	if not current_target:
		return
	var tw := create_tween()
	tw.tween_property(current_target, "scale", current_target.scale * 1.3, 0.15)
	tw.tween_property(current_target, "scale", current_target.scale, 0.25)
	tw.set_trans(Tween.TRANS_BOUNCE)

func _apply_halo(target: Node3D, color: Color) -> void:
	var halo := OmniLight3D.new()
	halo.light_color = color
	halo.light_energy = 1.8
	halo.omni_range = 2.5
	halo.name = "Halo"
	target.add_child(halo)
	var tw := create_tween().set_loops()
	tw.tween_property(halo, "light_energy", 0.8, 0.6)
	tw.tween_property(halo, "light_energy", 1.8, 0.6)

# ----------------------------------------------------------------
# Constructeurs de scène — primitives 3D stylisées low-poly
# ----------------------------------------------------------------

func _make_mouse(parent: Node3D, pos: Vector3) -> Node3D:
	var mouse := Node3D.new()
	mouse.name = "Mouse"
	mouse.position = pos
	parent.add_child(mouse)

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 0.6
	body.mesh = body_mesh
	body.position = Vector3(0, 0.35, 0)
	_set_material(body, Color(0.25, 0.75, 0.3))
	mouse.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.4
	head.mesh = head_mesh
	head.position = Vector3(0, 0.55, 0.32)
	_set_material(head, Color(0.28, 0.78, 0.32))
	mouse.add_child(head)

	for side in [-1, 1]:
		var ear := MeshInstance3D.new()
		var ear_mesh := SphereMesh.new()
		ear_mesh.radius = 0.09
		ear_mesh.height = 0.15
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.15, 0.68, 0.35)
		_set_material(ear, Color(0.9, 0.6, 0.65))
		mouse.add_child(ear)

	var tail := MeshInstance3D.new()
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.03
	tail_mesh.bottom_radius = 0.05
	tail_mesh.height = 0.6
	tail.mesh = tail_mesh
	tail.name = "Tail"
	tail.rotation_degrees = Vector3(0, 0, 80)
	tail.position = Vector3(0, 0.2, -0.4)
	_set_material(tail, Color(0.85, 0.55, 0.55))
	mouse.add_child(tail)

	return mouse

## Ajoute un StaticBody3D + CollisionShape3D générique à la cible de l'étape
## courante, si elle n'en a pas déjà un, pour permettre la détection du tap
## quelle que soit la nature de l'objet (souris entière, queue, bocal...).
func _ensure_tappable_collider(node: Node3D) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			return # déjà pourvu d'un collider
	var radius := 0.55
	if node.name == "Tail":
		radius = 0.28
	elif node.name in ["OilJar", "Snail"]:
		radius = 0.5
	elif node.name == "Messieurs":
		radius = 1.6
	var col := StaticBody3D.new()
	col.name = "TapCollider"
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	col.add_child(shape)
	node.add_child(col)

func _make_ground(parent: Node3D, color: Color) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	ground.mesh = plane
	ground.position = Vector3(0, 0, 0)
	_set_material(ground, color)
	parent.add_child(ground)

func _set_material(mesh_instance: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	mesh_instance.material_override = mat

func _add_static_prop(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation_degrees = rot_deg
	_set_material(inst, color)
	parent.add_child(inst)
	return inst

# --- Étape 1 : la souris apparaît ---
func _build_step_mouse_intro(parent: Node3D) -> Node3D:
	_make_ground(parent, Color(0.55, 0.4, 0.3))
	return _make_mouse(parent, Vector3(0, 0, 0))

# --- Étape 2 : la souris court dans l'herbe ---
func _build_step_grass(parent: Node3D) -> Node3D:
	_make_ground(parent, Color(0.3, 0.65, 0.25))
	# Touffes d'herbe décoratives
	for i in range(14):
		var blade_mesh := CylinderMesh.new()
		blade_mesh.top_radius = 0.02
		blade_mesh.bottom_radius = 0.05
		blade_mesh.height = randf_range(0.3, 0.55)
		var pos := Vector3(randf_range(-2.5, 2.5), 0.2, randf_range(-2.5, 2.5))
		_add_static_prop(parent, blade_mesh, pos, Color(0.25, 0.7, 0.2))

	var mouse := _make_mouse(parent, Vector3(0, 0, 0))
	var tw := create_tween().set_loops()
	tw.tween_property(mouse, "position", Vector3(1.3, 0, 0.8), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mouse, "position", Vector3(-1.3, 0, -0.8), 1.2).set_trans(Tween.TRANS_SINE)
	return mouse

# --- Étape 3 : attraper par la queue ---
func _build_step_tail(parent: Node3D) -> Node3D:
	_make_ground(parent, Color(0.3, 0.65, 0.25))
	var mouse := _make_mouse(parent, Vector3(0, 0, 0))
	# La cible tapable est la queue elle-même
	var tail: Node3D = mouse.get_node("Tail")
	return tail

# --- Étape 4 : montrer à ces messieurs ---
func _build_step_messieurs(parent: Node3D) -> Node3D:
	_make_ground(parent, Color(0.6, 0.5, 0.35))
	_make_mouse(parent, Vector3(0, 0.6, -0.8))

	var messieurs := Node3D.new()
	messieurs.name = "Messieurs"
	parent.add_child(messieurs)

	var colors := [Color(0.2, 0.3, 0.7), Color(0.7, 0.2, 0.2), Color(0.2, 0.5, 0.3)]
	for i in range(3):
		var person := Node3D.new()
		person.position = Vector3((i - 1) * 0.9, 0, 1.2)
		messieurs.add_child(person)

		var torso_mesh := CapsuleMesh.new()
		torso_mesh.radius = 0.22
		torso_mesh.height = 0.7
		_add_static_prop(person, torso_mesh, Vector3(0, 0.5, 0), colors[i])

		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.18
		_add_static_prop(person, head_mesh, Vector3(0, 1.0, 0), Color(0.95, 0.8, 0.65))

	return messieurs

# --- Étape 5 : tremper dans l'huile ---
func _build_step_huile(parent: Node3D) -> Node3D:
	_make_ground(parent, Color(0.6, 0.5, 0.35))
	_make_mouse(parent, Vector3(-1.2, 0, 0))

	var jar_mesh := CylinderMesh.new()
	jar_mesh.top_radius = 0.4
	jar_mesh.bottom_radius = 0.45
	jar_mesh.height = 0.7
	var jar := _add_static_prop(parent, jar_mesh, Vector3(0.8, 0.35, 0), Color(0.75, 0.55, 0.15, 0.85))
	jar.name = "OilJar"
	return jar

# --- Étape 6 : tremper dans l'eau ---
func _build_step_eau(parent: Node3D) -> Node3D:
	_make_ground(parent, Color(0.6, 0.5, 0.35))
	_make_mouse(parent, Vector3(-1.2, 0, 0))

	var bucket_mesh := CylinderMesh.new()
	bucket_mesh.top_radius = 0.5
	bucket_mesh.bottom_radius = 0.4
	bucket_mesh.height = 0.6
	var bucket := _add_static_prop(parent, bucket_mesh, Vector3(0.8, 0.3, 0), Color(0.5, 0.5, 0.55))

	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 0.45
	water_mesh.bottom_radius = 0.45
	water_mesh.height = 0.05
	var water := _add_static_prop(parent, water_mesh, Vector3(0.8, 0.55, 0), Color(0.3, 0.6, 0.9, 0.8))
	water.name = "Water"
	return bucket

# --- Étape 7 : l'escargot tout chaud ---
func _build_step_escargot(parent: Node3D) -> Node3D:
	_make_ground(parent, Color(0.3, 0.65, 0.25))

	var snail := Node3D.new()
	snail.name = "Snail"
	parent.add_child(snail)

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.18
	body_mesh.height = 0.5
	var body := _add_static_prop(snail, body_mesh, Vector3(0, 0.18, 0.3), Color(0.85, 0.7, 0.3), Vector3(90, 0, 0))

	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.38
	_add_static_prop(snail, shell_mesh, Vector3(0, 0.4, -0.1), Color(0.8, 0.4, 0.65))

	for side in [-1, 1]:
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.02
		horn_mesh.bottom_radius = 0.04
		horn_mesh.height = 0.25
		_add_static_prop(snail, horn_mesh, Vector3(side * 0.06, 0.35, 0.55), Color(0.85, 0.7, 0.3), Vector3(-70, 0, 0))

	var tw := create_tween().set_loops()
	tw.tween_property(snail, "rotation_degrees:y", 360, 4.0)
	return snail
