## PlayerPreferences owns options that apply outside one saved case.
## CaseLocale owns language; GameState owns investigation progress. Keeping these
## three responsibilities separate makes a Continue action deterministic.
extends Node

signal guidance_changed(enabled: bool)

const PREFERENCE_PATH := "user://shadow_castle_preferences.cfg"
const GUIDANCE_SECTION := "guidance"
const GUIDANCE_ENABLED_KEY := "field_prompts_enabled"

var field_prompts_enabled := true


func _ready() -> void:
	field_prompts_enabled = _load_field_prompts_enabled()


func set_field_prompts_enabled(enabled: bool) -> void:
	if field_prompts_enabled == enabled:
		return
	field_prompts_enabled = enabled
	_save_field_prompts_enabled()
	guidance_changed.emit(field_prompts_enabled)


func toggle_field_prompts() -> void:
	set_field_prompts_enabled(not field_prompts_enabled)


func _load_field_prompts_enabled() -> bool:
	var config := ConfigFile.new()
	if config.load(PREFERENCE_PATH) != OK:
		return true
	return bool(config.get_value(GUIDANCE_SECTION, GUIDANCE_ENABLED_KEY, true))


func _save_field_prompts_enabled() -> void:
	var config := ConfigFile.new()
	# Preserve the language preference written by CaseLocale in the same file.
	config.load(PREFERENCE_PATH)
	config.set_value(GUIDANCE_SECTION, GUIDANCE_ENABLED_KEY, field_prompts_enabled)
	config.save(PREFERENCE_PATH)
