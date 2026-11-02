# "Soumettre un score" (GDD 3 rule 14, profile GDD rule 10): the profile score of a match
# that ended by domination or at turn 30. The profile keeps the maximum per (faction,
# difficulty) and ignores a match id it already took (it keeps the last 8).
class_name SubmitScoreEffect
extends ProfileEffect

## The single MVP difficulty, "Standard" (GDD 9 rule 25).
const DIFFICULTY_STANDARD := 0

var match_id: int
var faction: int
var difficulty: int
var score: int


func _init(p_match_id: int, p_faction: int, p_difficulty: int, p_score: int) -> void:
	match_id = p_match_id
	faction = p_faction
	difficulty = p_difficulty
	score = p_score
