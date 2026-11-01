extends PanelContainer
## Who else is here. In a club: the code to share. In the village: visit a neighbour.

var _list: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(220, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var col := Ui.vbox(4)
	add_child(col)
	col.add_child(Ui.label(Net.link.title(), Ui.GOLD))
	if Net.link is RoomLink:
		var share := Ui.hbox(4)
		var line := Ui.label("Share this code: " + Net.link.code, Ui.CREAM)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		share.add_child(line)
		share.add_child(Ui.copy_button(Net.link.code))
		col.add_child(share)
	_list = Ui.vbox(2)
	col.add_child(_list)
	var close := Ui.button("CLOSE")
	close.pressed.connect(queue_free)
	col.add_child(close)
	Net.link.peers_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var link := Net.link
	if link == null:
		return
	for id: String in link.peers():
		var row := Ui.hbox(4)
		var who := Ui.label(link.peer_name(id) + (" (you)" if id == Net.uid else ""))
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		if link is VillageLink and id != Net.uid:
			var go := Ui.button("VISIT", "green")
			go.pressed.connect(_visit.bind(id))
			row.add_child(go)
		_list.add_child(row)


func _visit(id: String) -> void:
	var link: VillageLink = Net.link
	if link == null:
		return
	if not link.visit_ready.is_connected(_on_visit_ready):
		link.visit_ready.connect(_on_visit_ready, CONNECT_ONE_SHOT)
	Session.save_game()
	link.visit(id)


func _on_visit_ready(_owner_id: String) -> void:
	Session.go_to("res://scenes/visit.tscn")
