# Building

## Automated build (recommended)

The repo ships a GitHub Actions pipeline (`.github/workflows/build-android.yml`):

1. **smoke-test** job — downloads Godot 4.4.1 headless, imports the project and runs
   90 frames of the full game headless (`--smoke` arg bypasses the menu and the asset
   download requirement). Catches GDScript parse/runtime errors before packaging.
2. **build-apk** job — installs Java 17 + Android SDK (platform 34, build-tools 34),
   Godot 4.4.1 + export templates, generates a debug keystore, and runs:
   ```bash
   godot --headless --path . --export-release "Android" build/GrandOpenWorld.apk
   ```
3. Validates the APK (`lib/arm64-v8a` + `classes.dex` present) and uploads it as an
   artifact. Version tags (`v*`) also publish a GitHub Release with the APK.

## Asset pack workflow

`.github/workflows/generate-assets.yml` (manual dispatch or `assets-v*` tag) runs
`tools/generate_asset_packs.py`, which procedurally generates:

- `pack_textures.zip` — 4096px versions of all 15 world textures
- `pack_audio.zip` — 10-minute original music tracks (320 kbps Ogg Vorbis), added
  adaptively until the combined packs total ~1 GB

and publishes them to the `assets-v1` release together with a `manifest.json`.
The in-game downloader fetches exactly these files.

## Manual local build

Requirements:

- Godot 4.4.1 (editor or headless binary)
- Android SDK with `platforms;android-34` and `build-tools;34.0.0`
- Java 17+ (for `keytool`)

```bash
# debug keystore (once)
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keysize 2048 -validity 10000 \
  -keypass android -storepass android -keystore debug.keystore \
  -dname "CN=Android Debug,O=Android,C=US"

# import assets then export
godot --headless --path . --import
godot --headless --path . --export-release "Android" build/GrandOpenWorld.apk
```

If Godot cannot find the Android SDK, set it in Editor Settings
(`Export > Android > Android SDK Path`) or write `~/.config/godot/editor_settings-4.4.tres`:

```
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path="/path/to/android-sdk"
```

## Troubleshooting

- **"No export template found"** — install templates: editor > Manage Export Templates,
  or place them in `~/.local/share/godot/export_templates/4.4.1.stable/`.
- **APK not signed** — the workflow generates a debug keystore; for Play Store builds,
  create a release keystore and fill the `keystore/release*` fields in `export_presets.cfg`.
- **Smoke test fails on CI but not locally** — delete `.godot/` and re-import; stale
  caches occasionally break headless runs.
