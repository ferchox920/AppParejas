class_name InvitationService
extends Node

## Adapters answer every request once. IDs let the controller ignore late answers.
## Production adapters must obtain the actor from Auth, never trust payload.user_id.
signal completed(request_id: int, result: Dictionary)

func request(_operation: String, _payload: Dictionary, request_id: int) -> void:
	completed.emit(request_id, {"ok": false, "error": "unavailable"})
