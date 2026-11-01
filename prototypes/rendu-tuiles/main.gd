# PROTOTYPE - NOT FOR PRODUCTION
# Question: 144-256 tiles in ONE MultiMeshInstance2D (custom data), ring wave computed in shader?
# Date: 2026-10-30
extends Node2D

const T_ANNEAU := 0.2
const T_FONDU := 0.4
const T_REV := 0.15
const K_MAX := 3
const TILE := 40.0
const STEP := 42.0
const ORIGIN := Vector2(40, 40)
const HEX := ["4E5862", "1FA38F", "C49BEA", "1E2329", "5F6266", "3A8EE6", "F0DC6E", "1E2329"]

var n := 12
var radius := 3
var cb := false
var reduced := false
var owner_a := PackedInt32Array()   # proprietaire reel (0 neutre, 1 propre, 2 ennemi)
var mem := PackedInt32Array()       # derniere vue
var fog := PackedInt32Array()       # 0 INCONNUE, 1 EXPLOREE, 2 VISIBLE
var cd: Array = []                  # Vector4 par tuile: shown, prev, fog(+4 rev), start
var mmi: MultiMeshInstance2D
var mm: MultiMesh
var mat: ShaderMaterial
var label: Label
var samples: Array = []
var shown_t := 0.0
var bench := false
var bench_waves := false
var bench_last := 0.0
var bench_i := 0
var results: Array = []
var captures_done := 0

func _ready() -> void:
	RenderingServer.global_shader_parameter_add("g_time", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	var sh := load("res://tile.gdshader") as Shader
	mat = ShaderMaterial.new()
	mat.shader = sh
	var pal := PackedVector3Array()
	for h in HEX:
		var c := Color(h)
		pal.append(Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("pal", pal)
	mmi = MultiMeshInstance2D.new()
	mmi.material = mat
	add_child(mmi)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(740, 10)
	layer.add_child(label)
	build(12)
	if "--bench" in OS.get_cmdline_user_args():
		bench = true
		run_bench()

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func build(size: int) -> void:
	n = size
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(TILE, TILE)
	mm.mesh = q
	mm.instance_count = n * n
	mmi.multimesh = mm
	owner_a.resize(n * n); mem.resize(n * n); fog.resize(n * n)
	cd.clear()
	for i in n * n:
		var x := i % n
		var y := i / n
		mm.set_instance_transform_2d(i, Transform2D(0, ORIGIN + Vector2(x, y) * STEP + Vector2(TILE, TILE) / 2))
		fog[i] = 0 if x < n / 4 else (1 if x < n / 2 - 1 else 2)
		owner_a[i] = 0
		if absi(x - n * 2 / 3) <= 1 and absi(y - n / 2) <= 1: owner_a[i] = 1
		if absi(x - n * 3 / 4) <= 1 and absi(y - n / 4) <= 1: owner_a[i] = 2
		mem[i] = owner_a[i] if fog[i] == 2 else 0
		if i == 0: pass
		cd.append(Vector4(disp(i), disp(i), fog[i], -100.0))
		mm.set_instance_custom_data(i, Color(cd[i].x, cd[i].y, cd[i].z, cd[i].w))

func disp(i: int) -> int:
	return 0 if fog[i] == 0 else (mem[i] if fog[i] == 1 else owner_a[i])

# miroir GDScript du shader (rule 15: reecriture sans saut), retourne (teinte, s)
func eval(i: int, t: float) -> Vector2:
	var v: Vector4 = cd[i]
	var rev: bool = v.z > 3.5
	var D := T_REV if rev else T_FONDU
	var u := clampf((t - v.w) / D, 0.0, 1.0)
	var sh := int(v.x); var pv := int(v.y)
	if pv == sh: return Vector2(sh, 0.0 if sh == 0 else 1.0)
	if pv == 0: return Vector2(sh, u)
	if sh == 0: return Vector2(pv, 1.0 - u)
	if u < 0.5: return Vector2(pv, 1.0 - 2.0 * u)
	return Vector2(sh, 2.0 * u - 1.0)

func write_tile(i: int, target: int, delay: float, rev: bool) -> void:
	var t := now()
	var cur := eval(i, t)
	var h := int(cur.x); var sc := cur.y
	var D := T_REV if rev else T_FONDU
	var prev := 0
	var u0 := 0.0
	if sc <= 0.001 or target == 0 and h == 0:
		prev = 0; u0 = 0.0
		if target == 0: prev = 0
	elif target == 0:
		prev = h; u0 = 1.0 - sc
	elif target == h:
		prev = 0; u0 = sc
	else:
		prev = h; u0 = (1.0 - sc) / 2.0
	var start := t + delay - u0 * D
	if reduced: start = t - 10.0
	var f := float(fog[i]) + (4.0 if rev else 0.0)
	cd[i] = Vector4(target, prev, f, start)
	mm.set_instance_custom_data(i, Color(target, prev, f, start))

func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func capture(src: Vector2i, owner_id: int, r: int) -> void:
	var changed: Array = []
	var zone: Array = []
	for y in range(maxi(0, src.y - r), mini(n, src.y + r + 1)):
		for x in range(maxi(0, src.x - r), mini(n, src.x + r + 1)):
			zone.append(y * n + x)
	for i in zone:
		var before := disp(i)
		owner_a[i] = owner_id
		if fog[i] == 2: mem[i] = owner_id
		if disp(i) != before: changed.append(i)
	if changed.is_empty(): return
	# F7 source effective
	var s := src
	if fog[src.y * n + src.x] != 2:
		var best := -1
		var bk := 999
		for i in changed:
			if fog[i] != 2: continue
			var k := cheb(src, Vector2i(i % n, i / n))
			if k < bk: bk = k; best = i
		if best < 0:
			for i in changed: write_tile(i, disp(i), 0.0, false)  # affichage direct
			return
		s = Vector2i(best % n, best / n)
	var t_ring := minf(T_ANNEAU, (1.0 - T_FONDU) / K_MAX)
	for i in changed:
		var k := cheb(s, Vector2i(i % n, i / n))
		write_tile(i, disp(i), minf(k, K_MAX) * t_ring, false)
	captures_done += 1

func set_fog(src: Vector2i, r: int) -> void:
	var st := (fog[src.y * n + src.x] + 1) % 3
	for y in range(maxi(0, src.y - r), mini(n, src.y + r + 1)):
		for x in range(maxi(0, src.x - r), mini(n, src.x + r + 1)):
			var i := y * n + x
			var before := disp(i)
			fog[i] = st
			if st == 2: mem[i] = owner_a[i]
			var after := disp(i)
			if after != before: write_tile(i, after, 0.0, true)
			else:
				var v: Vector4 = cd[i]
				cd[i] = Vector4(v.x, v.y, st, v.w)
				mm.set_instance_custom_data(i, Color(v.x, v.y, st, v.w))

func mouse_tile() -> Vector2i:
	var p := (get_local_mouse_position() - ORIGIN) / STEP
	return Vector2i(clampi(int(floor(p.x)), 0, n - 1), clampi(int(floor(p.y)), 0, n - 1))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT: capture(mouse_tile(), 1, radius)
		elif e.button_index == MOUSE_BUTTON_RIGHT: capture(mouse_tile(), 2, radius)
	elif e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_1: radius = 1
			KEY_2: radius = 2
			KEY_3: radius = 3
			KEY_C: set_cb(not cb)
			KEY_R: reduced = not reduced
			KEY_F: set_fog(mouse_tile(), radius)
			KEY_G: build(16 if n == 12 else 12)

func set_cb(v: bool) -> void:
	cb = v
	mat.set_shader_parameter("mode", 1 if cb else 0)  # aucune ecriture d'etat

func _process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set("g_time", now())
	samples.append(delta * 1000.0)
	if samples.size() > 120: samples.pop_front()
	if bench_waves and now() - bench_last > 0.6:
		bench_last = now()
		bench_i += 1
		capture(Vector2i((bench_i * 5) % n, (bench_i * 7) % n), 1 + bench_i % 2, 3)
	if now() - shown_t > 0.25:
		shown_t = now()
		var avg := 0.0
		for s in samples: avg += s
		avg /= maxf(1, samples.size())
		label.text = "FPS %d | %.2f ms/frame (moy. 120)\n%dx%d  rayon %d  daltonien %s  reduit %s\nClic G=propre, clic D=ennemi, 1/2/3 rayon,\nC daltonien, R reduit, F brouillard zone, G 12/16" % [Engine.get_frames_per_second(), avg, n, n, radius, cb, reduced]

func phase(name: String, secs: float) -> void:
	samples.clear()
	var all: Array = []
	var t0 := now()
	while now() - t0 < secs:
		await get_tree().process_frame
		all.append(get_process_delta_time() * 1000.0)
	var avg := 0.0; var mx := 0.0
	for s in all: avg += s; mx = maxf(mx, s)
	avg /= all.size()
	var line := "%s: frames=%d avg=%.3f ms max=%.3f ms (%.0f fps)" % [name, all.size(), avg, mx, 1000.0 / avg]
	print(line)
	results.append(line)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screens")
	DirAccess.make_dir_recursive_absolute(dir)
	var err := get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")
	print("shot ", name, " err=", err)

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func run_bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	results.append("renderer=%s method=%s adapter=%s" % [RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	print(results[0])
	await wait(1.0)
	await shot("01_12x12_initial")
	await phase("12x12 idle", 3.0)
	capture(Vector2i(7, 6), 1, 3)
	await wait(0.45)
	await shot("02_onde_r3_milieu")
	await wait(1.2)
	await shot("03_onde_r3_fin")
	capture(Vector2i(7, 6), 2, 2)
	await wait(0.3)
	await shot("04_f_vers_g_milieu")
	await wait(1.0)
	set_cb(true)
	await shot("05_daltonien")
	set_cb(false)
	reduced = true
	capture(Vector2i(8, 3), 1, 3)
	await shot("06_reduit_immediat")
	reduced = false
	set_fog(Vector2i(1, 1), 2)
	await wait(0.05)
	await shot("07_brouillard_revelation_milieu")
	await wait(0.5)
	bench_waves = true
	await phase("12x12 ondes en continu (1 capture r3 / 0.6 s)", 5.0)
	bench_waves = false
	await wait(1.5)
	build(16)
	await wait(0.5)
	await phase("16x16 idle", 3.0)
	capture(Vector2i(10, 8), 1, 3)
	await wait(0.45)
	await shot("08_16x16_onde_milieu")
	bench_waves = true
	await phase("16x16 ondes en continu", 5.0)
	bench_waves = false
	var f := FileAccess.open(ProjectSettings.globalize_path("res://bench_results.txt"), FileAccess.WRITE)
	for l in results: f.store_line(l)
	f.close()
	get_tree().quit()
