extends Control
## Garden Times, laid out as the front page of a village newspaper: the account,
## the Garden Club and Open Village modes, and friends.

const GARDEN := "res://scenes/garden.tscn"

var _paper: VBoxContainer
var _body: VBoxContainer
var _tabs: HBoxContainer
var _tab := "club"
var _message: Label
var _session_generation := 0


func _ready() -> void:
	name = "GardenTimes"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#24351f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var sheet := Ui.panel(false)
	sheet.custom_minimum_size = Vector2(430, 0)
	center.add_child(sheet)
	_paper = Ui.vbox(4)
	sheet.add_child(_paper)
	var head := Ui.label("THE GARDEN TIMES", Ui.INK, 24)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paper.add_child(head)
	_paper.add_child(_rule(2))
	_tabs = Ui.hbox(3)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_paper.add_child(_tabs)
	_body = Ui.vbox(4)
	_paper.add_child(_body)
	_message = Ui.label("", Color("#a83028"))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 400
	_paper.add_child(_message)
	var back := Ui.button("BACK TO MENU", "", 8)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 120
	back.pressed.connect(_back)
	_paper.add_child(back)
	Net.google_code.connect(_on_google_code)
	await Net.ready_token()
	if is_inside_tree():
		_show_current()


func _rule(height: int) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Ui.INK
	rule.custom_minimum_size = Vector2(0, height)
	return rule


func _text(text: String, color := Ui.INK) -> Label:
	var l := Ui.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 400
	return l


func _say(text: String) -> void:
	_message.text = text


func _clear() -> void:
	_say("")
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func _show_current() -> void:
	_build_tabs()
	if not Net.auth_available():
		_clear()
		_body.add_child(_text("Accounts are not switched on in this version of the game yet."))
	elif not Net.signed_in():
		_show_sign_in()
	elif Net.nickname == "":
		_show_name_choice()
	else:
		match _tab:
			"club":
				_show_club()
			"village":
				_show_village()
			"friends":
				_show_friends()
			"account":
				_show_account()


func _build_tabs() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	_tabs.visible = Net.signed_in() and Net.nickname != ""
	if not _tabs.visible:
		return
	for entry: Array in [["club", "GARDEN CLUB"], ["village", "OPEN VILLAGE"], ["friends", "FRIENDS"], ["account", Net.nickname]]:
		var id: String = entry[0]
		var b := Ui.button(entry[1], "gold" if id == _tab else "")
		b.custom_minimum_size.x = 96
		b.pressed.connect(func():
			_tab = id
			_show_current()
		)
		_tabs.add_child(b)


# --- Account --------------------------------------------------------------------

func _show_sign_in() -> void:
	_clear()
	_body.add_child(_text("Sign in to garden with others. Your account keeps your name, your friends and your village garden."))
	var email := Ui.line_edit("Email")
	var password := Ui.line_edit("Password", true)
	_body.add_child(email)
	_body.add_child(password)
	var row := Ui.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	var sign_in := Ui.button("SIGN IN", "green")
	sign_in.pressed.connect(func(): _finish_auth(await Net.sign_in(email.text.strip_edges(), password.text)))
	row.add_child(sign_in)
	var create := Ui.button("CREATE ACCOUNT", "blue")
	create.pressed.connect(func(): _finish_auth(await Net.sign_up(email.text.strip_edges(), password.text)))
	row.add_child(create)
	if Net.google_available():
		var google := Ui.button("SIGN IN WITH GOOGLE", "")
		google.pressed.connect(func():
			_say("Opening Google...")
			_finish_auth(await Net.sign_in_google())
		)
		row.add_child(google)


func _finish_auth(err: String) -> void:
	if not is_inside_tree():
		return
	if err != "":
		_show_sign_in()
		_say(err)
	else:
		_show_current()


## Google gives a short code to approve in a browser, the same on every device.
func _on_google_code(page: String, code: String) -> void:
	_show_google_code(page, code)
	DisplayServer.clipboard_set(code)
	OS.shell_open(page)


func _show_google_code(page: String, code: String) -> void:
	_clear()
	_body.add_child(_text("Your browser is opening Google. Enter this code there:"))
	var big := Ui.label(code, Color("#a83028"), 16)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(big)
	var copy := Ui.copy_button(code)
	copy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	copy.custom_minimum_size.x = 80
	_body.add_child(copy)
	_body.add_child(_text(page))
	var cancel := Ui.button("CANCEL")
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func():
		Net.cancel_google()
		_show_sign_in()
	)
	_body.add_child(cancel)


func _show_name_choice() -> void:
	_clear()
	_body.add_child(_text("Choose your gardener's name. Friends find you by it."))
	var field := Ui.line_edit("Name")
	field.max_length = Net.NAME_MAX
	_body.add_child(field)
	var ok := Ui.button("THAT'S ME", "green")
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		var err: String = await Net.claim_name(field.text)
		if err != "":
			_say(err)
		else:
			_show_current()
	)
	_body.add_child(ok)


func _show_account() -> void:
	_clear()
	_body.add_child(_text("Signed in as %s." % Net.nickname))
	var out := Ui.button("SIGN OUT", "red")
	out.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	out.pressed.connect(func():
		Net.sign_out()
		_show_current()
	)
	_body.add_child(out)


# --- Garden Club ------------------------------------------------------------------

func _show_club() -> void:
	_clear()
	_body.add_child(_text("One garden, up to %d friends. It lives on your devices, not on a server: whoever has been in the club keeps a copy." % RoomLink.MAX_MEMBERS))
	var row := Ui.hbox(4)
	_body.add_child(row)
	var create := Ui.button("NEW CLUB", "green")
	create.pressed.connect(_create_club)
	row.add_child(create)
	row.add_child(Ui.spacer())
	var code := Ui.line_edit("Club code")
	code.max_length = RoomLink.CODE_LENGTH
	code.custom_minimum_size.x = 90
	row.add_child(code)
	var join := Ui.button("JOIN", "blue")
	join.pressed.connect(func(): _join_club(code.text.strip_edges().to_upper()))
	row.add_child(join)
	_body.add_child(_rule(1))
	_body.add_child(_text("YOUR CLUBS"))
	var list := Ui.vbox(2)
	_body.add_child(list)
	var clubs: Variant = (await Net.read("users/%s/rooms" % Net.uid, true))["data"]
	if not is_inside_tree() or _tab != "club":
		return
	if not clubs is Dictionary or clubs.is_empty():
		list.add_child(_text("None yet.", Color("#6e4826")))
		return
	for room: String in clubs:
		var entry := Ui.hbox(4)
		var has_copy := FileAccess.file_exists(RoomLink.copy_path(room))
		var title := _text("%s  %s" % [room, "" if has_copy else "(no copy here)"])
		title.custom_minimum_size.x = 0
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(title)
		entry.add_child(Ui.copy_button(room))
		var play := Ui.button("PLAY", "green")
		play.pressed.connect(func(): _open_session(RoomLink.new(room), RoomLink.copy_path(room)))
		entry.add_child(play)
		var quit := Ui.button("LEAVE", "red")
		quit.pressed.connect(func():
			await RoomLink.quit_club(room)
			_show_club()
		)
		entry.add_child(quit)
		list.add_child(entry)


func _create_club() -> void:
	_say("Creating a club...")
	var room: String = await RoomLink.create()
	if room == "":
		_say("No connection to the server")
	else:
		_open_session(RoomLink.new(room, true), RoomLink.copy_path(room))


func _join_club(room: String) -> void:
	if room.length() != RoomLink.CODE_LENGTH:
		_say("A club code has %d characters" % RoomLink.CODE_LENGTH)
		return
	_say("Joining...")
	var err: String = await RoomLink.enter(room)
	if err != "":
		_say(err)
	else:
		_open_session(RoomLink.new(room), RoomLink.copy_path(room))


# --- Open Village -----------------------------------------------------------------

func _show_village() -> void:
	_clear()
	_body.add_child(_text("Land on a random server with up to %d gardeners. Everyone has their own garden, and you can walk over to see theirs." % VillageLink.MAX_PLAYERS))
	var play := Ui.button("PLAY", "green", 16)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.custom_minimum_size = Vector2(176, 26)
	play.pressed.connect(func(): _play_village())
	_body.add_child(play)
	_body.add_child(_rule(1))
	_body.add_child(_text("BRING A GARDEN FROM SINGLE PLAYER"))
	_body.add_child(_text("A copy becomes your village garden, replacing the one there, and syncs to your account. The original stays as it is.", Color("#6e4826")))
	var gardens := Session.garden_list()
	if gardens.is_empty():
		_body.add_child(_text("No saved gardens yet.", Color("#6e4826")))
	for g: Dictionary in gardens.slice(0, 4):
		var row := Ui.hbox(4)
		var title := _text("%s   %s" % [g["name"], Ui.garden_summary(g)])
		title.custom_minimum_size.x = 0
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var up := Ui.button("UPLOAD", "gold")
		var path: String = g["path"]
		up.pressed.connect(func():
			_say("Uploading...")
			_say("Uploaded! Press Play." if await VillageLink.upload_garden(path) else "Could not upload the garden")
		)
		row.add_child(up)
		_body.add_child(row)


func _play_village(wanted := "") -> void:
	_say("Looking for a server...")
	var server: String = await VillageLink.pick_server(wanted)
	if server == "":
		_say("Every server is full. Try again soon")
		return
	_open_session(VillageLink.new(server), "")


# --- Friends ----------------------------------------------------------------------

func _show_friends() -> void:
	_clear()
	var row := Ui.hbox(4)
	_body.add_child(row)
	var field := Ui.line_edit("A gardener's name")
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	var add := Ui.button("ADD FRIEND", "green")
	add.pressed.connect(func():
		var err: String = await Net.request_friend(field.text)
		_say(err if err != "" else "Request sent")
	)
	row.add_child(add)
	var refresh := Ui.button("REFRESH")
	refresh.pressed.connect(_show_friends)
	row.add_child(refresh)
	var list := Ui.vbox(2)
	_body.add_child(list)
	var o: Dictionary = await Net.friends_overview()
	if not is_inside_tree() or _tab != "friends":
		return
	for id: String in o["requests"]:
		var who: String = o["requests"][id]
		list.add_child(_friend_row("%s wants to be friends" % who, [
			["ACCEPT", "green", func():
				await Net.accept_friend(id, who)
				_show_friends()],
			["NO", "red", func():
				await Net.decline_friend(id)
				_show_friends()],
		]))
	if o["friends"].is_empty():
		list.add_child(_text("No friends here yet. Add one by their gardener's name.", Color("#6e4826")))
	for id: String in o["friends"]:
		var who: String = o["friends"][id]
		var where: Dictionary = await Net.friend_where(id)
		if not is_inside_tree() or _tab != "friends":
			return
		var actions := []
		if where.get("k") == "r":
			actions.append(["JOIN CLUB", "green", func(): _join_club(where["id"])])
		elif where.get("k") == "v":
			actions.append(["JOIN VILLAGE", "green", func(): _play_village(where["id"])])
		actions.append(["REMOVE", "", func():
			await Net.remove_friend(id)
			_show_friends()])
		list.add_child(_friend_row("%s   %s" % [who, "online" if not where.is_empty() else "away"], actions))


func _friend_row(text: String, actions: Array) -> Control:
	var row := Ui.hbox(4)
	var title := _text(text)
	title.custom_minimum_size.x = 0
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	for a: Array in actions:
		var b := Ui.button(a[0], a[1])
		b.pressed.connect(a[2])
		row.add_child(b)
	return row


# --- Starting a session -----------------------------------------------------------

func _open_session(link: GardenLink, save_path: String) -> void:
	_clear()
	_tabs.visible = false
	var status := Ui.label(link.title(), Ui.INK, 16)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(status)
	var line := _text("Connecting...")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(line)
	var older := Ui.button("USE MY OLDER COPY", "gold")
	older.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	older.visible = false
	_body.add_child(older)
	var cancel := Ui.button("CANCEL")
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func():
		await Net.leave_link()
		_show_current()
	)
	_body.add_child(cancel)
	link.status_changed.connect(func(text: String):
		line.text = text
		older.visible = link is RoomLink and link.has_older_copy() and text.contains("newer")
	)
	if link is RoomLink:
		older.pressed.connect(link.use_my_copy)
	link.lost.connect(func(reason: String):
		await Net.leave_link()
		if is_inside_tree():
			_show_current()
			_say(reason)
	)
	link.play_ready.connect(func():
		var path := save_path if save_path != "" else VillageLink.local_path()
		Session.open_shared(link.sim, path, link.title())
		Session.go_to(GARDEN)
	)
	await Net.start_link(link)


func _back() -> void:
	await Net.leave_link()
	Session.go_to("res://scenes/main_menu.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		_back()
