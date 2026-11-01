extends SceneTree
## Generates every texture of the game into assets/. Run after changing the art:
##   godot --headless --path . --script tools/generate_art.gd
##   godot --headless --path . --import

const Painter := preload("res://tools/art/painter.gd")
const FruitArt := preload("res://tools/art/fruit_art.gd")
const PlantArt := preload("res://tools/art/plant_art.gd")
const ItemArt := preload("res://tools/art/item_art.gd")
const WorldArt := preload("res://tools/art/world_art.gd")
const UiArt := preload("res://tools/art/ui_art.gd")
const IconArt := preload("res://tools/art/icon_art.gd")
const D := preload("res://scripts/core/game_data.gd")

const ROOT := "res://assets"
const SHEET_WIDTH := 1024

var manifest := {}


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ROOT + "/sprites")
	DirAccess.make_dir_recursive_absolute(ROOT + "/fonts")
	DirAccess.make_dir_recursive_absolute(ROOT + "/world")
	UiArt.write_font(ROOT + "/fonts")
	_build_fruits()
	_build_plants()
	_build_items()
	_build_chars()
	_build_props()
	_build_ui()
	WorldArt.ground().img.save_png(ROOT + "/world/ground.png")
	UiArt.logo().img.save_png(ROOT + "/world/logo.png")
	_write_icon()
	_write_manifest()
	print("Art generated in %d ms" % (Time.get_ticks_msec() - t0))
	quit()


## Every size a fruit is drawn at: icon, growth steps, weight variants.
static func fruit_sizes(fs: int) -> Array:
	var sizes := {16: true, 10: true}
	for v in [roundi(fs * 0.45), roundi(fs * 0.7), fs - 1, fs, fs + 1, fs + 2]:
		sizes[maxi(v, 3)] = true
	return sizes.keys()


func _pack(sheet: String, items: Array) -> void:
	# Shelf packing: tallest first keeps wasted space low.
	items.sort_custom(func(a, b): return a[1].h > b[1].h)
	var x := 0
	var y := 0
	var shelf := 0
	var placed := []
	for it in items:
		var p: RefCounted = it[1]
		if x + p.w + 1 > SHEET_WIDTH:
			x = 0
			y += shelf + 1
			shelf = 0
		placed.append([it[0], p, x, y])
		x += p.w + 1
		shelf = maxi(shelf, p.h)
	var img := Image.create_empty(SHEET_WIDTH, y + shelf + 1, false, Image.FORMAT_RGBA8)
	var path := "%s/sprites/%s.png" % [ROOT, sheet]
	for e in placed:
		var p: RefCounted = e[1]
		img.blit_rect(p.img, Rect2i(0, 0, p.w, p.h), Vector2i(e[2], e[3]))
		manifest[e[0]] = [sheet, e[2], e[3], p.w, p.h, p.ax, p.ay]
	img.save_png(path)


func _build_fruits() -> void:
	var items := []
	for id in D.SEEDS:
		for size in fruit_sizes(D.SEEDS[id]["fs"]):
			items.append(["fruit/%s/%d" % [id, size], FruitArt.make(id, size)])
	_pack("fruits", items)


func _build_plants() -> void:
	var items := []
	for id in D.SEEDS:
		for stage in 5:
			for v in 2:
				items.append(["plant/%s/%d/%d" % [id, stage, v], PlantArt.make(id, stage, v)])
	_pack("plants", items)


func _build_items() -> void:
	var items := []
	for id in D.SEEDS:
		var band: String = D.RARITIES[D.SEEDS[id]["rar"]]["color"]
		items.append(["item/seed/" + id, ItemArt.seed_packet(id, band)])
	for id in D.GEAR:
		items.append(["item/gear/" + id, ItemArt.gear_icon(id)])
	for id in ["basic_sprinkler", "adv_sprinkler", "godly_sprinkler", "lucky_gnome"]:
		items.append(["gadget/" + id, ItemArt.gadget(id)])
	items.append(["ui/coin", ItemArt.coin()])
	items.append(["ui/quest", ItemArt.quest_icon()])
	items.append(["ui/greenhouse", ItemArt.greenhouse_icon()])
	_pack("items", items)


const PLAYER_PAL := {"skin": "#f0c090", "shirt": "#d84848", "pants": "#3a60c0", "boots": "#5a3618", "hat": "#e8c868", "band": "#a03030", "hair": "#6a3a18"}


func _build_chars() -> void:
	var items := []
	for dir in 3:
		for frame in 4:
			items.append(["player/%d/%d" % [dir, frame], ItemArt.person(dir, frame, PLAYER_PAL)])
	_pack("characters", items)


func _build_props() -> void:
	var seed_keeper := {"skin": "#e0a878", "shirt": "#4a9e48", "pants": "#7c5228", "boots": "#3a2210", "hat": "#4a9e48", "band": "#ffe060", "hair": "#3a2210"}
	var gear_keeper := {"skin": "#f0c090", "shirt": "#3a70b8", "pants": "#3a3a48", "boots": "#2a2a34", "hat": "#d8a020", "band": "#2a2a34", "hair": "#a05a20"}
	var sell_keeper := {"skin": "#b87a50", "shirt": "#e8c030", "pants": "#6a3ad0", "boots": "#3a2210", "hat": "#8a4fc0", "band": "#ffe060", "hair": "#1a1420"}
	var seed_goods := []
	for id in ["carrot", "tomato", "strawberry", "apple", "pumpkin"]:
		seed_goods.append(ItemArt.seed_packet(id, D.RARITIES[D.SEEDS[id]["rar"]]["color"]))
	var gear_goods := []
	for id in ["shovel", "watering_can", "trowel", "basic_sprinkler", "golden_sickle"]:
		gear_goods.append(ItemArt.gear_icon(id))
	var sell_goods := []
	for id in ["watermelon", "tomato", "apple", "corn", "pumpkin"]:
		sell_goods.append(FruitArt.make(id, 14))
	var items := [
		["prop/tree_oak0", WorldArt.tree("oak", 0)], ["prop/tree_oak1", WorldArt.tree("oak", 1)], ["prop/tree_oak2", WorldArt.tree("oak", 2)],
		["prop/tree_pine0", WorldArt.tree("pine", 0)], ["prop/tree_pine1", WorldArt.tree("pine", 1)],
		["prop/tree_blossom0", WorldArt.tree("blossom", 0)], ["prop/tree_blossom1", WorldArt.tree("blossom", 1)],
		["prop/bush_green", WorldArt.bush("green", 0)], ["prop/bush_rose", WorldArt.bush("rose", 0)],
		["prop/bush_yellow", WorldArt.bush("yellow", 0)], ["prop/bush_violet", WorldArt.bush("violet", 0)],
		["prop/hedge0", WorldArt.hedge(0)], ["prop/hedge1", WorldArt.hedge(1)], ["prop/hedge2", WorldArt.hedge(2)],
		["prop/fence_h", WorldArt.fence_h()], ["prop/fence_v", WorldArt.fence_v()],
		["prop/pillar", WorldArt.pillar(false)], ["prop/pillar_lantern", WorldArt.pillar(true)],
		["prop/gate_door", WorldArt.gate_door()], ["prop/arch", WorldArt.arch()],
		["prop/lamp", WorldArt.lamp()], ["prop/bench", WorldArt.bench()],
		["prop/rock0", WorldArt.rock(0)], ["prop/rock1", WorldArt.rock(1)], ["prop/topiary", WorldArt.topiary()],
		["prop/fountain", WorldArt.fountain()], ["prop/greenhouse", WorldArt.greenhouse()], ["prop/house", WorldArt.house()],
		["prop/stall_seed", WorldArt.stall("#3aa84a", "#f4f0dc", seed_goods, seed_keeper)],
		["prop/stall_gear", WorldArt.stall("#3a78c8", "#f4f0dc", gear_goods, gear_keeper)],
		["prop/stall_sell", WorldArt.stall("#e0a020", "#f4f0dc", sell_goods, sell_keeper)],
		["prop/bed_sign", WorldArt.bed_sign()],
	]
	_pack("props", items)
	WorldArt.locked_bed().img.save_png(ROOT + "/world/locked_bed.png")


func _build_ui() -> void:
	var paper := ["#e8d4a4", "#dcc494", "#f6e8c0"]
	var dark := ["#3a2616", "#34220f", "#4a3220"]
	var green := ["#2a6a2e", "#3c8a3a", "#58ac4a", "#84cc62"]
	var wood := ["#5a3618", "#7c5228", "#9a6e3c", "#c09458"]
	var gold := ["#8a5a10", "#c08a20", "#e8b83a", "#ffe880"]
	var grey := ["#3c3830", "#55504a", "#6e6a60", "#8a867a"]
	var red := ["#7a2018", "#a83028", "#cc4a3a", "#e87a60"]
	var blue := ["#1f4a7a", "#2c6aa8", "#4a90d0", "#80c0f0"]
	var items := [
		["ui/panel", UiArt.panel(paper)], ["ui/panel_dark", UiArt.panel(dark)],
		["ui/btn", UiArt.button(wood)], ["ui/btn_hover", UiArt.button(gold)], ["ui/btn_pressed", UiArt.button(wood, 2)],
		["ui/btn_disabled", UiArt.button(grey)],
		["ui/btn_green", UiArt.button(green)], ["ui/btn_green_pressed", UiArt.button(green, 2)],
		["ui/btn_red", UiArt.button(red)], ["ui/btn_red_pressed", UiArt.button(red, 2)],
		["ui/btn_blue", UiArt.button(blue)], ["ui/btn_blue_pressed", UiArt.button(blue, 2)],
		["ui/btn_gold", UiArt.button(gold)], ["ui/btn_gold_pressed", UiArt.button(gold, 2)],
		["ui/slot", UiArt.slot(false)], ["ui/slot_selected", UiArt.slot(true)],
		["ui/glow", UiArt.glow(128)], ["ui/cursor", UiArt.cursor()],
	]
	_pack("ui", items)


func _write_icon() -> void:
	var berry: RefCounted = IconArt.strawberry()
	IconArt.scaled(berry, 4).save_png("res://icon.png")
	DirAccess.make_dir_recursive_absolute(ROOT + "/icon")
	IconArt.scaled(berry, 3).save_png(ROOT + "/icon/android_192.png")
	IconArt.adaptive_foreground(berry).save_png(ROOT + "/icon/android_foreground.png")
	IconArt.adaptive_background().save_png(ROOT + "/icon/android_background.png")
	IconArt.adaptive_monochrome(berry).save_png(ROOT + "/icon/android_monochrome.png")


func _write_manifest() -> void:
	var f := FileAccess.open(ROOT + "/sprites/manifest.gd", FileAccess.WRITE)
	f.store_string("extends RefCounted\n## Generated by tools/generate_art.gd: name -> [sheet, x, y, w, h, anchor_x, anchor_y]\n\nconst SPRITES := %s\n" % JSON.stringify(manifest, "\t", false))
	f.close()
