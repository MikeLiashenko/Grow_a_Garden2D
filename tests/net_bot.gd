extends Node
## One automated player for the multiplayer test. See tests/run_net_test.ps1.
##   GG_NET_BOT=host|guest|villager_a|villager_b  GG_NET_UID=<id>  GG_NET_ROOT=<test root>  GG_NET_CODE=<club>

const D := preload("res://scripts/core/game_data.gd")

var _failures := 0
var _role := ""
var _code := ""


func _ready() -> void:
	_role = OS.get_environment("GG_NET_BOT")
	_code = OS.get_environment("GG_NET_CODE")
	_run()


func _check(cond: bool, what: String) -> void:
	print("[%s] %s %s" % [_role, "ok  " if cond else "FAIL", what])
	if not cond:
		_failures += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _until(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
	return cond.call()


func _finish() -> void:
	print("[%s] traffic in: %d bytes" % [_role, Net.traffic_in()])
	print("[%s] FAILURES: %d" % [_role, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _run() -> void:
	await _wait(0.5)
	if OS.has_environment("GG_EMULATOR"):
		await _make_account()
	var started := Time.get_ticks_msec()
	match _role:
		"host":
			await _host()
		"guest":
			await _guest()
		"villager_a":
			await _villager_a()
		"villager_b":
			await _villager_b()
		"friend_a":
			await _friend_a()
		"friend_b":
			await _friend_b()
		"ui":
			await _ui()
	var minutes := maxf((Time.get_ticks_msec() - started) / 60000.0, 0.01)
	print("[%s] %.1f minutes, %.1f KB per minute" % [_role, minutes, Net.traffic_in() / 1024.0 / minutes])
	_finish()


func _make_account() -> void:
	var tag := OS.get_environment("GG_NET_UID")
	var err: String = await Net.sign_up(tag + "@example.com", "password123")
	_check(err == "", "signs up with email " + err)
	var again: String = await Net.sign_in(tag + "@example.com", "wrong-password")
	_check(again != "", "wrong password refused")
	err = await Net.sign_in(tag + "@example.com", "password123")
	_check(err == "", "signs in with email " + err)
	err = await Net.claim_name(_role)
	_check(err == "", "claims a name " + err)
	var stolen: Dictionary = await Net.read("users/nobody/garden")
	_check(stolen["code"] == 401, "someone else's data is closed")
	var forged: Dictionary = await Net.write("users/nobody/name", "hacked")
	_check(forged["code"] == 401, "someone else's data can't be written")


func _friend_a() -> void:
	await _wait(4.0)
	var err: String = await Net.request_friend("friend_b")
	_check(err == "", "sends a friend request " + err)
	var mine := {}
	for t in 40:
		mine = await Net.friends_overview()
		if not mine["friends"].is_empty():
			break
		await _wait(0.5)
	_check(mine["friends"].size() == 1, "request was accepted")
	if mine["friends"].is_empty():
		return
	await _wait(1.0)
	var w: Dictionary = await Net.friend_where(mine["friends"].keys()[0])
	_check(w.get("k") == "r", "can see where the friend is")


func _friend_b() -> void:
	var o := {}
	for t in 40:
		o = await Net.friends_overview()
		if not o["requests"].is_empty():
			break
		await _wait(0.5)
	_check(o["requests"].size() == 1, "request arrived")
	if o["requests"].is_empty():
		return
	var who: String = o["requests"].keys()[0]
	Net.set_where("r", "ABCDEF")
	await Net.accept_friend(who, o["requests"][who])
	await _wait(1.0)
	var after: Dictionary = await Net.friends_overview()
	_check(after["friends"].has(who) and after["requests"].is_empty(), "accepted: friends now, request gone")
	await _wait(3.0)


## Screenshots of the Garden Times screens, for looking at.
func _ui() -> void:
	var dir := OS.get_environment("GG_NET_SHOTS")
	Session.go_to("res://scenes/garden_times.tscn")
	await _wait(2.0)
	await _shot(dir + "/gt_club.png")
	for entry: Array in [["village", "gt_village"], ["friends", "gt_friends"], ["account", "gt_account"]]:
		var screen: Node = get_tree().current_scene
		screen._tab = entry[0]
		screen._show_current()
		await _wait(2.5)
		await _shot(dir + "/" + entry[1] + ".png")
	var page: Node = get_tree().current_scene
	Net.uid = ""
	page._show_current()
	await _wait(0.5)
	await _shot(dir + "/gt_signin.png")


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _enter_club() -> RoomLink:
	var err: String = await RoomLink.enter(_code)
	if err == "No club with that code":
		var found: Dictionary = await Net.read_tagged("rooms/%s/mem" % _code)
		await Net.write_if("rooms/%s/mem" % _code, {Net.uid: Net.nickname}, found["etag"])
	else:
		_check(err == "", "joins the member list " + err)
	var link := RoomLink.new(_code)
	await Net.start_link(link)
	await _until(func(): return link.sim != null, 25.0)
	_check(link.sim != null, "got a garden")
	if link.sim != null:
		Session.open_shared(link.sim, RoomLink.copy_path(_code), link.title())
		Session.go_to("res://scenes/garden.tscn")
		await _wait(1.0)
		_check(get_tree().current_scene.name == "Garden", "garden scene opened")
	return link


func _host() -> void:
	var link := await _enter_club()
	if link.sim == null:
		return
	_check(link.is_host, "the first in the club runs the garden")
	var sim := link.sim
	await _until(func(): return link.peers().size() >= 2, 40.0)
	_check(link.peers().size() == 2, "sees the second member")
	sim.s["money"] = 500.0
	sim.add_item("seed:carrot", 5)
	await _wait(1.0)
	var bed: Rect2 = D.BEDS[0]["rect"]
	_check(sim.plant("carrot", bed.get_center()) == "", "host plants")
	# The guest plants and buys through us.
	await _until(func(): return sim.s["plants"].size() >= 2, 15.0)
	_check(sim.s["plants"].size() >= 2, "guest's plant arrived and took effect")
	await _until(func(): return float(sim.s["money"]) < 500.0, 8.0)
	_check(float(sim.s["money"]) < 500.0, "guest's purchase spent shared money")
	await _wait(8.0)
	var walked: bool = get_tree().current_scene.get_child_count() > 0
	_check(walked, "scene still running")
	Session.save_game()
	await Net.leave_link()
	print("[host] left the club")
	await _wait(1.0)


func _guest() -> void:
	await _wait(3.0)
	var link := await _enter_club()
	if link.sim == null:
		return
	var sim := link.sim
	_check(not link.is_host and not sim.authority, "a later member follows")
	await _until(func(): return sim.s["plants"].size() >= 1, 20.0)
	_check(sim.s["plants"].size() >= 1, "host's plant appeared here")
	_check(float(sim.s["money"]) >= 400.0, "shared money arrived")
	var bed: Rect2 = D.BEDS[0]["rect"]
	_check(sim.plant("carrot", bed.get_center() + Vector2(40, 0)) == "", "guest's plant is accepted for sending")
	await _until(func(): return sim.s["plants"].size() >= 2, 15.0)
	_check(sim.s["plants"].size() >= 2, "own plant came back from the host")
	var cheapest := ""
	for id: String in D.SEEDS:
		if int(sim.s["stock_seeds"].get(id, 0)) > 0 and int(D.SEEDS[id]["price"]) <= int(sim.s["money"]):
			cheapest = id
			break
	if cheapest != "":
		_check(sim.buy_seed(cheapest) == "", "guest buys a seed")
	else:
		sim.s["stock_seeds"]["carrot"] = 1
		_check(sim.buy_seed("carrot") == "", "guest buys a seed")
	for t in 6:
		link.send_move(Vector2(200 + t * 10, 200), Vector2(92, 0) if t % 2 == 0 else Vector2(0, 92))
		await _wait(0.6)
	var plants_before: int = sim.s["plants"].size()
	await _until(func(): return link.is_host, 30.0)
	_check(link.is_host and sim.authority, "takes over when the host leaves")
	_check(sim.s["plants"].size() == plants_before, "the garden survived the takeover")
	_check(sim.plant("carrot", bed.get_center() + Vector2(-40, 0)) == "" or sim.item_count("seed:carrot") == 0, "new host can plant")
	Session.save_game()
	_check(FileAccess.file_exists(RoomLink.copy_path(_code)), "copy of the garden kept on this device")
	await Net.leave_link()


func _start_village() -> VillageLink:
	var server: String = await VillageLink.pick_server(_code)
	var link := VillageLink.new(server)
	await Net.start_link(link)
	await _until(func(): return link.sim != null and link.status == "", 25.0)
	Session.open_shared(link.sim, VillageLink.local_path(), link.title())
	Session.go_to("res://scenes/garden.tscn")
	await _wait(1.0)
	_check(get_tree().current_scene.name == "Garden", "village garden opened on " + server)
	return link


func _villager_a() -> void:
	var link := await _start_village()
	var sim := link.sim
	var bed: Rect2 = D.BEDS[0]["rect"]
	sim.add_item("seed:carrot", 3)
	_check(sim.plant("carrot", bed.get_center()) == "", "plants in own garden")
	await _until(func(): return link.peers().size() >= 2, 40.0)
	_check(link.peers().size() == 2, "sees a neighbour on the server")
	await _until(func(): return link._visitors().size() >= 1, 30.0)
	_check(link._visitors().size() == 1, "neighbour came to visit")
	await _wait(1.5)
	_check(sim.plant("carrot", bed.get_center() + Vector2(40, 0)) == "", "plants while visited")
	await _until(func(): return link._visitors().is_empty(), 30.0)
	_check(link._visitors().is_empty(), "visitor went home")
	Session.save_game()
	await Net.leave_link()


func _villager_b() -> void:
	await _wait(3.0)
	var link := await _start_village()
	await _until(func(): return link.peers().size() >= 2, 20.0)
	var other := ""
	for id: String in link.peers():
		if id != Net.uid:
			other = id
	_check(other != "", "found the neighbour")
	if other == "":
		return
	var own_sim := link.sim
	link.visit(other)
	await _until(func(): return link.visit_sim != null, 20.0)
	_check(link.visit_sim != null, "their garden arrived")
	if link.visit_sim == null:
		return
	Session.go_to("res://scenes/visit.tscn")
	await _wait(1.0)
	_check(get_tree().current_scene.name == "Visit", "visit scene opened")
	var view := link.visit_sim
	_check(view.s["plants"].size() >= 1, "their plants are visible")
	_check(view.plant("carrot", Vector2(300, 300)) != "", "a visitor can't plant")
	await _until(func(): return view.s["plants"].size() >= 2, 15.0)
	_check(view.s["plants"].size() >= 2, "their new plant appeared live")
	var money_before: float = own_sim.s["time"]
	await _wait(1.0)
	_check(float(own_sim.s["time"]) > money_before, "own garden keeps running while away")
	link.go_home()
	Session.go_to("res://scenes/garden.tscn")
	await _wait(2.0)
	Session.save_game()
	await Net.leave_link()
