## AssetManager - downloads the high-resolution asset packs from the GitHub
## release and extracts them into user://assets. The game requires these packs
## before it can be played (mandatory first-run download, ~1 GB).
class_name AssetManager
extends Node

signal pack_progress(pack_index: int, pack_name: String, received: int, total: int)
signal pack_done(pack_index: int, pack_name: String)
signal all_done()
signal download_error(message: String)

const RELEASE_BASE: String = "https://github.com/Woodjamesley201/Grand-Open-World-Android/releases/download/assets-v1/"
const MANIFEST_URL: String = RELEASE_BASE + "manifest.json"
const DOWNLOAD_DIR: String = "user://downloads/"
const ASSETS_DIR: String = "user://assets/"

var manifest: Dictionary = {}
var _hd_textures: Dictionary = {}
var _hd_streams: Dictionary = {}
var _dl_result: Array = []

func _on_http_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_dl_result = [result, response_code, headers, body]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func fetch_manifest() -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	http.use_threads = true
	http.request(MANIFEST_URL)
	var result: Array = await http.request_completed
	var body: PackedByteArray = result[3]
	http.queue_free()
	if result[1] != 200:
		return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	return {}

func total_download_bytes() -> int:
	var total := 0
	for pack in manifest.get("packs", []):
		total += int(pack.get("bytes", 0))
	return total

func download_all() -> bool:
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_DIR)
	DirAccess.make_dir_recursive_absolute(ASSETS_DIR)
	var packs: Array = manifest.get("packs", [])
	for i in range(packs.size()):
		var pack: Dictionary = packs[i]
		var fname := String(pack.get("file", ""))
		var url := RELEASE_BASE + fname
		var dest := DOWNLOAD_DIR + fname
		var ok := await _download_file(url, dest, i, fname)
		if not ok:
			download_error.emit("Failed to download " + fname)
			return false
		var extract_ok := _extract_zip(dest, ASSETS_DIR)
		if not extract_ok:
			download_error.emit("Failed to extract " + fname)
			return false
		DirAccess.remove_absolute(dest)
		pack_done.emit(i, fname)
	# stamp the version so the game knows assets are present
	var f := FileAccess.open(GameState.ASSET_VERSION_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": String(manifest.get("version", "v1"))}))
		f.close()
	GameState.assets_ready = true
	GameState.asset_version = String(manifest.get("version", "v1"))
	all_done.emit()
	return true

func _download_file(url: String, dest: String, index: int, name: String) -> bool:
	_dl_result = []
	var http := HTTPRequest.new()
	http.use_threads = true
	http.download_file = dest
	http.timeout = 0
	http.request_completed.connect(_on_http_completed)
	add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return false
	while _dl_result.is_empty():
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(http):
			return false
		pack_progress.emit(index, name, http.get_downloaded_bytes(), http.get_body_size())
	http.queue_free()
	return _dl_result[1] == 200

func _extract_zip(zip_path: String, dest_dir: String) -> bool:
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		return false
	var files := reader.get_files()
	for fname in files:
		if String(fname).ends_with("/"):
			continue
		var data := reader.read_file(fname)
		var out_path := dest_dir + String(fname)
		# create parent dirs
		var dir_parts := String(fname).split("/")
		var cur := dest_dir
		for j in range(dir_parts.size() - 1):
			cur += dir_parts[j] + "/"
			DirAccess.make_dir_recursive_absolute(cur)
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_buffer(data)
			f.close()
	reader.close()
	return true

func has_hd_texture(name: String) -> bool:
	return FileAccess.file_exists(ASSETS_DIR + "textures/" + name + ".png")

func get_hd_texture(name: String, max_size: int = 4096) -> ImageTexture:
	if _hd_textures.has(name):
		return _hd_textures[name]
	var path := ASSETS_DIR + "textures/" + name + ".png"
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		return null
	var dim := maxi(img.get_width(), img.get_height())
	if dim > max_size:
		var scale := float(max_size) / float(dim)
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(img)
	_hd_textures[name] = tex
	return tex

func get_hd_audio(name: String) -> AudioStreamOggVorbis:
	if _hd_streams.has(name):
		return _hd_streams[name]
	var path := ASSETS_DIR + "audio/" + name + ".ogg"
	if not FileAccess.file_exists(path):
		return null
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream != null:
		_hd_streams[name] = stream
	return stream

func list_hd_audio() -> Array:
	var out: Array = []
	var dir := DirAccess.open(ASSETS_DIR + "audio")
	if dir:
		for fname in dir.get_files():
			if String(fname).ends_with(".ogg"):
				out.append(String(fname).get_basename())
	return out

func available_storage_bytes() -> int:
	var dir := DirAccess.open("user://")
	if dir:
		return dir.get_space_left()
	return 0
