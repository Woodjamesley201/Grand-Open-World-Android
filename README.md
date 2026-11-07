# GRAND OPEN WORLD — Android

An original, fully playable **3D open-world crime sandbox** for Android, inspired by
the scale and freedom of GTA V — built in **Godot 4.4** with the mobile renderer,
ARM64 support, and a fully automated GitHub Actions APK pipeline.

> 100% original content. Every model, texture, sound and music track is generated
> procedurally by code. No GTA or other copyrighted assets are used.

![Status](https://img.shields.io/badge/status-playable-green) ![Engine](https://img.shields.io/badge/engine-Godot%204.4-blue) ![Platform](https://img.shields.io/badge/platform-Android%20ARM64-orange)

## Quick install

1. Download **GrandOpenWorld.apk** from the
   [v1.0.0 release](https://github.com/Woodjamesley201/Grand-Open-World-Android/releases/download/v1.0.0/GrandOpenWorld.apk)
   (or grab the build artifact from [Actions](../../actions)).
2. Copy it to your Android 10+ phone and install it (allow "install from unknown sources").
3. On first launch the game shows a **main menu** and requires a one-time download of the
   **HD asset pack (~1 GB)** — textures and music are fetched from this repository's
   GitHub release and stored on your device.
4. Play. Landscape orientation, touch controls.

## Features

### Open world — the city of Oceanport
- Procedurally generated coastal city: **downtown skyscrapers**, commercial districts,
  residential neighborhoods, **luxury mansions**, **beachfront + boardwalk**, river with a
  **bridge**, a **tunnel** under downtown, **highway ring**, **industrial zone**,
  **airport** with runway/hangars/terminal, **mountains**, **countryside** with fields
  and barns, a park, gas stations, police stations, a hospital, and shops with enterable interiors.
- **Day/night cycle** (sun, moon, sky colors, street lights, lit windows, headlights).
- **Weather**: clear / cloudy / rain / storm (with lightning + thunder) / fog.
- Living city: **traffic** following the road grid with right-hand lanes, **pedestrians**
  walking, fleeing, and reacting to being hit.

### Player & vehicles
- Third-person character: walk / run / sprint / jump / crouch / **swim** (river & ocean),
  procedural animation, touch drag camera with collision.
- 9 original vehicles: sports car, supercar, sedan, SUV, motorcycle, pickup, van, bus,
  police cruiser — physics-based (VehicleBody3D) with suspension, damage, smoke, fire,
  explosions, headlights, brake lights, engine audio, horn, mobile driving controls.

### Gameplay systems
- **Original story** (8 missions) with original characters — Marcus Reed, Danny Chen,
  Sasha Molina, crime boss Vincent Kane — including races, ambushes, a heist, a boss fight.
- Side content: street races, courier runs, 30 hidden collectible packages.
- **Wanted system** (1–5 stars): police cars pursue, officers deploy on foot and shoot,
  line-of-sight search behavior, wanted decay when you break away.
- Shops: weapons (pistol/SMG/ammo/armor), clothes (customization), garage, gas/repair.
- Money, save/load (JSON), minimap with blips, pause menu, settings
  (low/medium/high quality, sensitivity, volume).

### Audio — all synthesized at runtime
Engine loops, sirens, horns, footsteps, gunfire, explosions, thunder, rain, city ambience,
UI blips, and generative music. The HD audio pack replaces music with studio-quality
encoded tracks after download.

### Android specifics
- ARM64-v8a only, Android 10+ (API 29+), landscape, touch UI (virtual joystick + buttons).
- Quality presets scale fog distance, shadows, traffic and pedestrian density.
- Object pooling for traffic / peds / police; MultiMesh rendering for buildings; the
  mobile renderer with ETC2/ASTC texture compression.
- First-run **asset download** (~1 GB) with progress, storage check and resumable packs.

## Repository layout

```
Grand-Open-World-Android/
├── project.godot              # Godot project (mobile renderer, landscape, autoloads)
├── export_presets.cfg         # Android ARM64 export preset
├── scenes/main.tscn           # boot scene
├── autoload/
│   ├── game_input.gd          # unified touch + keyboard input hub
│   └── game_state.gd          # economy, wanted, saves, settings
├── scripts/
│   ├── main.gd                # bootstrap: menu -> world -> systems
│   ├── menu/main_menu.gd      # main menu + mandatory asset downloader
│   ├── world/                 # city generator, day/night, weather, traffic, peds
│   ├── player/                # player character + third-person camera
│   ├── vehicles/              # vehicle factory + physics vehicle + AI driving
│   ├── police/                # wanted system + hostile NPC shooters
│   ├── game/                  # missions, shops, HUD, asset manager
│   ├── ui/                    # touch controls, pause menu
│   └── audio/                 # procedural sound + music synthesis
├── tools/generate_asset_packs.py   # CI asset pack generator (~1 GB)
└── .github/workflows/
    ├── build-android.yml      # smoke test + APK build + release
    └── generate-assets.yml    # HD asset pack build + release (assets-v1)
```

## Building from source

```bash
# 1. Open in Godot 4.4.1 (or run headless import)
godot --headless --path . --import

# 2. Export the APK (needs Android SDK + export templates)
godot --headless --path . --export-release "Android" build/GrandOpenWorld.apk
```

Or just push to `main` — GitHub Actions builds, validates and publishes the APK
automatically. See [docs/BUILDING.md](docs/BUILDING.md) for the full CI setup.

## Documentation

- [docs/BUILDING.md](docs/BUILDING.md) — local + CI builds, signing, troubleshooting
- [docs/GAMEPLAY.md](docs/GAMEPLAY.md) — controls and systems guide
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — code architecture tour
- [docs/ROADMAP.md](docs/ROADMAP.md) — planned features
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) — current limitations

## License

MIT — see [LICENSE](LICENSE). All assets are procedurally generated originals.
