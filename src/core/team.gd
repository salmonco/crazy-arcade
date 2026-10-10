class_name Team
extends RefCounted

const COLOR_PALETTE: Array[Color] = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.ORANGE,
	Color.PURPLE,
]
const MONSTER_COLOR := Color.BLUE
const PLAYER_COLOR := Color.RED
const SECOND_PLAYER_COLOR := Color.BLUE

static func colors(characters: Array[Character]) -> Array[Color]:
	var team: Array[Color] = []
	for character in characters:
		var color = character.color
		if color not in team:
			team.append(color)
	return team
