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
const UNKNOWN_PROTOCOL := &"PROTOCOLE_INCONNU"
const PROTOCOL_ACQUIRED := &"PROTOCOLE_ACQUIS"
const RESEARCH_IN_PROGRESS := &"RECHERCHE_EN_COURS"
const PREREQUISITE_MISSING := &"PRÉREQUIS_MANQUANT"
## Params: need, available (GDD 10 rule 6).
const NOT_ENOUGH_ENERGY := &"ÉNERGIE_INSUFFISANTE"
## An AI attack or capture only comes from a stored intention (ADR-0004 §9).
const NO_INTENTION := &"AUCUNE_INTENTION"
## Shared by CAPTURER (not an Ouvrier or Bastion) and RÉVEILLER (not a pack unit).
const TYPE_NOT_CAPABLE := &"TYPE_NON_CAPABLE"
## RÉVEILLER: the target is not, on the faction's view, a visible sleeping unit at
## distance 1. One code, no parameter, for every way to fail (GDD 7 rule 2).
const NO_ADJACENT_DRONE := &"AUCUN_DRONE_ADJACENT"
const ALREADY_ACTED := &"DÉJÀ_AGI"
const NOT_ON_A_NODE := &"PAS_SUR_UN_NŒUD"
const NODE_ALREADY_OWNED := &"NŒUD_DÉJÀ_POSSÉDÉ"
## MONTER_NŒUD (GDD 11 rule 11).
const UNKNOWN_NODE := &"NŒUD_INCONNU"
const NODE_NOT_OWNED := &"NŒUD_NON_POSSÉDÉ"
const NODE_ACQUIRED_THIS_TURN := &"NŒUD_ACQUIS_CE_TOUR"
const MAX_LEVEL := &"NIVEAU_MAX"
const ALREADY_UPGRADED := &"DÉJÀ_MONTÉ"
const ATTACKER_WITHOUT_ATTACK := &"ATTAQUANT_SANS_ATTAQUE"
## Same code, no parameter, for a hidden, unknown, destroyed or stale target (GDD 5 rule 18).
const TARGET_NOT_VISIBLE := &"CIBLE_NON_VISIBLE"
const TARGET_NOT_HOSTILE := &"CIBLE_NON_HOSTILE"
const TARGET_OUT_OF_RANGE := &"CIBLE_HORS_DE_PORTÉE"
## Internal turn commands out of their sequence (GDD 3, States and Transitions).
const WRONG_PHASE := &"PHASE_INCORRECTE"
## COMMENCER_LE_TOUR beyond T_MAX: the match must end instead (GDD 3 rule 6).
const TURN_LIMIT := &"LIMITE_DE_TOURS"
