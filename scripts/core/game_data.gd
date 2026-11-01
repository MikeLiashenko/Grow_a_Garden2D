class_name GameData
extends RefCounted
## Static game content: seeds, gear, mutations, weather, quests, world layout.
## No nodes or textures here, so the simulation also runs headless.

const TILE := 16
const WORLD_W := 60
const WORLD_H := 44
const WORLD_PX := Vector2(WORLD_W * TILE, WORLD_H * TILE)

## Fence, in tiles (inclusive). The south side has a gate gap.
const FENCE_X1 := 8
const FENCE_X2 := 51
const FENCE_Y1 := 4
const FENCE_Y2 := 32
const GATE_X1 := 28
const GATE_X2 := 31

const SPAWN := Vector2(480, 344)
const FOUNTAIN := Vector2(480, 288)
const DAY_LENGTH := 480.0
const RESTOCK_TIME := 240.0
const START_CAPACITY := 100

## Garden beds in pixels. Price 0 means unlocked from the start.
const BEDS := [
	{"rect": Rect2(176, 240, 224, 112), "price": 0},
	{"rect": Rect2(560, 240, 224, 112), "price": 0},
	{"rect": Rect2(176, 368, 224, 112), "price": 5000},
	{"rect": Rect2(560, 368, 224, 112), "price": 25000},
	{"rect": Rect2(176, 112, 224, 112), "price": 120000},
	{"rect": Rect2(560, 112, 224, 112), "price": 600000},
]
const BED_INSET := 5.0

const RARITIES := {
	"common": {"name": "Common", "color": "#c9c9c9", "rank": 0},
	"uncommon": {"name": "Uncommon", "color": "#6ddc5a", "rank": 1},
	"rare": {"name": "Rare", "color": "#4fa8ff", "rank": 2},
	"legendary": {"name": "Legendary", "color": "#ffd23f", "rank": 3},
	"mythical": {"name": "Mythical", "color": "#d66bff", "rank": 4},
	"divine": {"name": "Divine", "color": "#ff7a3c", "rank": 5},
	"prismatic": {"name": "Prismatic", "color": "#7ff0ff", "rank": 6},
}

## grow: seconds to maturity. multi plants keep producing fruit every fruit_time.
## r: footprint radius used for spacing. fs: fruit sprite size on the plant.
## slots: where fruit hangs, relative to the plant base.
const SEEDS := {
	"carrot": {"name": "Carrot", "rar": "common", "price": 12, "grow": 20.0, "multi": false, "fruit_time": 0.0,
		"value": 24, "kg": 0.25, "r": 6, "fs": 11, "slots": [Vector2(0, -6)], "chance": 1.0, "stock": [12, 25]},
	"tomato": {"name": "Tomato", "rar": "common", "price": 45, "grow": 60.0, "multi": true, "fruit_time": 25.0,
		"value": 16, "kg": 0.4, "r": 10, "fs": 8,
		"slots": [Vector2(-7, -9), Vector2(7, -11), Vector2(-3, -18), Vector2(4, -22), Vector2(0, -12)], "chance": 1.0, "stock": [4, 10]},
	"strawberry": {"name": "Strawberry", "rar": "uncommon", "price": 350, "grow": 120.0, "multi": true, "fruit_time": 35.0,
		"value": 40, "kg": 0.3, "r": 9, "fs": 7,
		"slots": [Vector2(-7, -6), Vector2(6, -5), Vector2(-2, -11), Vector2(4, -13)], "chance": 0.85, "stock": [2, 6]},
	"daffodil": {"name": "Daffodil", "rar": "uncommon", "price": 550, "grow": 90.0, "multi": false, "fruit_time": 0.0,
		"value": 760, "kg": 0.16, "r": 7, "fs": 12, "slots": [Vector2(0, -21)], "chance": 0.7, "stock": [3, 6]},
	"corn": {"name": "Corn", "rar": "uncommon", "price": 750, "grow": 150.0, "multi": true, "fruit_time": 40.0,
		"value": 58, "kg": 0.45, "r": 9, "fs": 10,
		"slots": [Vector2(-5, -13), Vector2(5, -18), Vector2(-5, -25), Vector2(5, -30)], "chance": 0.6, "stock": [1, 4]},
	"tulip": {"name": "Tulip", "rar": "rare", "price": 950, "grow": 120.0, "multi": false, "fruit_time": 0.0,
		"value": 1450, "kg": 0.05, "r": 6, "fs": 10, "slots": [Vector2(0, -20)], "chance": 0.5, "stock": [1, 3]},
	"blueberry": {"name": "Blueberry", "rar": "rare", "price": 1400, "grow": 180.0, "multi": true, "fruit_time": 60.0,
		"value": 160, "kg": 0.17, "r": 10, "fs": 6,
		"slots": [Vector2(-8, -8), Vector2(7, -7), Vector2(-3, -14), Vector2(4, -17), Vector2(1, -8)], "chance": 0.5, "stock": [1, 3]},
	"mushroom": {"name": "Mushroom", "rar": "rare", "price": 2400, "grow": 240.0, "multi": false, "fruit_time": 0.0,
		"value": 3800, "kg": 2.5, "r": 12, "fs": 22, "slots": [Vector2(0, -11)], "chance": 0.35, "stock": [1, 2]},
	"bamboo": {"name": "Bamboo", "rar": "legendary", "price": 3200, "grow": 300.0, "multi": false, "fruit_time": 0.0,
		"value": 5200, "kg": 3.8, "r": 7, "fs": 13, "slots": [Vector2(0, -7)], "chance": 0.3, "stock": [1, 2]},
	"cactus": {"name": "Cactus", "rar": "legendary", "price": 3600, "grow": 360.0, "multi": true, "fruit_time": 60.0,
		"value": 300, "kg": 0.6, "r": 11, "fs": 8,
		"slots": [Vector2(-12, -23), Vector2(12, -28), Vector2(0, -40), Vector2(-4, -27), Vector2(5, -19)], "chance": 0.25, "stock": [1, 2]},
	"watermelon": {"name": "Watermelon", "rar": "legendary", "price": 4200, "grow": 360.0, "multi": false, "fruit_time": 0.0,
		"value": 5800, "kg": 7.0, "r": 12, "fs": 20, "slots": [Vector2(0, -8)], "chance": 0.3, "stock": [1, 3]},
	"mango": {"name": "Mango", "rar": "legendary", "price": 6500, "grow": 420.0, "multi": true, "fruit_time": 120.0,
		"value": 950, "kg": 0.6, "r": 15, "fs": 10,
		"slots": [Vector2(-14, -27), Vector2(14, -29), Vector2(-4, -36), Vector2(8, -42), Vector2(-15, -40)], "chance": 0.18, "stock": [1, 1]},
	"coconut": {"name": "Coconut", "rar": "mythical", "price": 14000, "grow": 480.0, "multi": true, "fruit_time": 90.0,
		"value": 1900, "kg": 1.4, "r": 13, "fs": 9,
		"slots": [Vector2(-4, -46), Vector2(5, -45), Vector2(-9, -44), Vector2(10, -43)], "chance": 0.12, "stock": [1, 1]},
	"apple": {"name": "Apple", "rar": "mythical", "price": 45000, "grow": 600.0, "multi": true, "fruit_time": 120.0,
		"value": 5600, "kg": 0.25, "r": 15, "fs": 9,
		"slots": [Vector2(-14, -28), Vector2(13, -30), Vector2(-5, -38), Vector2(7, -42), Vector2(-16, -40), Vector2(16, -41)], "chance": 0.08, "stock": [1, 1]},
	"grape": {"name": "Grape Vine", "rar": "mythical", "price": 110000, "grow": 720.0, "multi": true, "fruit_time": 150.0,
		"value": 12000, "kg": 2.8, "r": 13, "fs": 10,
		"slots": [Vector2(-12, -19), Vector2(0, -19), Vector2(12, -19), Vector2(-8, -30), Vector2(7, -31), Vector2(0, -13)], "chance": 0.06, "stock": [1, 1]},
	"pumpkin": {"name": "Pumpkin", "rar": "divine", "price": 140000, "grow": 600.0, "multi": false, "fruit_time": 0.0,
		"value": 210000, "kg": 6.5, "r": 12, "fs": 20, "slots": [Vector2(0, -9)], "chance": 0.04, "stock": [1, 1]},
	"dragon": {"name": "Dragon Fruit", "rar": "divine", "price": 750000, "grow": 900.0, "multi": true, "fruit_time": 120.0,
		"value": 28000, "kg": 0.5, "r": 11, "fs": 10,
		"slots": [Vector2(-10, -14), Vector2(10, -17), Vector2(-9, -28), Vector2(9, -32), Vector2(0, -38)], "chance": 0.03, "stock": [1, 1]},
	"starfall": {"name": "Starfall Tree", "rar": "prismatic", "price": 4500000, "grow": 1200.0, "multi": true, "fruit_time": 180.0,
		"value": 240000, "kg": 1.2, "r": 15, "fs": 10,
		"slots": [Vector2(-14, -28), Vector2(14, -30), Vector2(-5, -39), Vector2(7, -44), Vector2(-16, -41), Vector2(16, -42)], "chance": 0.01, "stock": [1, 1]},
}

## Seed ids used by earlier versions, so old saves keep working. Each pair has
## the same number of fruit slots, so fruit already growing stays valid.
const LEGACY_SEEDS := {
	"moon": "starfall", "sunroot": "carrot", "jellyberry": "strawberry", "bubbleplum": "blueberry",
	"bellbloom": "tulip", "honeypod": "tomato", "starlily": "daffodil", "sugarcob": "corn",
	"cloudmelon": "watermelon", "lanternsquash": "pumpkin", "rubypear": "apple", "crystalreed": "bamboo",
	"stormnut": "coconut", "emberthistle": "cactus", "wyrmfruit": "dragon", "phoenix": "mango",
	"glowcap": "mushroom", "aurora": "grape",
}

## kind drives the click behaviour. pack = charges per purchase.
const GEAR := {
	"shovel": {"name": "Shovel", "kind": "shovel", "price": 0, "perm": true, "hidden": true,
		"desc": "Digs up a plant or removes placed gear."},
	"watering_can": {"name": "Watering Can", "kind": "water", "price": 150, "pack": 10, "chance": 1.0, "stock": [3, 6],
		"desc": "10 uses. Click a plant: grows it 15% instantly."},
	"trowel": {"name": "Trowel", "kind": "trowel", "price": 1000, "pack": 5, "chance": 0.8, "stock": [1, 3],
		"desc": "5 uses. Click a plant, then a new spot to move it."},
	"golden_sickle": {"name": "Golden Sickle", "kind": "sickle", "price": 7500, "perm": true,
		"desc": "Forever. Click to harvest everything ripe nearby."},
	"basic_sprinkler": {"name": "Tin Sprinkler", "kind": "place", "price": 2000, "chance": 0.9, "stock": [1, 3],
		"radius": 40.0, "time": 300.0, "growth": 0.25, "size": 0.0, "luck": 1.0, "desc": "5 min. +25% growth nearby."},
	"adv_sprinkler": {"name": "Brass Sprinkler", "kind": "place", "price": 15000, "chance": 0.6, "stock": [1, 2],
		"radius": 56.0, "time": 300.0, "growth": 0.5, "size": 0.1, "luck": 1.0, "desc": "5 min. +50% growth, +10% fruit size."},
	"godly_sprinkler": {"name": "Royal Sprinkler", "kind": "place", "price": 120000, "chance": 0.25, "stock": [1, 1],
		"radius": 72.0, "time": 300.0, "growth": 1.0, "size": 0.25, "luck": 1.0, "desc": "5 min. +100% growth, +25% fruit size."},
	"lucky_gnome": {"name": "Lucky Gnome", "kind": "place", "price": 50000, "chance": 0.35, "stock": [1, 1],
		"radius": 48.0, "time": 600.0, "growth": 0.0, "size": 0.0, "luck": 3.0, "desc": "10 min. Triple Golden & Rainbow luck nearby."},
	"rain_totem": {"name": "Rain Totem", "kind": "totem", "weather": "rain", "price": 25000, "chance": 0.4, "stock": [1, 2],
		"desc": "One use. Calls the rain right now."},
	"storm_totem": {"name": "Storm Totem", "kind": "totem", "weather": "storm", "price": 150000, "chance": 0.15, "stock": [1, 1],
		"desc": "One use. Calls a thunderstorm right now."},
	"backpack": {"name": "Bigger Backpack", "kind": "upgrade", "price": 1000,
		"desc": "+50 fruit capacity. Price doubles each time."},
}

## mult is the sell multiplier. tint picks the fruit recolor.
const MUTATIONS := {
	"golden": {"name": "Golden", "mult": 20.0, "color": "#ffd23f"},
	"rainbow": {"name": "Rainbow", "mult": 50.0, "color": "#ff7ae0"},
	"wet": {"name": "Wet", "mult": 2.0, "color": "#6ec6ff"},
	"chilled": {"name": "Chilled", "mult": 2.0, "color": "#bfeaff"},
	"frozen": {"name": "Frozen", "mult": 10.0, "color": "#7fdcff"},
	"shocked": {"name": "Shocked", "mult": 100.0, "color": "#fff36b"},
	"moonlit": {"name": "Moonlit", "mult": 2.0, "color": "#b79bff"},
}
const TINT_ORDER := ["rainbow", "golden", "frozen", "shocked", "moonlit", "chilled"]
const GOLD_CHANCE := 0.01
const RAINBOW_CHANCE := 0.001

const WEATHER := {
	"rain": {"name": "Rain", "time": 90.0, "growth": 1.5, "desc": "Plants grow 50% faster. Fruit may turn Wet."},
	"frost": {"name": "Frost", "time": 90.0, "growth": 1.0, "desc": "Fruit may turn Chilled. Wet fruit may freeze."},
	"storm": {"name": "Thunderstorm", "time": 75.0, "growth": 2.0, "desc": "Plants grow twice as fast. Lightning shocks fruit!"},
	"golden_hour": {"name": "Golden Hour", "time": 60.0, "growth": 1.25, "desc": "Sunlight may turn fruit Golden."},
}

const SEASON_DAYS := 5
## growth: how fast plants grow outside. weather: the odds of each kind of weather.
## tint: laid over the ground, so the garden shows the season.
const SEASONS := [
	{"name": "Spring", "growth": 1.15, "color": "#8ee05a", "tint": "#00000000",
		"weather": {"rain": 6, "frost": 1, "storm": 2, "golden_hour": 1}, "desc": "Plants grow a little faster."},
	{"name": "Summer", "growth": 1.3, "color": "#ffd23f", "tint": "#ffe08a1c",
		"weather": {"rain": 2, "frost": 0, "storm": 3, "golden_hour": 3}, "desc": "Plants grow fastest. Golden Hours are common."},
	{"name": "Autumn", "growth": 1.0, "color": "#ff9a4a", "tint": "#d9822b38",
		"weather": {"rain": 5, "frost": 2, "storm": 2, "golden_hour": 1}, "desc": "Get ready: winter comes next."},
	{"name": "Winter", "growth": 0.6, "color": "#bfeaff", "tint": "#e8f4ff70",
		"weather": {"rain": 0, "frost": 8, "storm": 0, "golden_hour": 1}, "desc": "Plants outside grow slowly and may die of cold."},
]
const WINTER_SEASON := 3
## Chance per second that a plant outside dies in winter. Frost makes it worse.
const WINTER_DEATH_CHANCE := 0.0004
const FROST_DEATH_FACTOR := 3.0

## Plants kept here grow at normal speed all year and are safe from the cold.
const GREENHOUSE_SLOTS := 20

const DAILY_QUEST_COUNT := 3
## Quests are picked from these each day. %s is the amount; n grows with the days.
const DAILY_QUESTS := {
	"planted": {"text": "Plant %s crops", "n": 3, "per_day": 1, "max": 25, "reward": 1.0},
	"harvested": {"text": "Harvest %s crops", "n": 3, "per_day": 2, "max": 60, "reward": 1.0},
	"earned": {"text": "Earn %s", "money": true, "reward": 2.0},
	"seeds_bought": {"text": "Buy %s seeds", "n": 3, "per_day": 1, "max": 20, "reward": 1.0},
	"gear_bought": {"text": "Buy something at the Gear Shop", "n": 1, "per_day": 0, "max": 1, "reward": 1.5},
}
## The first day teaches the basic loop.
const FIRST_DAY_QUESTS := ["planted", "harvested", "earned"]

const TIPS := [
	"Ripe fruit sparkles. Hold the mouse and sweep to harvest quickly.",
	"Rain makes plants grow faster and can make fruit Wet.",
	"Bushes and trees keep giving fruit after every harvest.",
	"The bigger the fruit, the more it sells for.",
	"Golden fruit sells for 20 times the price. Rainbow for 50!",
	"Your garden keeps growing while you are away.",
	"The shops restock every 4 minutes. Check back for rare seeds.",
	"Winter can kill plants outside. Keep them safe in the Greenhouse.",
	"You get 3 new quests every day. Press QUESTS to see them.",
]


static func seed_item(id: String) -> String:
	return "seed:" + id


static func gear_item(id: String) -> String:
	return "gear:" + id


static func item_name(key: String) -> String:
	var parts := key.split(":")
	if parts[0] == "seed":
		return SEEDS[parts[1]]["name"] + " Seed"
	return GEAR[parts[1]]["name"]


## Fence and gate gap together define where gear may be placed.
## Cobblestone ground: central walk, plaza around the fountain, the road outside the gate.
static func on_path(x: float, y: float) -> bool:
	if x >= 448 and x < 512 and y >= 180 and y < 608:
		return true
	if y >= 608 and y < 672:
		return true
	var dx := x - FOUNTAIN.x
	var dy := y - (FOUNTAIN.y + 4.0)
	return dx * dx + dy * dy < 80.0 * 80.0


static func fence_inner() -> Rect2:
	return Rect2((FENCE_X1 + 1) * TILE, (FENCE_Y1 + 1) * TILE,
		(FENCE_X2 - FENCE_X1 - 1) * TILE, (FENCE_Y2 - FENCE_Y1 - 1) * TILE)
