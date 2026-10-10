class_name RoomView
extends Control

const PLAYER_SLOT_TEXTURE: Texture2D = preload("res://assets/characters/bazzi_down.png")
const PLAYER_SLOT_MASK: Texture2D = preload("res://assets/characters/bazzi_down_mask.png")
const NPC_SLOT_TEXTURE: Texture2D = preload("res://assets/npcs/zomkkan_down.png")
const NPC_SLOT_MASK: Texture2D = preload("res://assets/npcs/zomkkan_down_mask.png")
const RECOLOR_SHADER: Shader = preload("res://src/game/character_recolor.gdshader")

const SEAT_COUNT := 4
const CARD_SIZE := Vector2(132, 214)
const PORTRAIT_SIZE := Vector2(112, 160)
const CHIP_SIZE := Vector2(44, 44)
const CHIP_CORNER_RADIUS := 8
const CHIP_BORDER_WIDTH := 3
const CHIP_BORDER_COLOR := Color(1, 1, 1, 0.9)

var peer_id: int
var _snapshot: Dictionary = {}

signal color_chosen(number: int, color: Color)

@onready var slots: HBoxContainer = %Slots
@onready var room_id_label: Label = %RoomIdLabel
@onready var local_multi_check: Button = %LocalMultiCheck
@onready var monster_mode_check: Button = %MonsterModeCheck
@onready var start_button: Button = %StartButton
@onready var leave_button: Button = %LeaveButton
@onready var palette: HBoxContainer = %Palette

func _ready() -> void:
	for color in Team.COLOR_PALETTE:
		palette.add_child(_create_chip(color))

func render(snapshot: Dictionary, my_peer_id: int) -> void:
	_snapshot = snapshot
	peer_id = my_peer_id
	_clear_slots()
	var seats: Array = snapshot["seats"]
	for number in maxi(SEAT_COUNT, seats.size()):
		if number < seats.size():
			slots.add_child(_create_slot(seats[number]))
		else:
			slots.add_child(_create_empty_slot())
	room_id_label.text = "방 %s" % snapshot["id"].substr(0, 8)
	start_button.disabled = not snapshot["can_battle_start"]
	monster_mode_check.set_pressed_no_signal(snapshot["mode"] == BattleMode.MONSTER)
	local_multi_check.set_pressed_no_signal(snapshot["local_multi_on"])

func slot_count() -> int:
	return _taken_cards().size()

func slot(index: int) -> TextureRect:
	return _taken_cards()[index].get_node("Box/Portrait")

func slot_label(index: int) -> String:
	var label: Label = _taken_cards()[index].get_node("Box/NamePlate/Name")
	return label.text

func chip_count() -> int:
	return palette.get_child_count()

func chip(index: int) -> Button:
	return palette.get_child(index)

func chip_color(index: int) -> Color:
	var style: StyleBoxFlat = chip(index).get_theme_stylebox("normal")
	return style.bg_color

func _taken_cards() -> Array[Node]:
	var taken: Array[Node] = []
	for card in slots.get_children():
		if card.has_meta("character"):
			taken.append(card)
	return taken

func _human_count(room: Room) -> int:
	var count := 0
	for character in room.characters():
		if character is Npc:
			continue
		count += 1
	return count

func _clear_slots() -> void:
	for slot_node in slots.get_children():
		slots.remove_child(slot_node)
		slot_node.queue_free()

func _create_slot(character: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SlotCard"
	card.custom_minimum_size = CARD_SIZE
	card.set_meta("character", character)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(_create_portrait(character))
	box.add_child(_create_name_plate(character))
	return card

func _create_portrait(seat: Dictionary) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = NPC_SLOT_TEXTURE if seat["is_npc"] else PLAYER_SLOT_TEXTURE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var recolor := ShaderMaterial.new()
	recolor.shader = RECOLOR_SHADER
	recolor.set_shader_parameter("color", seat["color"])
	recolor.set_shader_parameter("mask_texture", NPC_SLOT_MASK if seat["is_npc"] else PLAYER_SLOT_MASK)
	portrait.material = recolor
	return portrait

func _create_name_plate(seat: Dictionary) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.name = "NamePlate"
	var style := StyleBoxFlat.new()
	style.bg_color = seat["color"]
	style.set_corner_radius_all(8)
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	plate.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "Name"
	label.text = "NPC" if seat["is_npc"] else "%dP" % seat["number"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 22)
	plate.add_child(label)
	return plate

func _create_empty_slot() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SlotCardEmpty"
	card.custom_minimum_size = CARD_SIZE

	var label := Label.new()
	label.text = "비어 있음"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.53, 0.76, 0.95))
	label.add_theme_font_size_override("font_size", 20)
	card.add_child(label)
	return card

func _create_chip(color: Color) -> Button:
	var chip_button := Button.new()
	chip_button.custom_minimum_size = CHIP_SIZE
	chip_button.tooltip_text = "#%s" % color.to_html(false)
	chip_button.set_meta("color", color)
	chip_button.add_theme_stylebox_override("normal", _chip_style(color, 0))
	chip_button.add_theme_stylebox_override("hover", _chip_style(color, CHIP_BORDER_WIDTH))
	chip_button.add_theme_stylebox_override("pressed", _chip_style(color, CHIP_BORDER_WIDTH))
	chip_button.pressed.connect(_choose_color.bind(color))
	return chip_button

func _choose_color(color: Color) -> void:
	var numbers := my_character_numbers()
	if numbers.is_empty():
		return
	color_chosen.emit(numbers[0], color)

func _chip_style(color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(CHIP_CORNER_RADIUS)
	style.set_border_width_all(border_width)
	style.border_color = CHIP_BORDER_COLOR
	return style

func my_character_numbers() -> Array[int]:
	var numbers: Array[int] = []
	for seat in _seats():
		if not seat["is_npc"] and seat["peer_id"] == peer_id:
			numbers.append(seat["number"])
	numbers.sort()
	return numbers

func _seats() -> Array:
	return _snapshot.get("seats", [])
