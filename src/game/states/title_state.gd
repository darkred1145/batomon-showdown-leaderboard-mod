class_name TitleState
extends GameState

signal _startup_checks_finished

@export var music: AudioStream
@export var game_start_sfx: SoundEffect

var _waiting_for_any_input = false

# Identity gate: when no session was restored at boot, the title shows its on-screen login
# row (bottom third) in place of the "press any key" prompt, and the identity-dependent
# startup checks are deferred until a provider login succeeds. Set from enter() data.
var _needs_login := false

# Guards _run_startup_checks() so the identity-dependent probes run exactly once, whether
# they're kicked off in enter() (already logged in) or after an on-screen login.
var _startup_checks_started := false

# Save data peeked when Continue is pressed, held until the player confirms or
# cancels the save-info popup. Committed as the active run only on confirm.
var _pending_save_data: RunData = null

# Mode chosen for a new run, held while the player confirms overwriting any
# existing save (the overwrite warning appears after mode-select).
var _pending_new_run_ranked: bool = false

# The in-progress save the player is about to overwrite, peeked for the warning.
# Held so that on confirm we can settle a ranked save before discarding it.
var _pending_overwrite_save: RunData = null

# Result of the connectivity / maintenance probe. Populated by _ready().
var _startup_checks_done: bool = false
var _block_reason_title: String = ""
var _block_reason_message: String = ""

@onready var continue_button := $CanvasLayer/TitleMenu/MarginContainer/VBoxContainer/ContinueButton
@onready var new_run_button := $CanvasLayer/TitleMenu/MarginContainer/VBoxContainer/NewRunButton
@onready var dex_button := $CanvasLayer/TitleMenu/MarginContainer/VBoxContainer/DexButton
@onready var settings_button := $CanvasLayer/TitleMenu/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button := $CanvasLayer/TitleMenu/MarginContainer/VBoxContainer/QuitButton
@onready var anim_player := $CanvasLayer/AnimationPlayer
@onready var title_menu := $CanvasLayer/TitleMenu
@onready var title_menu_anim_player := $CanvasLayer/MenuAnimationPlayer
@onready var settings_menu := $CanvasLayer/SettingsMenu
@onready var press_any_key_label := $CanvasLayer/PressAnyKeyLabel
@onready var blocking_popup := $CanvasLayer/BlockingPopup
@onready var dex_ui := $CanvasLayer/DexContainer/DexUI
@onready var dex_bg := $CanvasLayer/DexContainer/DexBG
@onready var mode_select_menu := $CanvasLayer/ModeSelectMenu
@onready var mode_select_anim := $CanvasLayer/ModeSelectMenu/ModeSelectMenuAnimation
@onready var ranked_mode_button := $CanvasLayer/ModeSelectMenu/MarginContainer/VBoxContainer/RankedModeButton
@onready var casual_mode_button := $CanvasLayer/ModeSelectMenu/MarginContainer/VBoxContainer/CasualModeButton
@onready var cancel_mode_button := $CanvasLayer/ModeSelectMenu/MarginContainer/VBoxContainer/CancelButton
@onready var ranked_icon: RankedIcon = $CanvasLayer/RightSideBar/RankedIcon
@onready var save_info_popup: SaveInfoPopup = $CanvasLayer/SaveInfoPopup
@onready var confirm_popup: ConfirmPopup = $CanvasLayer/ConfirmPopup
@onready var rank_change_popup: RankChangePopup = $CanvasLayer/RankChangePopup
@onready var screen_cover := $CanvasLayer/ScreenCover

var leaderboard_panel
var leaderboard_button: Button
var _leaderboard_scene = load("res://game/ui/common/leaderboard_panel.tscn")

# On-screen login gate (shown only when no session was restored at boot). The provider
# buttons reuse the menu_button theme.
@onready var login_panel := $CanvasLayer/LoginPanel
@onready var steam_login_button: Button = $CanvasLayer/LoginPanel/ButtonRow/SteamButton
@onready var google_login_button: Button = $CanvasLayer/LoginPanel/ButtonRow/GoogleButton
@onready var apple_login_button: Button = $CanvasLayer/LoginPanel/ButtonRow/AppleButton
@onready var login_status_label: Label = $CanvasLayer/LoginPanel/StatusLabel

# Fully opaque dark used by the ScreenCover; matches the transition_in keyframe.
const SCREEN_COVER_OPAQUE := Color(0.054902, 0.054902, 0.054902, 1.0)

# Vertical padding kept between the save-info popup's bottom and the confirm
# popup's top in the overwrite-warning flow.
const OVERWRITE_POPUP_GAP := 8.0

# Fail-safe ceiling on how long the reveal waits for the identity-dependent startup checks
# (_run_startup_checks) before letting the player into the menu anyway. The requests in that
# chain are individually timeout-bounded, but on a lossy connection their retries can sum past
# any fixed wall-clock wait, so this watchdog is NON-BLOCKING: if it fires we reveal the menu
# rather than the connect-error popup (see _reveal_after_checks for why). It exists only so a
# genuinely wedged chain can't strand the player on the title forever with no input.
const STARTUP_CHECKS_WATCHDOG_SEC := 30.0

func enter(data: Dictionary = {}):
	continue_button.disabled = false
	new_run_button.disabled = false

	# When a session was restored at boot the title behaves exactly as before; otherwise the
	# login row replaces the "press any key" prompt and the identity-dependent checks wait for
	# a successful login (default true so any caller that omits the flag keeps old behavior).
	_needs_login = not data.get("logged_in", true)

	# Cover the screen opaque before the first frame renders, otherwise the title
	# background flashes for a frame on entry. Two things are forced here because
	# the animation alone can't guarantee frame-0 coverage:
	#  * color — transition_in only keys ScreenCover's color at t=0.5, so a direct
	#    write lands it this frame instead of relying on keyframe timing.
	#  * size — ScreenCover is a full-rect-anchored ColorRect (min size 0); its
	#    size from anchors isn't resolved until the first deferred layout pass, so
	#    on frame 0 it covers nothing while the title's TextureRect background
	#    (intrinsic size) already draws. Fill the viewport now so it covers.
	screen_cover.visible = true
	screen_cover.color = SCREEN_COVER_OPAQUE
	screen_cover.position = Vector2.ZERO
	screen_cover.size = screen_cover.get_viewport_rect().size

	anim_player.play("transition_in")
	anim_player.animation_finished.connect(_on_anim_finished)

	# Start music
	AudioManager.play_music(music)

	# Already logged in: run the identity-dependent probes now, in parallel with the intro
	# animation (as before). When a login is still needed they run after it succeeds instead.
	if not _needs_login:
		_run_startup_checks()

func _ready():
	# Hide button by default (while we check for save file)
	continue_button.visible = false

	# Identity-independent wiring — safe to do before any login. The identity-dependent
	# probes (user profile, connectivity, save-file, dex) live in _run_startup_checks(),
	# which runs in enter() when already logged in or after an on-screen login otherwise.
	save_info_popup.confirmed.connect(_on_save_info_confirmed)
	save_info_popup.cancelled.connect(_on_save_info_cancelled)
	confirm_popup.confirmed.connect(_on_overwrite_confirmed)
	confirm_popup.cancelled.connect(_on_overwrite_cancelled)

	continue_button.pressed.connect(_on_continue_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	dex_button.pressed.connect(_on_dex_pressed)
	# The dex's own close (X) button replaces the old separate "Done" button.
	dex_ui.close_requested.connect(_on_dex_done_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	ranked_mode_button.pressed.connect(_on_ranked_mode_pressed)
	casual_mode_button.pressed.connect(_on_casual_mode_pressed)
	cancel_mode_button.pressed.connect(_on_mode_select_cancel_pressed)

	# Leaderboard button added programmatically to the title menu
	var menu_vbox = $CanvasLayer/TitleMenu/MarginContainer/VBoxContainer
	var settings_idx = 0
	for i in range(menu_vbox.get_child_count()):
		if menu_vbox.get_child(i) == settings_button:
			settings_idx = i
			break
	leaderboard_button = load("res://game/ui/common/menu_button.tscn").instantiate()
	leaderboard_button.text = "Leaderboard"
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	menu_vbox.add_child(leaderboard_button)
	menu_vbox.move_child(leaderboard_button, settings_idx)

	leaderboard_panel = _leaderboard_scene.instantiate()
	leaderboard_panel.close_requested.connect(_on_leaderboard_closed)
	$CanvasLayer.add_child(leaderboard_panel)

	# Login row (hidden unless the boot gate found no session — see _show_login_panel).
	steam_login_button.pressed.connect(_on_login_provider_pressed.bind(AuthManager.Provider.STEAM))
	google_login_button.pressed.connect(_on_login_provider_pressed.bind(AuthManager.Provider.GOOGLE))
	apple_login_button.pressed.connect(_on_login_provider_pressed.bind(AuthManager.Provider.APPLE))
	login_status_label.text = ""

# Identity-dependent boot probes. Runs once (guarded). Mirrors the old _ready() body:
# loads the user profile, sets up the ranked icon, probes connectivity/maintenance, checks
# for a saved run, and populates the dex — then signals completion so the reveal can proceed.
func _run_startup_checks() -> void:
	if _startup_checks_started:
		return
	_startup_checks_started = true

	# Load/create user data
	await UserManager.initialize_user()

	# The rank icon only surfaces after the player has finished at least one
	# ranked run — pre-unlock the right sidebar shouldn't advertise it.
	if UserManager.has_tutorial_flag("played_ranked_run"):
		# Refresh master leaderboard position so the label has a number to show.
		if RankSystem.is_master(UserManager.data):
			await UserManager.refresh_master_rank()
		ranked_icon.set_user(UserManager.data)
	else:
		ranked_icon.visible = false

	# Probe the backend before doing anything that touches the network.
	# If the server is unreachable or in maintenance, we block the menu
	# entirely and surface a popup at the end of the intro animation.
	var connectivity = await RunManager.data_provider.check_connectivity()
	if not connectivity.get("ok", true):
		_block_reason_title = tr("ui.error.cannot_connect.title")
		_block_reason_message = tr("ui.error.cannot_connect.body")
	elif connectivity.get("maintenance", false):
		_block_reason_title = tr("ui.maintenance.title")
		var server_msg: String = connectivity.get("message", "")
		_block_reason_message = server_msg if server_msg != "" else tr("ui.maintenance.default_body")

	# Only check for a saved run when the backend is healthy — otherwise the
	# save-file probe would hang on the same dead connection.
	if _block_reason_title == "":
		var has_save = await RunManager.check_for_save_file()
		continue_button.visible = has_save

	# Dex is only meaningful after the player has finished a run
	dex_button.visible = UserManager.data.games_played > 0
	dex_ui.populate(UserManager.data)

	_startup_checks_done = true
	_startup_checks_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if !_waiting_for_any_input:
		return

	# When any key is pressed, show the title menu
	if event.is_pressed():
		_waiting_for_any_input = false
		title_menu.visible = true
		press_any_key_label.visible = false

		title_menu_anim_player.play("show")

func _on_continue_pressed():
	# Peek the save file so the popup can summarise the run before we commit it
	# as the active run (that only happens once the player confirms). load_run()
	# is a full provider fetch (a network round-trip on PocketBase/Firebase), so
	# disable the whole menu for the duration — otherwise the other buttons stay
	# live and the player can start another flow mid-fetch.
	_set_menu_buttons_disabled(true)
	_pending_save_data = await RunManager.data_provider.load_run()

	if _pending_save_data == null:
		print("Error: Save file was corrupt or missing.")
		_set_menu_buttons_disabled(false)
		return

	save_info_popup.populate(_pending_save_data)
	# Hide the title menu outright (no animation) while the popup animates in,
	# so the two panels don't slide past each other (mirrors mode-select).
	title_menu.visible = false
	save_info_popup.show_popup()

func _on_save_info_confirmed():
	await save_info_popup.hide_popup()

	anim_player.play("fade_out")
	AudioManager.fade_out_music(3.0)
	await anim_player.animation_finished

	# Commit the already-peeked save as the active run (no second provider hit).
	var success = RunManager.commit_loaded_run(_pending_save_data)
	_pending_save_data = null

	if success:
		# A run saved mid-battle re-enters that exact fight: the stored opponent is
		# already nerfed and the sim is deterministic, so it re-resolves to the same
		# outcome (a fatal loss goes straight to the run summary) — quitting
		# mid-battle can't dodge the result. Checked first; the marker only exists
		# between battle entry and the ghost-sim commit.
		if not RunManager.data.pending_battle_opponent.is_empty():
			var resumed_opponent := RunData.from_dictionary(RunManager.data.pending_battle_opponent)
			request_transition("battle", {"opponent_data": resumed_opponent, "is_resume": true})
		# A run saved before its trainer was picked (new run abandoned at the
		# trainer-select screen) resumes back into trainer select, where it
		# reuses its locked pending_trainer_options.
		elif RunManager.data.trainer_id == "":
			request_transition("trainer_select")
		# Check for pending rewards first
		elif not RunManager.data.pending_reward.is_empty():
			request_transition("trinket_select")
		# Load into event if event is pending
		elif RunManager.data.pending_event_id != "":
			request_transition("event")
		else:
			request_transition("shop")
	else:
		print("Error: Save file was corrupt or missing.")

func _on_save_info_cancelled():
	# Hide the popup outright (no animation) while the title menu animates back
	# in, so the two panels don't slide past each other (mirrors mode-select).
	save_info_popup.visible = false
	_pending_save_data = null
	_set_menu_buttons_disabled(false)
	# keep_sidebar variant: the sidebars never left, so don't re-slide them.
	title_menu_anim_player.play("show_keep_sidebar")

func _on_new_run_pressed():
	# Disable the whole menu: the no-wins path below awaits a full save fetch
	# (load_run, a network round-trip) while the title menu is still visible.
	_set_menu_buttons_disabled(true)

	var has_wins := UserManager.data != null and UserManager.data.runs_won > 0

	if has_wins:
		# Player has won at least once — let them choose the mode first. The
		# overwrite check happens after they pick (in _begin_new_run).
		# Hide the title menu outright (no animation) while the mode-select panel
		# animates in, so the two panels don't slide past each other.
		title_menu.visible = false
		mode_select_menu.visible = true
		if mode_select_anim.has_animation("show"):
			mode_select_anim.play("show")
		return

	# Ranked is gated on a prior win. New players skip mode-select entirely, so
	# go straight to the overwrite check (or the run) in casual.
	_begin_new_run(false)

func _on_ranked_mode_pressed():
	await _hide_mode_select()
	_begin_new_run(true)

func _on_casual_mode_pressed():
	await _hide_mode_select()
	_begin_new_run(false)

# Starts a new run in the given mode, first making the player confirm if a run
# is already saved (so we don't silently abandon it).
func _begin_new_run(is_ranked: bool) -> void:
	_pending_new_run_ranked = is_ranked

	# Peek the save so the popup can summarise the run that's at stake.
	var save_data: RunData = await RunManager.data_provider.load_run()
	if save_data != null:
		_pending_overwrite_save = save_data
		_show_overwrite_warning(save_data)
		return

	_start_run(is_ranked)

# Shows the save summary (buttons hidden) alongside a confirm popup warning that
# starting a new run abandons the in-progress one.
func _show_overwrite_warning(save_data: RunData) -> void:
	save_info_popup.populate(save_data)

	# Only the ranked warning (which threatens immediate rank changes on abandon)
	# applies when abandoning would actually settle the run. An endless ranked run
	# was already settled at 10 wins, so abandoning it costs nothing — show the
	# plain casual warning instead (mirrors apply_abandoned_ranked_run's endless
	# guard, which no-ops the rank change below).
	var warns_ranked_change := save_data.is_ranked and not save_data.is_endless_mode
	var msg_key := "ui.overwrite_ranked_confirmation" if warns_ranked_change else "ui.overwrite_casual_confirmation"
	confirm_popup.set_message(tr(msg_key))

	# The title menu / mode-select panel is already hidden by the caller.
	# Pin the save-info popup's bottom a fixed gap above the confirm popup's
	# (stable, top-anchored) top, so padding holds regardless of either popup's
	# height across localizations.
	save_info_popup.show_popup(false, confirm_popup.position.y - OVERWRITE_POPUP_GAP)
	confirm_popup.show_popup()

func _on_overwrite_confirmed():
	confirm_popup.hide_popup()
	await save_info_popup.hide_popup()

	# Abandoning a ranked run settles it as if it had ended now: apply the MMR and
	# (below Master) tier/star changes, then walk the player through the
	# rank-change popup before the new run starts.
	var overwritten := _pending_overwrite_save
	_pending_overwrite_save = null
	if overwritten != null and overwritten.is_ranked:
		await _show_rank_change_for_abandoned_run(overwritten)

	_start_run(_pending_new_run_ranked)

# Applies the abandoned ranked run's results, then plays the rank-change popup
# and awaits the player's confirm. Mirrors run_summary's _maybe_show_rank_change.
func _show_rank_change_for_abandoned_run(save_data: RunData) -> void:
	var change := UserManager.apply_abandoned_ranked_run(save_data)
	if change.is_empty():
		return
	# A run that lands at Master needs its leaderboard standing fetched so the
	# icon's place line is correct before the popup counts the MMR.
	if change.get("new_tier", "") == "master":
		await UserManager.refresh_master_rank()
	await rank_change_popup.play(change)
	# Keep the title sidebar icon in sync with the post-change rank (the popup
	# leaves UserManager.data mutated but doesn't touch the sidebar).
	ranked_icon.visible = true
	ranked_icon.set_user(UserManager.data)

func _on_overwrite_cancelled():
	# Hide both popups outright while the title menu animates back in, so the
	# panels don't slide past each other (mirrors mode-select cancel).
	confirm_popup.visible = false
	save_info_popup.visible = false
	_pending_overwrite_save = null
	_set_menu_buttons_disabled(false)
	# keep_sidebar variant: the sidebars never left, so don't re-slide them.
	title_menu_anim_player.play("show_keep_sidebar")

func _on_mode_select_cancel_pressed():
	# Hide the mode-select panel outright (no animation) while the title menu
	# animates back in, so the two panels don't slide past each other.
	mode_select_menu.visible = false
	# Use the keep_sidebar variant so the sidebar (which never left) doesn't
	# snap to -122 and slide back in.
	_set_menu_buttons_disabled(false)
	title_menu_anim_player.play("show_keep_sidebar")

func _hide_mode_select() -> void:
	if mode_select_anim.has_animation("hide"):
		mode_select_anim.play("hide")
		await mode_select_anim.animation_finished
	mode_select_menu.visible = false

# Performs the fade-out and transitions to trainer select.
# Shared by both "no wins → casual" and "picked from mode select".
# Plays the game-start SFX here so it only fires when a run is actually
# starting — not when opening the mode-select menu.
func _start_run(is_ranked: bool) -> void:
	game_start_sfx.play()
	anim_player.play("fade_out")
	AudioManager.fade_out_music(3.0)
	await anim_player.animation_finished
	RunManager.start_new_run(is_ranked)
	request_transition("trainer_select")

func _on_dex_pressed():
	dex_ui.play_show_animation()

	dex_bg.visible = true
	dex_bg.modulate.a = 0.0
	var bg_tween := create_tween()
	bg_tween.tween_property(dex_bg, "modulate:a", 1.0, 0.2)

func _on_dex_done_pressed():
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dex_ui, "modulate:a", 0.0, 0.1)
	tween.tween_property(dex_bg, "modulate:a", 0.0, 0.1)
	await tween.finished
	dex_ui.visible = false
	dex_bg.visible = false
	# The show animation doesn't touch modulate, so reset it here for next open
	dex_ui.modulate.a = 1.0

func _on_leaderboard_pressed():
	leaderboard_panel.show_leaderboard()

func _on_leaderboard_closed():
	pass

func _on_settings_pressed():
	# The settings menu will cover the title menu
	settings_menu.play_show_animation()

func _on_quit_pressed():
	get_tree().quit()

func _on_anim_finished(anim_name: StringName):
	if anim_name == "transition_in":
		# No session at boot: gate behind the on-screen login row instead of the
		# "press any key" prompt. The reveal happens once a provider login succeeds.
		if _needs_login:
			_show_login_panel()
		else:
			await _reveal_after_checks()

# Reveals the menu entry point after the identity-dependent checks land: a blocking popup
# if the backend is unreachable / in maintenance, otherwise the "press any key" prompt.
func _reveal_after_checks() -> void:
	# Wait for the backend probe to land before deciding what to show, but never indefinitely:
	# poll until the checks finish OR the watchdog elapses. _startup_checks_done is set just
	# before _startup_checks_finished fires, so polling the flag races the signal safely without
	# leaving a connected handler dangling if the watchdog wins.
	if not _startup_checks_done:
		var deadline := Time.get_ticks_msec() + int(STARTUP_CHECKS_WATCHDOG_SEC * 1000.0)
		while not _startup_checks_done and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame

	# Block the menu ONLY when the checks actually finished and found the backend unreachable /
	# in maintenance. If the watchdog fired first (checks still running), do NOT block: a stalled
	# chain is indistinguishable from a merely slow/lossy one, and hard-blocking would lock out
	# exactly the lossy-but-working players we're trying to help. Fall through to the menu instead
	# — a genuine outage resurfaces as a dismissable error on the next network action (Continue /
	# New Run), and a late-completing check can still reveal the Continue/Dex buttons behind it.
	if _startup_checks_done and _block_reason_title != "":
		blocking_popup.show_message(_block_reason_title, _block_reason_message)
	else:
		if not _startup_checks_done:
			push_warning("TitleState: startup checks didn't finish within %ss — entering menu without blocking." % STARTUP_CHECKS_WATCHDOG_SEC)
		press_any_key_label.visible = true
		_waiting_for_any_input = true

# --- ON-SCREEN LOGIN GATE ---
func _show_login_panel() -> void:
	login_status_label.text = ""
	_set_login_buttons_disabled(false)
	login_panel.visible = true

func _on_login_provider_pressed(provider: int) -> void:
	_set_login_buttons_disabled(true)
	login_status_label.text = "Signing in…"

	var ok: bool = await AuthManager.login_with(provider)
	if ok:
		await _on_login_success()
	else:
		login_status_label.text = "Sign-in failed. Please try again."
		_set_login_buttons_disabled(false)

# Login succeeded: drop the login row, run the now-possible identity-dependent checks, and
# reveal the menu entry point exactly as the already-logged-in path does.
func _on_login_success() -> void:
	_needs_login = false
	login_panel.visible = false
	_run_startup_checks()
	await _reveal_after_checks()

func _set_login_buttons_disabled(disabled: bool) -> void:
	steam_login_button.disabled = disabled
	google_login_button.disabled = disabled
	apple_login_button.disabled = disabled

# Toggles the main title menu buttons together so an async save peek (load_run)
# can't be interrupted by another menu action mid-fetch. Independent of each
# button's visibility — re-enabling a hidden button (e.g. Continue/Dex when the
# player has no save) leaves it hidden.
func _set_menu_buttons_disabled(disabled: bool) -> void:
	continue_button.disabled = disabled
	new_run_button.disabled = disabled
	dex_button.disabled = disabled
	settings_button.disabled = disabled
	quit_button.disabled = disabled
	if leaderboard_button:
		leaderboard_button.disabled = disabled
