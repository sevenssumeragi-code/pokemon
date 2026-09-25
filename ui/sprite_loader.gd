class_name SpriteLoader
extends RefCounted
## Loads assets/monsters/{id}_front.png / {id}_back.png; generates a placeholder when missing.

static var _cache: Dictionary = {}

static func get_texture(species_id: String, back: bool = false) -> Texture2D:
	var key := species_id + ("_back" if back else "_front")
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/monsters/%s.png" % key
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = _placeholder(species_id, back)
	_cache[key] = tex
	return tex

## Deterministic placeholder: colored rounded body by primary type + initials.
static func _placeholder(species_id: String, back: bool) -> Texture2D:
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var sp := GameData.get_species(species_id)
	var t: String = sp.get("types", ["normal"])[0] if not sp.is_empty() else "normal"
	var col := type_color(t)
	var col2 := col.darkened(0.35)
	var cx := size / 2.0
	var cy := size * (0.58 if back else 0.55)
	var rx := size * 0.36
	var ry := size * (0.30 if back else 0.34)
	for y in range(size):
		for x in range(size):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var d := dx * dx + dy * dy
			if d <= 1.0:
				img.set_pixel(x, y, col if d < 0.8 else col2)
	# head bump
	var hx := cx + (size * 0.12 if not back else -size * 0.1)
	var hy := cy - ry * 0.9
	var hr := size * 0.17
	for y in range(size):
		for x in range(size):
			if (x - hx) * (x - hx) + (y - hy) * (y - hy) <= hr * hr:
				img.set_pixel(x, y, col)
	if not back:
		# eye
		for y in range(int(hy - 3), int(hy + 3)):
			for x in range(int(hx + 4), int(hx + 10)):
				if x >= 0 and x < size and y >= 0 and y < size:
					img.set_pixel(x, y, Color.BLACK)
	return ImageTexture.create_from_image(img)

static func type_color(t: String) -> Color:
	match t:
		"normal": return Color("a8a878")
		"fire": return Color("f08030")
		"water": return Color("6890f0")
		"electric": return Color("f8d030")
		"grass": return Color("78c850")
		"ice": return Color("98d8d8")
		"fighting": return Color("c03028")
		"poison": return Color("a040a0")
		"ground": return Color("e0c068")
		"flying": return Color("a890f0")
		"psychic": return Color("f85888")
		"bug": return Color("a8b820")
		"rock": return Color("b8a038")
		"ghost": return Color("705898")
		"dragon": return Color("7038f8")
		"dark": return Color("705848")
		"steel": return Color("b8b8d0")
		"fairy": return Color("ee99ac")
	return Color("999999")
