extends Node
## Autoload singleton — état global du jeu : étape courante, progression.

signal step_changed(new_step: int)
signal rhyme_completed()

const TOTAL_STEPS := 7

var current_step: int = 0
var completed: bool = false

func reset() -> void:
	current_step = 0
	completed = false
	step_changed.emit(current_step)

func advance() -> void:
	if current_step < TOTAL_STEPS - 1:
		current_step += 1
		step_changed.emit(current_step)
	else:
		completed = true
		rhyme_completed.emit()

func restart() -> void:
	reset()
