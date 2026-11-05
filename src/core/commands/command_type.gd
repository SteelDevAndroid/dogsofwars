# Stable integer ids of the command types (ADR-0004 §1 and §2): the codec writes
# them; never renumber.
class_name CommandType
extends RefCounted

const MOVE := 0
const ATTACK := 1
const CAPTURE := 2
const WAKE := 3
const UPGRADE_NODE := 4
const RESEARCH := 5
const END_TURN := 6
const ABANDON := 7
const UNDO_MOVE := 8
const BEGIN_TURN := 9
const ANNOUNCE_INTENTIONS := 10
const EXECUTE_INTENTION := 11
const VALIDATE_RUIN_READ := 12
const ABILITY := 13
const COUNT := 14
