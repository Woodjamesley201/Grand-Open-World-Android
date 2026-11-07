# Architecture

Everything is built from code at runtime — the project ships **no binary assets**
(apart from the icon). All meshes are Godot primitives (Box/Cylinder/Sphere/Plane),
all textures are generated per-pixel with FastNoiseLite into ImageTextures, and all
audio is synthesized into AudioStreamWAVs. The HD asset pack downloaded on first
launch swaps in 4K textures and encoded music at runtime.

## Boot flow

```
main.tscn -> main.gd
   ├─ MainMenu (menu first: play requires the ~1 GB asset download)
   │    └─ AssetManager (HTTPRequest + ZIPReader -> user://assets)
   └─ start_game()
        ├─ WorldBuilder.build_all()   (coroutine, phased, progress text)
        │     ├─ DayNight (sun/sky/fog/street lights/window glow)
        │     ├─ WeatherSys (rain particles, lightning, fog density)
        │     ├─ TrafficManager (pooled VehicleBody3D cars, road-graph AI)
        │     └─ PedestrianManager (pooled PedBody kinematic walkers)
        ├─ PlayerChar + PlayerCamera (orbit camera w/ raycast collision)
        ├─ PoliceManager (wanted state machine) + ShooterNPC
        ├─ MissionSystem (story/side missions, shops, dialog UI, collectibles)
        ├─ HUD (CanvasLayer + SubViewport minimap + blip canvas)
        ├─ TouchControls (joystick + look area + context buttons)
        └─ AudioManager (procedural SFX/music; HD music from the pack)
```

## Key design decisions

- **Input**: every gameplay system reads the `GameInput` autoload; touch widgets and
  keyboard write into it. `driving_mode` flips the joystick between movement and
  steering/throttle/brake.
- **State**: `GameState` autoload owns money, wanted level, settings, weapons and
  JSON save/load. Emits signals the HUD consumes.
- **World**: the city is a 13×13 road grid (48 m pitch) over a 624 m square with
  districts by block coordinates; buildings render through MultiMesh (one draw call
  per material) with static collision boxes; mountains are a noise-displaced
  PlaneMesh with a trimesh collider. The ground has two collision slabs with a gap
  for the river + open ocean so swimming actually works.
- **Vehicles**: `VehicleBody3D` with `VehicleWheel3D`s for both the player and AI.
  Traffic AI follows the road-node graph with right-hand lane offsets and raycast
  obstacle braking; police pursuit steers directly at the player.
- **Performance**: MultiMesh batching, pooled traffic/peds/police, pooled street
  lights (8 OmniLights repositioned to the nearest lamp posts), fog-based draw
  distance, quality presets scaling shadows/fog/densities, mobile renderer + ASTC.
- **Assets**: AssetManager downloads `pack_textures.zip` + `pack_audio.zip` from the
  `assets-v1` GitHub release, extracts with ZIPReader, stamps a manifest into
  `user://assets/manifest.json` (which gates the PLAY button), and exposes
  `get_hd_texture()/get_hd_audio()` used by WorldBuilder and AudioManager.

## Save data

`user://save.json` — money, health/armor, weapons+ammo, customization colors,
completed missions, collected packages, owned vehicles, best race times, player
position and current vehicle id.
