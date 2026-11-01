# Refusal codes (GDD 23 table, GDD 6 Edge Cases): codes, never text; the HUD
# translates them.
class_name Refusal
extends RefCounted

const COMMANDS_LOCKED := &"COMMANDES_VERROUILLÉES"
const MATCH_OVER := &"PARTIE_TERMINÉE"
const NOT_YOUR_TURN := &"PAS_VOTRE_TOUR"
const UNKNOWN_COMMAND := &"COMMANDE_INCONNUE"
const UNKNOWN_UNIT := &"UNITÉ_INCONNUE"
const UNIT_ASLEEP := &"UNITÉ_ENDORMIE"
const ALREADY_MOVED := &"DÉJÀ_DÉPLACÉE"
const UNIT_IMMOBILE := &"UNITÉ_IMMOBILE"
const OUT_OF_RANGE := &"HORS_DE_PORTÉE"
const TILE_BLOCKED := &"CASE_BLOQUÉE"
const NOTHING_TO_UNDO := &"RIEN_À_ANNULER"
const MOVE_REVEALED := &"DÉPLACEMENT_A_RÉVÉLÉ"
const OTHER_ACTION_SINCE := &"AUTRE_ACTION_DEPUIS"
## Internal turn commands out of their sequence (GDD 3, States and Transitions).
const WRONG_PHASE := &"PHASE_INCORRECTE"
## COMMENCER_LE_TOUR beyond T_MAX: the match must end instead (GDD 3 rule 6).
const TURN_LIMIT := &"LIMITE_DE_TOURS"
