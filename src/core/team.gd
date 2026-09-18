class_name Team
extends RefCounted

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
