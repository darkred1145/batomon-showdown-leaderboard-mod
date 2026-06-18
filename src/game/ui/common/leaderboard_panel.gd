class_name LeaderboardPanel
extends PanelContainer

signal close_requested

@onready var anim_player: AnimationPlayer = $AnimationPlayer

const TIER_LABELS := {
	"bronze": "Bronze", "silver": "Silver", "gold": "Gold",
	"platinum": "Platinum", "diamond": "Diamond", "master": "Master",
}
const TIER_COLORS := {
	"bronze": Color(0.8, 0.5, 0.2),
	"silver": Color(0.7, 0.7, 0.75),
	"gold": Color(1.0, 0.84, 0.0),
	"platinum": Color(0.4, 0.9, 0.85),
	"diamond": Color(0.3, 0.6, 1.0),
	"master": Color(1.0, 0.3, 0.3),
}

var title_label: Label
var rank_summary_label: Label
var stats_label: Label
var leaderboard_header: Label
var scroll_container: ScrollContainer
var list_container: VBoxContainer
var loading_label: Label
var local_note: Label
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

	rank_summary_label = Label.new()
	rank_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_summary_label.add_theme_font_size_override("font_size", 16)
	rank_summary_label.add_theme_color_override("font_color", Color(0, 0, 0))
	rank_summary_label.visible = false
	vbox.add_child(rank_summary_label)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	stats_label.visible = false
	vbox.add_child(stats_label)

	vbox.add_child(HSeparator.new())

	leaderboard_header = Label.new()
	leaderboard_header.text = "Master Tier Rankings"
	leaderboard_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_header.add_theme_font_size_override("font_size", 16)
	leaderboard_header.add_theme_color_override("font_color", Color(0, 0, 0))
	vbox.add_child(leaderboard_header)

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

	local_note = Label.new()
	local_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	local_note.add_theme_font_size_override("font_size", 14)
	local_note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	local_note.visible = false
	list_container.add_child(local_note)

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
	local_note.visible = false

	for c in list_container.get_children():
		if c != loading_label and c != local_note:
			list_container.remove_child(c)
			c.queue_free()

	rank_summary_label.visible = false
	stats_label.visible = false

	_show_user_stats()

	if anim_player.has_animation("show"):
		anim_player.play("show")

	_fetch_pending = true
	_start_fetch()


func _show_user_stats():
	var user = UserManager.data
	if user == null:
		rank_summary_label.text = "No player data available"
		rank_summary_label.visible = true
		return

	var name_display = user.display_name
	if name_display == "":
		name_display = "Player"

	var tier_id = user.rank_tier
	var tier_label = TIER_LABELS.get(tier_id, tier_id.capitalize())
	var tier_color = TIER_COLORS.get(tier_id, Color(0, 0, 0))
	var sub = user.rank_sub
	var stars = user.rank_stars

	if tier_id == "master":
		rank_summary_label.text = "%s — Master (MMR: %d)" % [name_display, user.ranked_mmr]
	else:
		rank_summary_label.text = "%s — %s %d (%d★) — MMR: %d" % [name_display, tier_label, sub, stars, user.ranked_mmr]
	rank_summary_label.visible = true

	stats_label.text = "Wins: %d  /  Games: %d  —  Win Rate: %d%%" % [user.runs_won, user.games_played, int(float(user.runs_won) / max(user.games_played, 1) * 100)]
	stats_label.visible = true


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
		_on_fetch_done([])
		return

	var timer := get_tree().create_timer(10.0)
	timer.timeout.connect(_on_fetch_timeout)

	var lb = await provider.get_master_leaderboard(200)
	if not _fetch_pending:
		return
	_fetch_pending = false
	timer.stop()
	_on_fetch_done(lb)


func _on_fetch_timeout():
	if not _fetch_pending:
		return
	_fetch_pending = false
	_on_fetch_done([])


func _on_fetch_done(lb: Array):
	loading_label.visible = false

	if lb.is_empty():
		leaderboard_header.text = "Master Tier Rankings"
		local_note.text = "Leaderboard available online in the full game"
		local_note.visible = true
		return

	var user = UserManager.data
	var current_user_id := ""
	if user != null and user.has_method("_get_user_id"):
		current_user_id = "local_player"

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
		leaderboard_header.text = "Master Tier Rankings — Your Position: #%d" % my_pos


func _on_done():
	_fetch_pending = false
	if anim_player.has_animation("hide"):
		anim_player.play("hide")
		await anim_player.animation_finished
	visible = false
	close_requested.emit()
