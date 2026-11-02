class_name ScreenLayout
extends RefCounted

# Android reports physical pixels; containers use the expanded logical viewport.
static func safe_insets(safe_area: Rect2, window: Rect2, logical_size: Vector2) -> Vector4i:
	if window.size.x <= 0 or window.size.y <= 0 or not safe_area.has_area():
		return Vector4i.ZERO
	var visible := safe_area.intersection(window)
	if not visible.has_area(): return Vector4i.ZERO
	var scale := logical_size / window.size
	return Vector4i(
		ceili((visible.position.x - window.position.x) * scale.x),
		ceili((visible.position.y - window.position.y) * scale.y),
		ceili((window.end.x - visible.end.x) * scale.x),
		ceili((window.end.y - visible.end.y) * scale.y))
