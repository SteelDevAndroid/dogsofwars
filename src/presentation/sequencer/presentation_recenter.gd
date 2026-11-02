# A step of the sequence that brings the camera to a tile (the first step of a ruin reading).
class_name PresentationRecenter
extends PresentationEvent

var tile: int


func _init(p_tile: int) -> void:
	tile = p_tile
