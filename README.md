# Grow a Garden 2D

Top-down pixel gardening game made with Godot 4.7. Single player, plus the Garden Times multiplayer, with music, sound effects and ambience.

## Play

Run `build/GrowAGarden2D.exe`, or open this folder in Godot 4.7 and press F5.

| Controls | |
|---|---|
| WASD / arrows, Shift | Walk, run |
| Left click | Plant exactly where you click, harvest, use the held item |
| Hold left and move | Sweep harvest, drag planting |
| Right click / Q | Put the item away |
| Hold right and move | Look around |
| 1-9, mouse wheel | Choose a hotbar item |
| E | Harvest around the gardener |
| Z / X / C / B | Seed shop / Gear shop / Sell / Backpack |
| Esc | Close, or pause |

## Garden Times

- **Garden Club**: up to 4 members share one garden. The database only passes messages on. Every member keeps a copy in a file, and whoever has the newest runs the garden while the others follow. If that player leaves, the next one takes over.
- **Open Village**: Play lands on a random server of up to 6 gardeners, each with their own garden, which others can visit. A single-player garden can be uploaded as a copy, which then syncs to the account.

Everything is built around Firebase's free plan (100 connections, 10 GB a month): one stream per player, writes batched over a reused connection, walking sent only when it changes, growth computed on each side rather than sent, and a garden sent to a neighbour only while they are visiting.

To switch accounts on, fill in `scripts/net/net_config.gd` and paste the rules into the console. The free plan's limit of 100 connections means about 100 players at once.

## Project layout

- `scripts/core/` - rules and content with no rendering (`game_data.gd`, `garden_sim.gd`, and `shared_sim.gd` for a garden several people see).
- `scripts/net/`, `scripts/autoload/net.gd` - Garden Times: Firebase connection, sessions, keeping copies of a garden in step.
- `firebase/database.rules.json` - who may read and write what. Paste it into the Firebase console.
- `scripts/world/` - what the garden looks like on screen, driven by events from the simulation.
- `scripts/ui/`, `scripts/scenes/`, `scripts/autoload/` - interface, screens, shared services.
- `tools/art/` - every texture is drawn by code here. `assets/` holds the generated result.
- `tools/audio/recorded/`, `tools/import_sounds.gd` - free CC0 recordings and their conversion into `assets/sounds/`. Credits are in `assets/sounds/CREDITS.md`.
- `tests/` - rules tests.

## Commands

Regenerate textures after changing `tools/art/`:

```bash
godot --headless --path . --script tools/generate_art.gd
godot --headless --path . --import
```

Rebuild the sounds (needs ffmpeg). This also writes `build/sound_preview.wav`, every sound in a row:

```bash
godot --headless --path . --script tools/import_sounds.gd
godot --headless --path . --import
```

Run the rules tests:

```bash
godot --headless --path . --script tests/test_sim.gd
```

Run the multiplayer tests, with real accounts on the local Firebase emulators:

```bash
npx firebase emulators:exec --project demo-gag --only auth,database "GG_EMULATOR=1 GODOT=/path/to/godot bash tests/run_net_test.sh"
```

Automated play-through with screenshots. It uses its own save file and stays silent:

```bash
GG_TOUR=/some/folder godot --path .
```

On Windows, `tools/run_hidden.ps1` runs a program on a hidden desktop, so the tour's window stays off the screen:

```powershell
$env:GG_TOUR = "C:\some\folder"; .\tools\run_hidden.ps1 -Exe "$PWD\build\GrowAGarden2D.exe" -OutDir "C:\some\folder"
```

Build the Windows game:

```bash
godot --headless --path . --export-release "Windows" build/GrowAGarden2D.exe
```

Build the Android game. Put the keystore in `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD` first; signing with the debug keystore is fine for testing, but not for a store:

```bash
godot --headless --path . --export-release "Android" build/GrowAGarden2D.apk
```
