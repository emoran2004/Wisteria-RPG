
extends Node2D

const SKY = Color("#DCC9E8")
const DISTANT_HILLS = Color("#B6B6D6")
const TREES = Color("#91B6AE")
const TREE_TRUNKS = Color("#758F8A")

func _draw() -> void:
	# Lavender sky
	draw_rect(Rect2(-500, -500, 5000, 1100), SKY)

	# Distant hills
	for i in range(-300, 4000, 220):
		draw_circle(
			Vector2(i, 380),
			160,
			DISTANT_HILLS
		)

	# Distant trees
	for i in range(-100, 4000, 160):
		draw_rect(
			Rect2(i + 35, 250, 22, 230),
			TREE_TRUNKS
		)

		draw_circle(
			Vector2(i + 45, 220),
			85,
			TREES
		)

		draw_circle(
			Vector2(i, 255),
			55,
			TREES
		)

		draw_circle(
			Vector2(i + 90, 255),
			55,
			TREES
		)
