class_name SaveStore
extends RefCounted
## Checksummed JSON, atomic replacement, last-good backup, and version gating.

const VERSION: int = 1
const DEFAULT_PATH: String = "user://burrow-v1.json"
const MAX_BYTES: int = 64 * 1024 * 1024


static func write_save(data: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var payload: String = JSON.stringify(data)
	var envelope: Dictionary = {"version": VERSION, "payload": payload, "sha256": payload.sha256_text()}
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope))
	file.flush()
	file.close()
	var absolute: String = ProjectSettings.globalize_path(path)
	var backup: String = absolute + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			var remove_error: Error = DirAccess.remove_absolute(backup)
			if remove_error != OK: return remove_error
		var backup_error: Error = DirAccess.rename_absolute(absolute, backup)
		if backup_error != OK: return backup_error
	var replace_error: Error = DirAccess.rename_absolute(absolute + ".tmp", absolute)
	if replace_error != OK and FileAccess.file_exists(path + ".bak"):
		DirAccess.rename_absolute(backup, absolute)
	return replace_error


static func read_save(path: String = DEFAULT_PATH) -> Dictionary:
	var result: Dictionary = _read_checked(path)
	if result.is_empty(): result = _read_checked(path + ".bak")
	return result


static func exists(path: String = DEFAULT_PATH) -> bool:
	return not read_save(path).is_empty()


static func _read_checked(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {}
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK: return {}
	var envelope_value: Variant = parser.data
	if not envelope_value is Dictionary: return {}
	var envelope: Dictionary = envelope_value as Dictionary
	if int(envelope.get("version", 0)) != VERSION: return {}
	var payload_value: Variant = envelope.get("payload", null)
	if not payload_value is String: return {}
	var payload: String = payload_value as String
	if payload.sha256_text() != String(envelope.get("sha256", "")): return {}
	if parser.parse(payload) != OK: return {}
	var data: Variant = parser.data
	return data as Dictionary if data is Dictionary else {}
