# PROTOTYPE - NOT FOR PRODUCTION
# Question: cout de copie/serialisation de 3 representations de l'etat (A colonnes packed, B objets RefCounted, C Dictionary/Array)
# Date: 2026-10-30
extends SceneTree

const M := 0xFFFFFFFF
const T := 256
const COPIES := 3000
const WARM := 300
const GROUPS := {
	"u": ["id", "type", "fac", "x", "y", "hp", "flags"],
	"n": ["id", "x", "y", "owner", "level"],
	"r": ["id", "x", "y", "zone", "read", "turn"],
	"i": ["id", "author", "target", "atile", "ttile", "type", "motive", "turn", "exec", "status", "reason"]}
const COUNT := {"u": 60, "n": 10, "r": 3, "i": 60}
const GKEY := {"u": "units", "n": "nodes", "r": "ruins", "i": "intents"}
const BYTE_COLS := ["t_owner", "t_color", "t_poi", "t_anchor", "vis0", "vis1"]

static func hash32(seed: int, c: int) -> int:
	var z := (seed + c * 0x9E3779B9) & 0xFFFFFFFF
	z = ((z ^ (z >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF
	z = ((z ^ (z >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
	return z ^ (z >> 16)

static func draw(seed: int, c: int, n: int) -> int:
	return hash32(seed, c) % n

static func gen(seed: int) -> Dictionary:
	var ctr := [0]
	var nx := func(m: int) -> int:
		ctr[0] += 1
		return draw(seed, ctr[0], m)
	var c := {}
	var hdr := []
	for k in 16: hdr.append(nx.call(1000))
	c["hdr"] = hdr
	for k in ["t_owner", "t_color", "t_poi", "t_anchor"]:
		var a := []
		for i in T: a.append(nx.call(4))
		c[k] = a
	for k in ["vis0", "vis1"]:
		var a := []
		for i in T * 2: a.append(nx.call(2))
		c[k] = a
	for g in GROUPS:
		for f in GROUPS[g]:
			var a := []
			for i in COUNT[g]: a.append(i * 3 + 1 if f == "id" else nx.call(200))
			c[g + "_" + f] = a
	return c

static func norm(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var o := {}
			for k in v:
				var kk = int(k) if (k is String and k.is_valid_int()) else k
				o[kk] = norm(v[k])
			return o
		TYPE_ARRAY:
			var o := []
			for e in v: o.append(norm(e))
			return o
		TYPE_FLOAT: return int(v)
	return v

static func eq(a, b) -> bool:
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for k in a:
			if not b.has(k) or not eq(a[k], b[k]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not eq(a[i], b[i]): return false
		return true
	return a == b

# ---------- A: colonnes packed ----------
class StateA:
	var cols := {}
	static func from_canon(c: Dictionary) -> StateA:
		var s := StateA.new()
		for k in c:
			s.cols[k] = PackedByteArray(c[k]) if k in ["t_owner", "t_color", "t_poi", "t_anchor", "vis0", "vis1"] else PackedInt32Array(c[k])
		return s
	static func from_data(d: Dictionary) -> StateA: return from_canon(d)
	func copy() -> StateA:
		var s := StateA.new()
		for k in cols: s.cols[k] = cols[k].duplicate()
		return s
	func canon() -> Dictionary:
		var o := {}
		for k in cols: o[k] = Array(cols[k])
		return o
	func to_var_data(): return cols
	func to_json_data(): return canon()
	func mutate(): cols["u_hp"][0] += 1

# ---------- B: objets RefCounted ----------
class TileState extends RefCounted:
	var owner: int; var color: int; var poi: int; var anchor: int
	func copy() -> TileState:
		var o := TileState.new(); o.owner = owner; o.color = color; o.poi = poi; o.anchor = anchor; return o
class VisState extends RefCounted:
	var data: PackedByteArray
	func copy() -> VisState:
		var o := VisState.new(); o.data = data.duplicate(); return o
class UnitState extends RefCounted:
	const FIELDS := ["id", "type", "fac", "x", "y", "hp", "flags"]
	var id: int; var type: int; var fac: int; var x: int; var y: int; var hp: int; var flags: int
	func copy() -> UnitState:
		var o := UnitState.new(); o.id = id; o.type = type; o.fac = fac; o.x = x; o.y = y; o.hp = hp; o.flags = flags; return o
class NodeState extends RefCounted:
	const FIELDS := ["id", "x", "y", "owner", "level"]
	var id: int; var x: int; var y: int; var owner: int; var level: int
	func copy() -> NodeState:
		var o := NodeState.new(); o.id = id; o.x = x; o.y = y; o.owner = owner; o.level = level; return o
class RuinState extends RefCounted:
	const FIELDS := ["id", "x", "y", "zone", "read", "turn"]
	var id: int; var x: int; var y: int; var zone: int; var read: int; var turn: int
	func copy() -> RuinState:
		var o := RuinState.new(); o.id = id; o.x = x; o.y = y; o.zone = zone; o.read = read; o.turn = turn; return o
class IntentState extends RefCounted:
	const FIELDS := ["id", "author", "target", "atile", "ttile", "type", "motive", "turn", "exec", "status", "reason"]
	var id: int; var author: int; var target: int; var atile: int; var ttile: int; var type: int
	var motive: int; var turn: int; var exec: int; var status: int; var reason: int
	func copy() -> IntentState:
		var o := IntentState.new(); o.id = id; o.author = author; o.target = target; o.atile = atile; o.ttile = ttile
		o.type = type; o.motive = motive; o.turn = turn; o.exec = exec; o.status = status; o.reason = reason; return o

class StateB:
	var hdr: PackedInt32Array
	var tiles: Array[TileState] = []
	var vis: Array[VisState] = []
	var units: Array[UnitState] = []
	var nodes: Array[NodeState] = []
	var ruins: Array[RuinState] = []
	var intents: Array[IntentState] = []
	func list(g: String) -> Array:
		match g:
			"u": return units
			"n": return nodes
			"r": return ruins
		return intents
	static func mk(g: String):
		match g:
			"u": return UnitState.new()
			"n": return NodeState.new()
			"r": return RuinState.new()
		return IntentState.new()
	static func from_canon(c: Dictionary) -> StateB:
		var s := StateB.new()
		s.hdr = PackedInt32Array(c["hdr"])
		for i in 256:
			var t := TileState.new()
			t.owner = c["t_owner"][i]; t.color = c["t_color"][i]; t.poi = c["t_poi"][i]; t.anchor = c["t_anchor"][i]
			s.tiles.append(t)
		for f in 2:
			var v := VisState.new(); v.data = PackedByteArray(c["vis%d" % f]); s.vis.append(v)
		for g in ["u", "n", "r", "i"]:
			var lst := s.list(g)
			for i in c[g + "_id"].size():
				var o = mk(g)
				for f in o.FIELDS: o.set(f, c[g + "_" + f][i])
				lst.append(o)
		return s
	func copy() -> StateB:
		var s := StateB.new()
		s.hdr = hdr.duplicate()
		for t in tiles: s.tiles.append(t.copy())
		for v in vis: s.vis.append(v.copy())
		for u in units: s.units.append(u.copy())
		for n in nodes: s.nodes.append(n.copy())
		for r in ruins: s.ruins.append(r.copy())
		for i in intents: s.intents.append(i.copy())
		return s
	func canon() -> Dictionary:
		var o := {"hdr": Array(hdr)}
		for k in ["owner", "color", "poi", "anchor"]:
			var a := []
			for t in tiles: a.append(t.get(k))
			o["t_" + k] = a
		for f in vis.size(): o["vis%d" % f] = Array(vis[f].data)
		for g in GROUPS:
			for f in GROUPS[g]:
				var a := []
				for e in list(g): a.append(e.get(f))
				o[g + "_" + f] = a
		return o
	# format B serialise: tableaux d'enregistrements (dicts), pas les objets
	func to_data(json: bool) -> Dictionary:
		var d := {"hdr": Array(hdr), "tiles": [], "vis": []}
		for t in tiles: d["tiles"].append({"o": t.owner, "c": t.color, "p": t.poi, "a": t.anchor})
		for v in vis: d["vis"].append(Array(v.data) if json else v.data)
		for g in GROUPS:
			var a := []
			for e in list(g):
				var r := {}
				for f in e.FIELDS: r[f] = e.get(f)
				a.append(r)
			d[GKEY[g]] = a
		return d
	func to_var_data(): return to_data(false)
	func to_json_data(): return to_data(true)
	static func from_data(d: Dictionary) -> StateB:
		var s := StateB.new()
		s.hdr = PackedInt32Array(d["hdr"])
		for t in d["tiles"]:
			var o := TileState.new(); o.owner = t["o"]; o.color = t["c"]; o.poi = t["p"]; o.anchor = t["a"]; s.tiles.append(o)
		for v in d["vis"]:
			var o := VisState.new(); o.data = PackedByteArray(v); s.vis.append(o)
		for g in GROUPS:
			for r in d[GKEY[g]]:
				var o = mk(g)
				for f in o.FIELDS: o.set(f, r[f])
				s.list(g).append(o)
		return s
	func mutate(): units[0].hp += 1

# ---------- C: Dictionary / Array imbriques ----------
class StateC:
	var d := {}
	static func from_canon(c: Dictionary) -> StateC:
		var s := StateC.new()
		var h := {}
		for k in 16: h["h%d" % k] = c["hdr"][k]
		s.d["hdr"] = h
		var tl := []
		for i in 256: tl.append({"o": c["t_owner"][i], "c": c["t_color"][i], "p": c["t_poi"][i], "a": c["t_anchor"][i]})
		s.d["tiles"] = tl
		var vl := []
		for f in 2:
			var seen := []; var disc := []
			for i in 256:
				seen.append(c["vis%d" % f][i * 2]); disc.append(c["vis%d" % f][i * 2 + 1])
			vl.append({"seen": seen, "disc": disc})
		s.d["vis"] = vl
		for g in GROUPS:
			var m := {}
			var n: int = c[g + "_id"].size()
			for j in n:
				# ordre d'insertion melange (37 premier avec 60, 10 et 3 : 37 mod n est inversible)
				var i := (j * 37) % n
				var r := {}
				for f in GROUPS[g]: r[f] = c[g + "_" + f][i]
				m[c[g + "_id"][i]] = r
			s.d[GKEY[g]] = m
		return s
	static func from_data(d: Dictionary) -> StateC:
		var s := StateC.new(); s.d = d; return s
	func copy() -> StateC:
		var s := StateC.new(); s.d = d.duplicate(true); return s
	func copy_deep() -> StateC:
		var s := StateC.new(); s.d = d.duplicate_deep(); return s
	func canon() -> Dictionary:
		var o := {"hdr": []}
		for k in 16: o["hdr"].append(d["hdr"]["h%d" % k])
		for p in [["t_owner", "o"], ["t_color", "c"], ["t_poi", "p"], ["t_anchor", "a"]]:
			var a := []
			for t in d["tiles"]: a.append(t[p[1]])
			o[p[0]] = a
		for f in 2:
			var a := []
			for i in 256:
				a.append(d["vis"][f]["seen"][i]); a.append(d["vis"][f]["disc"][i])
			o["vis%d" % f] = a
		for g in GROUPS:
			var ids: Array = d[GKEY[g]].keys()
			ids.sort()
			for f in GROUPS[g]:
				var a := []
				for id in ids: a.append(d[GKEY[g]][id][f])
				o[g + "_" + f] = a
		return o
	func to_var_data(): return d
	func to_json_data(): return d
	func mutate(): d["units"][d["units"].keys()[0]]["hp"] += 1

# ---------- harnais ----------
func stats(a: PackedInt64Array) -> String:
	var b := a.duplicate(); b.sort()
	var sum := 0
	for v in a: sum += v
	return "med=%d p95=%d min=%d mean=%.1f" % [b[b.size() / 2], b[int(b.size() * 0.95)], b[0], float(sum) / a.size()]

func bench(name: String, fn: Callable) -> void:
	for i in WARM: fn.call()
	var t_copy := PackedInt64Array(); var t_free := PackedInt64Array()
	t_copy.resize(COPIES); t_free.resize(COPIES)
	for i in COPIES:
		var t0 := Time.get_ticks_usec()
		var r = fn.call()
		var t1 := Time.get_ticks_usec()
		r = null
		var t2 := Time.get_ticks_usec()
		t_copy[i] = t1 - t0; t_free[i] = t2 - t0
	print("COPY  %-18s copie: %s | copie+liberation: %s (us, n=%d)" % [name, stats(t_copy), stats(t_free), COPIES])

func timed(n: int, fn: Callable) -> String:
	for i in 20: fn.call()
	var a := PackedInt64Array(); a.resize(n)
	for i in n:
		var t0 := Time.get_ticks_usec(); fn.call(); a[i] = Time.get_ticks_usec() - t0
	return stats(a)

func _init() -> void:
	print("VERSION ", Engine.get_version_info()["string"])
	var c := gen(12345)
	var reps := {"A": StateA, "B": StateB, "C": StateC}
	var objs := {}
	for k in reps: objs[k] = reps[k].from_canon(c)
	for k in reps: print("CHECK ", k, " canon == generateur: ", eq(objs[k].canon(), c))
	for k in reps:
		var o = objs[k]
		var cp = o.copy()
		var same: bool = eq(cp.canon(), c)
		cp.mutate()
		print("CHECK ", k, " copie egale: ", same, " ; original intact apres mutation de la copie: ", eq(o.canon(), c), " ; copie modifiee: ", not eq(cp.canon(), c))
	var shallow := StateC.new()
	shallow.d = objs["C"].d.duplicate()
	shallow.mutate()
	print("CHECK C duplicate() non profond partage les imbriques -> original modifie: ", not eq(objs["C"].canon(), c))
	objs["C"] = StateC.from_canon(c)
	var cd = objs["C"].copy_deep()
	cd.mutate()
	print("CHECK C duplicate_deep: original intact: ", eq(objs["C"].canon(), c), " ; copie modifiee: ", not eq(cd.canon(), c))
	bench("A packed", objs["A"].copy)
	bench("B objets", objs["B"].copy)
	bench("C dup(true)", objs["C"].copy)
	bench("C duplicate_deep", objs["C"].copy_deep)
	print("PACKED JSON.stringify(PackedInt32Array): ", JSON.stringify(PackedInt32Array([1, 2])))
	print("var_to_bytes(objet RefCounted, sans objets) taille=", var_to_bytes(objs["B"].units[0]).size())
	for k in reps:
		var o = objs[k]
		var vb: PackedByteArray = var_to_bytes(o.to_var_data())
		var js: String = JSON.stringify(o.to_json_data())
		print("SIZE  ", k, " var_to_bytes=", vb.size(), " B ; JSON=", js.to_utf8_buffer().size(), " B ; brut formule 5=", 64 + 256 * 4 + 256 * 2 * 2 + 60 * 16 + 10 * 8 + 3 * 8 + 60 * 16 + 2 * 64)
		var r_vb = reps[k].from_data(bytes_to_var(vb))
		var r_js = reps[k].from_data(norm(JSON.parse_string(js)))
		print("ROUND ", k, " egalite profonde var=", eq(r_vb.canon(), c), " json=", eq(r_js.canon(), c))
		var cls = reps[k]
		print("TIME  ", k, " ser var: ", timed(500, func(): var_to_bytes(o.to_var_data())))
		print("TIME  ", k, " deser var: ", timed(500, func(): cls.from_data(bytes_to_var(vb))))
		print("TIME  ", k, " ser json: ", timed(500, func(): JSON.stringify(o.to_json_data())))
		print("TIME  ", k, " deser json (parse+norm+from_data): ", timed(500, func(): cls.from_data(norm(JSON.parse_string(js)))))
		print("TIME  ", k, " aller-retour var: ", timed(500, func(): cls.from_data(bytes_to_var(var_to_bytes(o.to_var_data())))))
		print("TIME  ", k, " aller-retour json: ", timed(500, func(): cls.from_data(norm(JSON.parse_string(JSON.stringify(o.to_json_data()))))))
	var ids := [5, 3, 9, 1, 100, 2, 0, 7, 64, 31]
	var dd := {}
	for i in ids: dd[i] = true
	print("ORDER inseres=", ids, " observe=", dd.keys())
	var ds := {}
	for s in ["zeta", "alpha", "mid", "b"]: ds[s] = 1
	print("ORDER chaines observe=", ds.keys())
	dd.erase(3)
	dd[3] = true
	print("ORDER apres erase+reinsert de 3: ", dd.keys())
	print("ORDER unites C (insertion melangee) 12 premiers: ", objs["C"].d["units"].keys().slice(0, 12))
	var mx := 9223372036854775807
	print("INT64 max+1 = ", mx + 1, " ; max*2 = ", mx * 2, " ; 0xFFFFFFFF*0xFFFFFFFF = ", 0xFFFFFFFF * 0xFFFFFFFF, " ; masque 32 = ", (0xFFFFFFFF * 0xFFFFFFFF) & M)
	for sd in [0, 1, 1234, 987654321, 4294967295]:
		var hs := []
		var ds6 := []
		for n in 5:
			hs.append(hash32(sd, n))
			ds6.append(draw(sd, n, 6))
		print("DRAW seed=", sd, " hash32(c=0..4)=", hs, " draw(6)=", ds6)
	var f := FileAccess.open("user://bench_tmp.bin", FileAccess.WRITE)
	var ok1 = f.store_buffer(var_to_bytes(objs["A"].to_var_data()))
	var ok2 = f.store_32(7)
	print("FILE store_buffer -> ", typeof(ok1) == TYPE_BOOL, " ", ok1, " ; store_32 -> ", typeof(ok2) == TYPE_BOOL, " ", ok2)
	f.close()
	quit()
