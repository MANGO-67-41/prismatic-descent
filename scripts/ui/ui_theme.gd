class_name UITheme
extends RefCounted
## Shared look for every menu: palette, pixel font, label styles.
## Palette comes from the zone 1 dusk -> depth range in the pixel-art-style skill.

const CREAM := Color("f2e2bc")
const CREAM_DIM := Color("b9a888")
const RUST := Color("a8512d")
const RUST_DARK := Color("5a2a22")
const INK := Color("120d14")
const PRISM_HUE := 0.52

## Rodondo has a single weight, so `bold` only changes the cache key. Pixelify Sans stays in
## assets/fonts/ as a pixel-grid alternative (swap the path to try it).
const FONT_FILE := "res://assets/fonts/Rodondo.otf"

static var _font_cache: Dictionary = {}


static func font(bold: bool = false, glyph_spacing: int = 0) -> Font:
	var key := "%s_%d" % [bold, glyph_spacing]
	if _font_cache.has(key):
		return _font_cache[key]
	var base: FontFile = load(FONT_FILE)
	base.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	base.hinting = TextServer.HINTING_NONE
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	base.generate_mipmaps = false
	var variation := FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = glyph_spacing
	variation.spacing_space = 3  # the font's native word space is too tight at menu sizes
	_font_cache[key] = variation
	return variation


static func label_settings(
	size: int,
	color: Color = CREAM,
	bold: bool = false,
	glyph_spacing: int = 0,
	outline: int = 1
) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = font(bold, glyph_spacing)
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = INK
	settings.shadow_size = 0
	return settings


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_outline_color", "Label", INK)
	theme.set_constant("outline_size", "Label", 2)
	return theme
