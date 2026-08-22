class_name ObjectiveCard
extends RefCounted

## Objective cards are authored at a fixed height, but their copy is localized
## and steps differ in length. English step 2 of the Wake Room chain needs 95px
## in a 74px card, so the last line ("...field notes.") was simply cut off.
##
## Rather than hand-tuning a height per string per language, the card measures
## the wrapped text and grows to fit it.

const PADDING_TOP: float = 10.0
const PADDING_BOTTOM: float = 12.0


## Resize `body` to the height its wrapped text needs, then grow `panel` to
## contain it. Panels here are anchored to a corner with offsets, so the height
## is expressed by moving the bottom edge relative to the top one.
static func fit(panel: Panel, title: Label, body: Label) -> void:
	if panel == null or title == null or body == null:
		return
	var needed := text_height(body)
	if needed <= 0.0:
		return
	body.size.y = needed
	var card_height := body.position.y + needed + PADDING_BOTTOM
	panel.offset_bottom = panel.offset_top + card_height
	panel.size.y = card_height


## Height the label's current text needs at its current width.
static func text_height(label: Label) -> float:
	var font := label.get_theme_font("font")
	if font == null:
		return 0.0
	var font_size := label.get_theme_font_size("font_size")
	var width := label.size.x
	if width <= 0.0:
		return 0.0
	return font.get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		font_size
	).y
