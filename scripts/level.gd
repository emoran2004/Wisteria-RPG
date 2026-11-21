extends Node2D

# Wisteria: The Lily Pond - Godot 4.x
const WORLD_WIDTH := 2400.0
const FLOOR_Y := 460.0
const SPEED := 230.0
const JUMP_SPEED := -420.0
const GRAVITY := 1050.0

const POND_LEFT := 850.0
const POND_RIGHT := 1190.0
const WATER_Y := 462.0
const WATER_COLOR := Color("#83BFC9")
const WATER_LIGHT := Color("#B9E3E5")
const WATER_DARK := Color("#648FAE")
const SPAWN := Vector2(100, 380)

var water_time := 0.0

# Fairy realm decoration animation.
var nature_time := 0.0

# Decorative firefly positions.
var firefly_positions: Array[Vector2] = [
	Vector2(260, 310),
	Vector2(450, 260),
	Vector2(690, 300),
	Vector2(840, 250),
	Vector2(1100, 280),
	Vector2(1380, 290),
	Vector2(1660, 240),
	Vector2(1920, 310),
	Vector2(2150, 260)
]

var player: CharacterBody2D
var wisteria_sprite: AnimatedSprite2D
var frog: Area2D
var frog_start_x := 1450.0
var frog_time := 0.0
var petals := 0
var petal_nodes: Array[Area2D] = []
var crystal: Area2D
var won := false
var message := "Collect 3 petals, cross the lily pond, and rescue your friend!"
var camera: Camera2D
var hud: CanvasLayer
var hud_label: Label
var message_label: Label
var platforms: Array[StaticBody2D] = []
var lily_pads: Array[StaticBody2D] = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#DCC9E8"))

	# Two separate banks leave a real gap for the pond.
	build_platform(
		Vector2(POND_LEFT / 2.0, 510),
		Vector2(POND_LEFT, 100),
		Color("#597c60")
	)
	build_platform(
		Vector2((POND_RIGHT + WORLD_WIDTH) / 2.0, 510),
		Vector2(WORLD_WIDTH - POND_RIGHT, 100),
		Color("#597c60")
	)

	# Enchanted stone platforms.
	for data in [
		[500, 410, 160],
		[760, 350, 140],
		[1320, 410, 160],
		[1600, 380, 180],
		[1850, 400, 160]
	]:
		build_platform(
			Vector2(data[0], data[1]),
			Vector2(data[2], 22),
			Color("#7aa77d")
		)

	# Jumpable lily pads over the pond.
	for x in [895.0, 980.0, 1065.0, 1150.0]:
		var pad := build_platform(
			Vector2(x, 452),
			Vector2(70, 12),
			Color("#8EC59A")
		)
		pad.set_meta("lily_pad", true)
		lily_pads.append(pad)

	# Existing parallax background scene.
	var background_scene: PackedScene = load(
		"res://scenes/lily_pond_background.tscn"
	)
	if background_scene != null:
		var background = background_scene.instantiate()
		background.z_index = -10
		add_child(background)

	# Create Wisteria's collision body.
	player = CharacterBody2D.new()
	player.name = "Wisteria"
	player.position = SPAWN
	player.collision_layer = 1
	player.collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 42)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	player.add_child(collision)
	add_child(player)

	# Load Wisteria's animated character scene.
	var wisteria_scene: PackedScene = load(
		"res://scenes/wisteria_visual.tscn"
	)
	if wisteria_scene != null:
		var wisteria_visual: Node2D = wisteria_scene.instantiate()
		player.add_child(wisteria_visual)
		wisteria_sprite = wisteria_visual.get_node(
			"AnimatedSprite2D"
		)
		wisteria_sprite.position = Vector2(0, -20)
		wisteria_sprite.scale = Vector2(0.35, 0.35)
		wisteria_sprite.play("idle")

	# Camera follows Wisteria.
	camera = Camera2D.new()
	camera.position = Vector2(0, -80)
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 540
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6
	player.add_child(camera)
	camera.make_current()

	# Three magical petals.
	for pos in [
		Vector2(520, 360),
		Vector2(1030, 360),
		Vector2(1850, 350)
	]:
		var area := make_area(pos, Vector2(28, 28))
		petal_nodes.append(area)
		area.body_entered.connect(
			_on_petal_touched.bind(area)
		)

	# Frog enemy patrols the far bank.
	frog = make_area(
		Vector2(frog_start_x, 432),
		Vector2(54, 38)
	)
	frog.body_entered.connect(_on_frog_touched)

	# Crystal containing Wisteria's fairy friend.
	crystal = make_area(
		Vector2(2240, 420),
		Vector2(56, 75)
	)

	# HUD.
	hud = CanvasLayer.new()
	add_child(hud)

	hud_label = Label.new()
	hud_label.position = Vector2(20, 16)
	hud_label.add_theme_font_size_override("font_size", 22)
	hud.add_child(hud_label)

	message_label = Label.new()
	message_label.position = Vector2(20, 52)
	message_label.add_theme_font_size_override("font_size", 17)
	hud.add_child(message_label)

	update_hud()
	queue_redraw()


func build_platform(
	center: Vector2,
	size: Vector2,
	color: Color
) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)

	body.set_meta("size", size)
	body.set_meta("color", color)
	add_child(body)
	platforms.append(body)
	return body


func make_area(pos: Vector2, size: Vector2) -> Area2D:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	return area


func _physics_process(delta: float) -> void:
	water_time += delta
	nature_time += delta

	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
		return

	if not won:
		var direction := Input.get_axis("ui_left", "ui_right")
		if Input.is_key_pressed(KEY_A):
			direction = -1.0
		if Input.is_key_pressed(KEY_D):
			direction = 1.0

		player.velocity.x = direction * SPEED

		if not player.is_on_floor():
			player.velocity.y += GRAVITY * delta

		if player.is_on_floor() and (
			Input.is_action_just_pressed("ui_accept")
			or Input.is_key_pressed(KEY_W)
			or Input.is_key_pressed(KEY_UP)
		):
			player.velocity.y = JUMP_SPEED

		player.move_and_slide()
		update_wisteria_animation()

		# Falling into the pond triggers a respawn.
		if player.position.y > 525:
			respawn()

		# Frog patrol movement.
		frog_time += delta
		frog.position.x = (
			frog_start_x + sin(frog_time * 1.4) * 105.0
		)

		# Rescue the fairy after collecting all petals.
		if (
			player.global_position.distance_to(
				crystal.global_position
			) < 95.0
			and Input.is_key_pressed(KEY_E)
		):
			if petals == 3:
				won = true
				player.velocity = Vector2.ZERO
				message = "Fairy rescued! Chapter 1 complete. Press R to replay."
			else:
				message = "The crystal needs all three magical petals!"
			update_hud()

	queue_redraw()


func update_wisteria_animation() -> void:
	if not is_instance_valid(wisteria_sprite):
		return

	if not player.is_on_floor():
		if player.velocity.y < 0:
			wisteria_sprite.play("jump")
		else:
			wisteria_sprite.play("fall")
	elif abs(player.velocity.x) > 1:
		wisteria_sprite.play("walk")
	else:
		wisteria_sprite.play("idle")

	if player.velocity.x > 0:
		wisteria_sprite.flip_h = false
	elif player.velocity.x < 0:
		wisteria_sprite.flip_h = true


func respawn() -> void:
	player.position = SPAWN
	player.velocity = Vector2.ZERO
	message = "Try again! Watch your step around the pond."
	update_hud()


func _on_frog_touched(body: Node2D) -> void:
	if body == player and not won:
		respawn()


func _on_petal_touched(
	body: Node2D,
	area: Area2D
) -> void:
	if (
		body == player
		and is_instance_valid(area)
		and not area.is_queued_for_deletion()
	):
		petals += 1
		petal_nodes.erase(area)
		area.queue_free()
		message = "A magical petal! Keep exploring."
		update_hud()


func update_hud() -> void:
	hud_label.text = "WISTERIA  |  Petals: %d / 3" % petals
	message_label.text = message


func _draw() -> void:
	# Pond sits in the real gap between the banks.
	draw_magical_water()

	# Draw the mossy platforms and ground.
	for platform in platforms:
		if platform in lily_pads:
			continue
		var size: Vector2 = platform.get_meta("size")
		var top_left: Vector2 = platform.position - size / 2.0
		draw_mossy_platform(top_left, size)
	
	# Draw lily pads and decorative lotus flowers.
	for i in range(lily_pads.size()):
		var pad := lily_pads[i]

		draw_lily_pad(pad.position, 35.0)

		# Add flowers to alternating lily pads.
		if i % 2 == 0:
			draw_lotus_flower(
				pad.position + Vector2(-8, -5)
			)
	
	# Giant fairy-realm flowers.
	for x in [300.0, 620.0, 1430.0, 1750.0, 2100.0]:
		draw_giant_flower(
			Vector2(x, FLOOR_Y),
			x
		)

	# Mushrooms along the grassy banks.
	for x in [180.0, 570.0, 800.0, 1250.0, 1720.0, 2050.0]:
		draw_fairy_mushroom(
			Vector2(x, FLOOR_Y),
			1.0
		)

	# Pondside reeds.
	for x in [820.0, 850.0, 1190.0, 1220.0]:
		draw_pond_reeds(
			Vector2(x, FLOOR_Y)
		)

	# Animated fireflies.
	for i in range(firefly_positions.size()):
		draw_firefly(
			firefly_positions[i],
			float(i)
		)

	# Shoreline flowers on solid land.
	for i in range(35, int(WORLD_WIDTH), 90):
		if i > POND_LEFT - 20 and i < POND_RIGHT + 20:
			continue
		draw_line(
			Vector2(i, FLOOR_Y),
			Vector2(i, FLOOR_Y - 20),
			Color("#3f7556"),
			3
		)
		draw_circle(
			Vector2(i, FLOOR_Y - 23),
			6,
			Color("#d69abf")
		)

	# Collectible petals.
	for petal in petal_nodes:
		if is_instance_valid(petal):
			draw_circle(
				petal.position,
				13,
				Color("#f3d3ee")
			)
			draw_circle(
				petal.position,
				6,
				Color("#fff4bb")
			)

	# Frog enemy.
	if is_instance_valid(frog):
		draw_ellipse_simple(
			frog.position,
			Vector2(30, 20),
			Color("#5e9662")
		)
		draw_circle(
			frog.position + Vector2(-12, -14),
			9,
			Color("#77ae70")
		)
		draw_circle(
			frog.position + Vector2(12, -14),
			9,
			Color("#77ae70")
		)
		draw_circle(
			frog.position + Vector2(-12, -16),
			3,
			Color("#1e382a")
		)
		draw_circle(
			frog.position + Vector2(12, -16),
			3,
			Color("#1e382a")
		)

	# Fairy rescue crystal.
	if is_instance_valid(crystal):
		var c := crystal.position
		var crystal_color := Color("#ad83d5")
		if won:
			crystal_color = Color("#d6f5c8")

		draw_colored_polygon(
			PackedVector2Array([
				c + Vector2(0, -38),
				c + Vector2(25, -8),
				c + Vector2(0, 38),
				c + Vector2(-25, -8)
			]),
			crystal_color
		)
		draw_circle(c, 8, Color("#fff3d6"))


func draw_magical_water() -> void:
	# Water occupies only the pond gap.
	var pond_width := POND_RIGHT - POND_LEFT
	var pond_bottom := 540.0

	draw_rect(
		Rect2(
			POND_LEFT,
			WATER_Y,
			pond_width,
			pond_bottom - WATER_Y
		),
		WATER_COLOR
	)

	# Animated surface shimmer.
	for x in range(int(POND_LEFT), int(POND_RIGHT), 24):
		var wave_y := (
			WATER_Y
			+ sin(water_time * 2.0 + x * 0.04) * 2.0
		)
		draw_rect(
			Rect2(x, wave_y, 16, 3),
			WATER_LIGHT
		)

	# Ripples below the surface.
	for row in range(2):
		for i in range(5):
			var ripple_x := (
				POND_LEFT + 18 + i * 70
				+ sin(water_time + row) * 8.0
			)
			var ripple_y := WATER_Y + 22 + row * 22
			draw_rect(
				Rect2(ripple_x, ripple_y, 22, 2),
				WATER_DARK
			)

	# Shoreline edges.
	draw_rect(
		Rect2(POND_LEFT - 5, FLOOR_Y, 5, 24),
		Color("#668D70")
	)
	draw_rect(
		Rect2(POND_RIGHT, FLOOR_Y, 5, 24),
		Color("#668D70")
	)


func draw_ellipse_simple(
	center: Vector2,
	radii: Vector2,
	color: Color
) -> void:
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * i / 24.0
		pts.append(
			center + Vector2(
				cos(a) * radii.x,
				sin(a) * radii.y
			)
		)
	draw_colored_polygon(pts, color)


func draw_mossy_platform(
	pos: Vector2,
	size: Vector2
) -> void:
	var x := int(pos.x)
	var y := int(pos.y)
	var w := int(size.x)
	var h := int(size.y)

	# Dark purple outline.
	draw_rect(
		Rect2(x, y, w, h),
		Color("#51465E")
	)

	# Purple-gray stone body.
	draw_rect(
		Rect2(x + 3, y + 8, w - 6, h - 11),
		Color("#8D819D")
	)

	# Individual stone details.
	for i in range(0, w - 16, 24):
		var stone_x := x + i + 6

		draw_rect(
			Rect2(stone_x, y + 12, 15, 3),
			Color("#A99BB5")
		)
		draw_rect(
			Rect2(stone_x + 8, y + 18, 12, 2),
			Color("#6D637F")
		)

	# Dark green grass foundation.
	draw_rect(
		Rect2(x, y, w, 8),
		Color("#4F795F")
	)

	# Soft sage-green grass.
	draw_rect(
		Rect2(x + 2, y, w - 4, 5),
		Color("#86B88A")
	)

	# Light mint highlights.
	for i in range(0, w - 8, 16):
		draw_rect(
			Rect2(x + i + 4, y, 8, 2),
			Color("#C1DCA4")
		)

	# Hanging moss.
	for i in range(8, w - 4, 20):
		var moss_length := 5 + (i % 3) * 2
		draw_rect(
			Rect2(x + i, y + 7, 4, moss_length),
			Color("#668D70")
		)

	# Tiny pink flowers.
	if w >= 100:
		for i in range(35, w - 10, 85):
			var fx := x + i
			var fy := y - 5
			draw_circle(
				Vector2(fx, fy),
				4,
				Color("#E5A3CF")
			)
			draw_circle(
				Vector2(fx, fy),
				2,
				Color("#FFF1BB")
			)



func draw_lily_pad(pos: Vector2, size: float) -> void:
	# Dark green underside.
	draw_ellipse_simple(
		pos + Vector2(0, 5),
		Vector2(size, 8),
		Color("#487D68")
	)

	# Main lily pad.
	draw_ellipse_simple(
		pos,
		Vector2(size, 8),
		Color("#8EC59A")
	)

	# Soft mint-green highlight.
	draw_ellipse_simple(
		pos + Vector2(-6, -2),
		Vector2(size * 0.55, 4),
		Color("#B8DDAA")
	)

	# Small leaf vein.
	draw_line(
		pos + Vector2(-15, 0),
		pos + Vector2(12, 0),
		Color("#74AA82"),
		2
	)

func draw_lotus_flower(pos: Vector2) -> void:
	# Dark green stem.
	draw_line(
		pos + Vector2(0, 7),
		pos + Vector2(0, -5),
		Color("#487D68"),
		3
	)

	# Outer pink petals.
	draw_ellipse_simple(
		pos + Vector2(-8, -5),
		Vector2(6, 9),
		Color("#E9A9D1")
	)

	draw_ellipse_simple(
		pos + Vector2(8, -5),
		Vector2(6, 9),
		Color("#E9A9D1")
	)

	# Taller inner petals.
	draw_ellipse_simple(
		pos + Vector2(-4, -10),
		Vector2(5, 10),
		Color("#F5C6E4")
	)

	draw_ellipse_simple(
		pos + Vector2(4, -10),
		Vector2(5, 10),
		Color("#F5C6E4")
	)

	# Center petal.
	draw_ellipse_simple(
		pos + Vector2(0, -12),
		Vector2(5, 11),
		Color("#FFE0F0")
	)

	# Golden center.
	draw_circle(
		pos + Vector2(0, -5),
		3,
		Color("#FFF0AE")
	)

func draw_giant_flower(pos: Vector2, seed: float) -> void:
	var height := 100.0 + fmod(seed, 40.0)
	var sway := sin(nature_time * 0.6 + seed) * 5.0

	var flower_center := pos + Vector2(sway, -height)

	# Thick green stem.
	draw_line(
		pos,
		flower_center,
		Color("#5B8B70"),
		7
	)

	# Large leaves.
	draw_ellipse_simple(
		pos + Vector2(-20, -45),
		Vector2(25, 9),
		Color("#80B694")
	)

	draw_ellipse_simple(
		pos + Vector2(20, -65),
		Vector2(25, 9),
		Color("#A2CFA8")
	)

	# Five oversized petals.
	for i in range(5):
		var angle := TAU * float(i) / 5.0
		var offset := Vector2(
			cos(angle) * 22,
			sin(angle) * 22
		)

		draw_circle(
			flower_center + offset,
			19,
			Color("#E8B3D8")
		)

	# Inner flower.
	draw_circle(
		flower_center,
		15,
		Color("#FFF0BC")
	)

	draw_circle(
		flower_center,
		7,
		Color("#E9C57D")
	)

func draw_fairy_mushroom(pos: Vector2, scale_factor: float) -> void:
	var stem_height := 25.0 * scale_factor
	var cap_width := 23.0 * scale_factor

	# Mushroom stem.
	draw_rect(
		Rect2(
			pos.x - 5 * scale_factor,
			pos.y - stem_height,
			10 * scale_factor,
			stem_height
		),
		Color("#F3E6D7")
	)

	# Purple mushroom cap.
	draw_ellipse_simple(
		pos + Vector2(0, -stem_height),
		Vector2(cap_width, 13 * scale_factor),
		Color("#A88BC5")
	)

	# Pink cap highlight.
	draw_ellipse_simple(
		pos + Vector2(-4, -stem_height - 5),
		Vector2(13 * scale_factor, 5 * scale_factor),
		Color("#D9B5DD")
	)

	# White mushroom spots.
	draw_circle(
		pos + Vector2(-9, -stem_height - 3),
		3 * scale_factor,
		Color("#FFF0F6")
	)

	draw_circle(
		pos + Vector2(7, -stem_height - 6),
		2.5 * scale_factor,
		Color("#FFF0F6")
	)

func draw_pond_reeds(pos: Vector2) -> void:
	for i in range(4):
		var x_offset := float(i * 9 - 14)
		var height := 35.0 + float(i % 3) * 12.0

		var start := pos + Vector2(x_offset, 0)
		var tip := start + Vector2(
			sin(nature_time + float(i)) * 4.0,
			-height
		)

		# Thin green reed.
		draw_line(
			start,
			tip,
			Color("#548B72"),
			3
		)

		# Cattail flower.
		draw_ellipse_simple(
			tip,
			Vector2(4, 10),
			Color("#8A6580")
		)

func draw_firefly(pos: Vector2, offset: float) -> void:
	var float_x := sin(nature_time * 1.2 + offset) * 14.0
	var float_y := cos(nature_time * 1.5 + offset) * 9.0

	var fly_pos := pos + Vector2(float_x, float_y)

	# Flickering brightness.
	var brightness := (
		sin(nature_time * 3.0 + offset * 2.0) + 1.0
	) / 2.0

	# Soft outer glow.
	draw_circle(
		fly_pos,
		9,
		Color(1.0, 0.92, 0.65, 0.10 + brightness * 0.15)
	)

	# Inner glow.
	draw_circle(
		fly_pos,
		5,
		Color(1.0, 0.95, 0.70, 0.35 + brightness * 0.3)
	)

	# Bright center.
	draw_circle(
		fly_pos,
		2,
		Color("#FFF8CE")
	)
