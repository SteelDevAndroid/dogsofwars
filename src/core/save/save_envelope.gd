# Envelope of a save file (ADR-0006 §2): a fixed prefix (mark, envelope version, payload
# length, content schema, revision), the payload, then the SHA-256 of everything before.
# The prefix never changes, so the hash stays checkable whatever the content schema.
class_name SaveEnvelope
extends RefCounted

const MARK := "DOWS"
const VERSION := 1
const PREFIX_SIZE := 17
const HASH_SIZE := 32

const OK := &"OK"
const BAD_MARK := &"BAD_MARK"
const BAD_LENGTH := &"BAD_LENGTH"
const BAD_HASH := &"BAD_HASH"

var payload := PackedByteArray()
var content_schema := 0
var revision := 0


static func encode(p_payload: PackedByteArray, p_content_schema: int, p_revision: int) -> PackedByteArray:
	var bytes := MARK.to_ascii_buffer()
	bytes.resize(PREFIX_SIZE)
	bytes[4] = VERSION
	bytes.encode_u32(5, p_payload.size())
	bytes.encode_u32(9, p_content_schema)
	bytes.encode_u32(13, p_revision)
	bytes.append_array(p_payload)
	bytes.append_array(_hash(bytes))
	return bytes


## The envelope of `bytes`, or null with the failing check in `code[0]`: mark, then length,
## then hash, in that order (ADR-0006 §3); the content schema is for the caller to judge.
static func decode(bytes: PackedByteArray, code: Array) -> SaveEnvelope:
	if bytes.size() < PREFIX_SIZE + HASH_SIZE or bytes.slice(0, 4).get_string_from_ascii() != MARK or bytes[4] != VERSION:
		code[0] = BAD_MARK
		return null
	var length := bytes.decode_u32(5)
	if bytes.size() != PREFIX_SIZE + length + HASH_SIZE:
		code[0] = BAD_LENGTH
		return null
	var body := bytes.slice(0, PREFIX_SIZE + length)
	if _hash(body) != bytes.slice(PREFIX_SIZE + length):
		code[0] = BAD_HASH
		return null
	var envelope := SaveEnvelope.new()
	envelope.payload = bytes.slice(PREFIX_SIZE, PREFIX_SIZE + length)
	envelope.content_schema = bytes.decode_u32(9)
	envelope.revision = bytes.decode_u32(13)
	code[0] = OK
	return envelope


static func _hash(bytes: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()
