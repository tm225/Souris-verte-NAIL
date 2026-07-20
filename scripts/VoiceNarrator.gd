extends Node
## Autoload singleton — gère la narration vocale en français.
## Utilise le TTS natif de Godot 4 (DisplayServer.tts_speak),
## qui fonctionne directement sur Android sans dépendance externe.

var voice_id: String = ""
var is_speaking: bool = false

func _ready() -> void:
	_pick_french_voice()

func _pick_french_voice() -> void:
	# Cherche une voix française parmi les voix disponibles sur l'appareil.
	var voices := DisplayServer.tts_get_voices_for_language("fr")
	if voices.size() > 0:
		voice_id = voices[0]
	else:
		voice_id = "" # Godot utilisera la voix par défaut du système

## Prononce un texte en français, à un débit ralenti adapté aux enfants.
func speak(text: String, interrupt: bool = true) -> void:
	if interrupt:
		DisplayServer.tts_stop()
	is_speaking = true
	DisplayServer.tts_speak(
		text,
		voice_id,
		80,   # volume (0-100)
		0.85, # débit ralenti pour bien articuler (1.0 = normal)
		1.0,  # pitch normal
		0     # utterance_id
	)

func stop() -> void:
	DisplayServer.tts_stop()
	is_speaking = false

func _process(_delta: float) -> void:
	# Godot ne fournit pas toujours de callback fiable multiplateforme pour
	# la fin de la synthèse ; on considère la narration terminée après un
	# délai basé sur la longueur du texte (géré par l'appelant si besoin).
	pass
