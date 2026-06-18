class_name LeaderboardPanel
extends PanelContainer

signal close_requested

@onready var anim_player: AnimationPlayer = $AnimationPlayer

var title_label: Label
var your_rank_label: Label
var scroll_container: ScrollContainer
var list_container: VBoxContainer
var loading_label: Label
var error_label: Label
var done_button: Button

const TROPHY_ICON := preload("res://assets/ui/textures/dex/trophy_icon.png")
const GOLD_ICON := preload("res://assets/ui/textures/ranked/gold_icon.png")
const SILVER_ICON := preload("res://assets/ui/textures/ranked/silver_icon.png")
const BRONZE_ICON := preload("res://assets/ui/textures/ranked/bronze_icon.png")

var _fetch_pending := false


func _ready():
	visible = false

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var trophy_holder := CenterContainer.new()
	var trophy := TextureRect.new()
	trophy.texture = TROPHY_ICON
	trophy.custom_minimum_size = Vector2(32, 32)
	trophy.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy_holder.add_child(trophy)
	vbox.add_child(trophy_holder)

	title_label = Label.new()
	title_label.text = "Leaderboard"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0, 0, 0))
	vbox.add_child(title_label)

	vbox.add_child(HSeparator.new())

	your_rank_label = Label.new()
	your_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	your_rank_label.add_theme_font_size_override("font_size", 16)
	your_rank_label.add_theme_color_override("font_color", Color(0, 0, 0))
	vbox.add_child(your_rank_label)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_container)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(list_container)

	loading_label = Label.new()
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.text = "Loading..."
	loading_label.add_theme_font_size_override("font_size", 18)
	loading_label.add_theme_color_override("font_color", Color(0, 0, 0))
	list_container.add_child(loading_label)

	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	error_label.visible = false
	list_container.add_child(error_label)

	vbox.add_child(HSeparator.new())

	done_button = load("res://game/ui/common/menu_button.tscn").instantiate()
	done_button.text = "Done"
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done_button.pressed.connect(_on_done)
	vbox.add_child(done_button)

	_update_position()
	get_window().size_changed.connect(_update_position)


func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_done()


func show_leaderboard():
	_update_position()
	pivot_offset = size / 2.0
	scale = Vector2(1, 1)
	visible = true

	loading_label.visible = true
	loading_label.text = "Loading..."
	error_label.visible = false

	for c in list_container.get_children():
		if c != loading_label and c != error_label:
			list_container.remove_child(c)
			c.queue_free()

	your_rank_label.text = ""

	if anim_player.has_animation("show"):
		anim_player.play("show")

	_fetch_pending = true
	_start_fetch()


func _update_position():
	var vs := get_viewport_rect().size
	var pw := min(vs.x * 0.85, 640.0)
	var ph := min(vs.y * 0.85, 600.0)
	custom_minimum_size = Vector2(pw, 0)
	size = Vector2(pw, ph)
	position = Vector2((vs.x - pw) / 2, (vs.y - ph) / 2)


func _start_fetch():
	var provider = RunManager.data_provider
	if provider == null or not provider.has_method("get_master_leaderboard"):
		_show_error("Data provider not available")
		_fetch_pending = false
		return

	var timer := get_tree().create_timer(10.0)
	timer.timeout.connect(_on_fetch_timeout)

	var lb = await provider.get_master_leaderboard(200)
	if not _fetch_pending:
		return
	_fetch_pending = false
	timer.stop()

	loading_label.visible = false
	if lb.is_empty():
		_show_error("Could not load leaderboard")
		return
	_populate_list(lb)


func _on_fetch_timeout():
	if not _fetch_pending:
		return
	_fetch_pending = false
	loading_label.visible = false
	_show_error("Request timed out")


func _populate_list(lb: Array):
	var current_user_id: String = ""
	if UserManager.data != null and UserManager.data.has("user_id"):
		current_user_id = UserManager.data["user_id"]

	var my_pos := 0
	for i in range(lb.size()):
		var entry = lb[i]
		var rank_num = i + 1
		var user_id = entry.get("user_id", "")
		var display_name = entry.get("display_name", "Unknown")
		var mmr = entry.get("ranked_mmr", 0)

		if user_id == current_user_id:
			my_pos = rank_num

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 24)

		var rank_label: Control
		if rank_num <= 3:
			var icon := TextureRect.new()
			match rank_num:
				1: icon.texture = GOLD_ICON
				2: icon.texture = SILVER_ICON
				3: icon.texture = BRONZE_ICON
			icon.custom_minimum_size = Vector2(22, 22)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rank_label = icon
			rank_label.custom_minimum_size = Vector2(40, 0)
		else:
			rank_label = Label.new()
			rank_label.text = "#%d" % rank_num
			rank_label.custom_minimum_size = Vector2(40, 0)
			rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rank_label.add_theme_color_override("font_color", Color(0, 0, 0))

		var name_label := Label.new()
		name_label.text = display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_color_override("font_color", Color(0, 0, 0))

		var mmr_label := Label.new()
		mmr_label.text = str(mmr)
		mmr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mmr_label.custom_minimum_size = Vector2(60, 0)
		mmr_label.add_theme_color_override("font_color", Color(0, 0, 0))

		if user_id == current_user_id:
			if rank_label is Label:
				rank_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			name_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			mmr_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			var arrow := Label.new()
			arrow.text = " <-- You"
			arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			row.add_child(rank_label)
			row.add_child(name_label)
			row.add_child(mmr_label)
			row.add_child(arrow)
		else:
			row.add_child(rank_label)
			row.add_child(name_label)
			row.add_child(mmr_label)

		list_container.add_child(row)

	if my_pos > 0:
		your_rank_label.text = "Your Rank: #%d" % my_pos
	else:
		var user_mmr = UserManager.data.ranked_mmr if UserManager.data != null else 0
		if user_mmr > 0:
			your_rank_label.text = "Your MMR: %d (outside top %d)" % [user_mmr, lb.size()]
		else:
			your_rank_label.text = "Complete a ranked run to appear on the leaderboard"


func _show_error(msg: String):
	loading_label.visible = false
	error_label.text = msg
	error_label.visible = true


func _on_done():
	_fetch_pending = false
	if anim_player.has_animation("hide"):
		anim_player.play("hide")
		await anim_player.animation_finished
	visible = false
	close_requested.emit()
