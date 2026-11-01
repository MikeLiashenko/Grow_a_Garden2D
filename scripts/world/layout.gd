extends RefCounted
## Where every prop stands. Returns plain data; garden_world.gd builds the nodes.

const D := preload("res://scripts/core/game_data.gd")

const STALLS := [
	{"id": "gear", "sprite": "prop/stall_gear", "title": "GEAR", "pos": Vector2(224, 592)},
	{"id": "seed", "sprite": "prop/stall_seed", "title": "SEEDS", "pos": Vector2(352, 592)},
	{"id": "sell", "sprite": "prop/stall_sell", "title": "SELL", "pos": Vector2(608, 592)},
]
## Places the gardener can go to. Their window opens with E on this spot.
const PLACES := {
	"seed": {"name": "Seed Shop", "stand": Vector2(352, 606)},
	"gear": {"name": "Gear Shop", "stand": Vector2(224, 606)},
	"sell": {"name": "Sell Stand", "stand": Vector2(608, 606)},
	"greenhouse": {"name": "Greenhouse", "stand": Vector2(480, 206)},
}
const PLACE_REACH := 52.0
const GREENHOUSE_POS := Vector2(480, 192)
const LAMPS := [
	Vector2(436, 205), Vector2(524, 205), Vector2(436, 385), Vector2(524, 385), Vector2(436, 450), Vector2(524, 450),
	Vector2(436, 565), Vector2(524, 565), Vector2(180, 690), Vector2(400, 690), Vector2(560, 690), Vector2(780, 690),
]
const NORTH_Y := 80
const SOUTH_Y := 528


## The place the gardener is standing at, or "" if none is within reach.
static func place_near(pos: Vector2) -> String:
	for id: String in PLACES:
		if pos.distance_to(PLACES[id]["stand"]) <= PLACE_REACH:
			return id
	return ""


## Returns [{sprite, pos, col: Rect2 relative to pos (optional)}].
static func props() -> Array:
	var out: Array = []
	var add := func(sprite: String, pos: Vector2, col := Rect2()) -> void:
		var e := {"sprite": sprite, "pos": pos}
		if col.size != Vector2.ZERO:
			e["col"] = col
		out.append(e)

	# Fence: north, south (with the gate gap), west and east.
	var x0 := D.FENCE_X1 * 16 + 8
	var x1 := D.FENCE_X2 * 16 + 8
	for x in range(x0, x1, 16):
		add.call("prop/fence_h", Vector2(x, NORTH_Y))
	for x in range(x0, 432, 16):
		add.call("prop/fence_h", Vector2(x, SOUTH_Y))
	for x in range(528, x1, 16):
		add.call("prop/fence_h", Vector2(x, SOUTH_Y))
	for y in range(NORTH_Y + 16, SOUTH_Y, 16):
		add.call("prop/fence_v", Vector2(x0, y))
		add.call("prop/fence_v", Vector2(x1, y))
	for c: Vector2 in [Vector2(x0, NORTH_Y + 1), Vector2(x1, NORTH_Y + 1), Vector2(x0, SOUTH_Y + 1), Vector2(x1, SOUTH_Y + 1)]:
		add.call("prop/pillar", c)
	add.call("prop/pillar_lantern", Vector2(440, SOUTH_Y + 2))
	add.call("prop/pillar_lantern", Vector2(520, SOUTH_Y + 2))

	# Hedges along the north wall.
	var k := 0
	for x in range(152, 816, 14):
		if x < 414 or x > 540:
			add.call("prop/hedge%d" % (k % 3), Vector2(x, 96))
		k += 1

	# Centrepieces.
	add.call("prop/fountain", D.FOUNTAIN, Rect2(-50, -18, 100, 44))
	add.call("prop/greenhouse", GREENHOUSE_POS, Rect2(-60, -14, 120, 14))
	add.call("prop/house", Vector2(60, 300), Rect2(-46, -16, 92, 16))

	for p: Vector2 in LAMPS:
		add.call("prop/lamp", p, Rect2(-3, -3, 6, 4))
	for p: Vector2 in [Vector2(412, 228), Vector2(548, 228), Vector2(412, 358), Vector2(548, 358)]:
		add.call("prop/topiary", p, Rect2(-6, -4, 12, 5))
	add.call("prop/bench", Vector2(420, 300), Rect2(-18, -6, 36, 7))
	add.call("prop/bench", Vector2(540, 300), Rect2(-18, -6, 36, 7))

	# Flowering shrubs flanking the walk.
	var kinds := ["prop/bush_rose", "prop/bush_yellow", "prop/bush_violet", "prop/bush_rose"]
	var i := 0
	for y: int in [400, 424, 472, 498]:
		add.call(kinds[i % 4], Vector2(420, y), Rect2(-8, -4, 16, 5))
		add.call(kinds[(i + 1) % 4], Vector2(540, y), Rect2(-8, -4, 16, 5))
		i += 1

	# Blossom trees just outside the gate.
	add.call("prop/tree_blossom0", Vector2(384, 540), Rect2(-5, -4, 10, 5))
	add.call("prop/tree_blossom1", Vector2(576, 540), Rect2(-5, -4, 10, 5))

	_forest(out)
	return out


static func _forest(out: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var kinds := ["prop/tree_oak0", "prop/tree_pine0", "prop/tree_oak1", "prop/tree_pine1", "prop/tree_oak2", "prop/tree_blossom0"]
	var y := 8
	while y < 720:
		var x := -8
		while x < 980:
			var p := Vector2(x + rng.randf_range(-13, 13), y + rng.randf_range(-11, 11)).round()
			if _forest_free(p):
				if rng.randf() < 0.8:
					out.append({"sprite": kinds[rng.randi() % kinds.size()], "pos": p, "col": Rect2(-5, -4, 10, 5)})
			else:
				if rng.randf() < 0.05 and _rock_free(p):
					out.append({"sprite": "prop/rock%d" % (rng.randi() % 2), "pos": p, "col": Rect2(-8, -4, 16, 5)})
			x += 38
		y += 30


static func _forest_free(p: Vector2) -> bool:
	# Keep clear of the garden, the road, the gate walk and the set pieces.
	if p.x > 104 and p.x < 858 and p.y > 44 and p.y < 556:
		return false
	if p.y > 556 and p.y < 700:
		return false
	if Rect2(4, 240, 120, 80).has_point(p):
		return false
	if Rect2(838, 210, 118, 140).has_point(p):
		return false
	return true


static func _rock_free(p: Vector2) -> bool:
	if p.y > 596 and p.y < 684:
		return false
	if p.x > 110 and p.x < 852 and p.y < 550:
		return false
	if p.x > 430 and p.x < 530:
		return false
	if p.y > 500 and p.y < 600 and p.x > 170 and p.x < 660:
		return false
	return not Rect2(4, 240, 120, 80).has_point(p) and not Rect2(838, 210, 118, 140).has_point(p)


## Solid walls that aren't attached to a single prop.
static func walls() -> Array:
	var x0 := float(D.FENCE_X1 * 16 + 4)
	var x1 := float(D.FENCE_X2 * 16 + 12)
	var w := D.WORLD_PX
	return [
		Rect2(x0, NORTH_Y - 6, x1 - x0, 8),
		Rect2(x0, SOUTH_Y - 6, 448 - x0, 8),
		Rect2(512, SOUTH_Y - 6, x1 - 512, 8),
		Rect2(x0, NORTH_Y, 6, SOUTH_Y - NORTH_Y),
		Rect2(x1 - 6, NORTH_Y, 6, SOUTH_Y - NORTH_Y),
		Rect2(-20, -20, w.x + 40, 20),
		Rect2(-20, w.y, w.x + 40, 20),
		Rect2(-20, 0, 20, w.y),
		Rect2(w.x, 0, 20, w.y),
		Rect2(854, 226, 84, 108), # pond
	]
