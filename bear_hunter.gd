extends Node3D
const DesertLanguage = preload("res://desert_language.gd")
var ui_english := false
var english_pack: Translation
var turkish_pack: Translation
## ÇÖL SÜRÜŞÜ - Godot 4.2+ (3D), tek script, hiçbir asset gerekmez.
## Kurulum: Yeni sahne > kök düğüm olarak Node3D > bu scripti ekle > kaydet > F5.
## (En iyi görüntü için proje ayarlarında renderer "Forward+" olsun, varsayılan zaten odur.)
##
## Kontroller:
##   W / Yukarı        : gaz
##   S / Aşağı         : fren / geri vites
##   A D / Sol Sağ     : direksiyon
##   Boşluk            : el freni (drift!)
##   Shift             : nitro
##   R                 : yola geri dön (araba sıkışırsa)
##   C                 : araba rengini değiştir
##
## Özellikler: sonsuz prosedürel çöl (kum tepeleri, mesalar, kaktüsler, kayalar), kıvrılan asfalt yol,
## eğime göre sürüş, tepelerden havalanma, drift izleri, toz, gündüz-gece döngüsü, farlar, altın toplama.
## Kamera sabit açılı ve arabayı takip eder (tam tepeden değil, çapraz).

const CHUNK := 64.0
const CHUNK_N := 24
const LOAD_R := 1
var mobile_low_detail := OS.has_feature("mobile")
const ROAD_HALF := 4.2
@export_range(30.0, 75.0, 1.0) var camera_angle := 53.0
const CAMERA_DISTANCE := 18.0
const GRAVITY := 32.0


class ChunkData:
	var ramp := Vector4.ZERO
	var node: Node3D
	var obstacles: Array = []  # Vector3(x, z, yarıçap)
	var coins: Array = []      # Node3D


# ---------------------------------------------------------------- Durum

var noise_big := FastNoiseLite.new()
var noise_mid := FastNoiseLite.new()
var noise_fine := FastNoiseLite.new()

var chunks := {}  # Vector2i -> ChunkData

# araba
var car: Node3D
var car_body: Node3D
var wheel_spins: Array = []
var wheel_pivots: Array = []
var vinish_car_active := false
const VEHICLE_FILES := ["FrontEngineTrack", "MuscleCoupe", "WedgeSupercar", "BoxyOffRoader", "Enduro", "GrabATV", "GrabBuggy", "Rally", "GTSupercar", "V8Supercar", "Hypercar", "V12", "Retro", "ClassicFormula", "TevySnowmobile", "LuxurySUV", "DesertRaptor", "MonsterTruck", "microcar", "vintage-truck", "grand-tourer", "rear-engine-sports-coupe", "hot-hatchback", "vintage-roadster", "touring-car", "vintage-coupe"]
const VEHICLE_NAMES := ["Pist", "Drift", "Spor", "4×4", "Enduro", "ATV", "Buggy", "Ralli", "Süper GT", "Süper V8", "Hypercar", "V12 GT", "Retro", "Klasik F1", "Kar Motoru", "SUV 4×4", "Çöl Raptoru", "Dağ Canavarı 4×4", "Klasik Mini", "Klasik Pikap", "Klasik GT", "Drift Coupé", "Drift Hatch", "1928 Roadster", "1920 Touring", "1932 Coupé"]
const PAINT_OVERRIDES := {"Paint_Acid": Color("#c22438"), "Paint_Silver": Color("#346bd0"),
	"Paint_Graphite": Color("#813dc1"), "Paint_Race_White": Color("#df5231"), "Paint_Sand": Color("#cf862c")}
const STARTER_INDEX := 18
var vehicle_index := STARTER_INDEX
var preview_vehicle_index := STARTER_INDEX
var vehicle_model: Node3D
var pedal_art: Texture2D
var wheel_art: Texture2D
var shop_stage: Node3D
var shop_model: Node3D
var garage_page: Control
var garage_maps: Control
var garage_backdrop: TextureRect
var garage_car_name: Label
var garage_speed: Label
var garage_pick: Button
var garage_meter: ProgressBar
var garage_strip: HBoxContainer
var garage_nav: Array[Button]
var garage_map_buttons: Array[Button] = []
var garage_map_atlas: Texture2D
var garage_map_preview: Control
var garage_night: CheckButton
var garage_car_images := {}
var race_heading_font: Font
var race_body_font: Font
var race_skins := {}
var shop_view: SubViewport
var main_menu: Control
var map_index := 0
var ramp_entry_key := Vector2i.ZERO
var ramp_entry_active := false
var desert_night := false
var soft_props: Array[Node3D] = []
var forest_bark: StandardMaterial3D
var forest_needles: StandardMaterial3D
const MAP_NAMES := ["Çöl", "Karlı Geçit", "Çamur Parkuru", "Orman", "Şehir", "Oval Yarış", "Uzun GP", "Drift Pisti"]
const TRACK_AXES := [Vector2(99, 65), Vector2(128, 80), Vector2(110, 69)]
const RACE_LIMIT := 10.6
var race_models: Array[Node3D] = []
const KIT_START := 8
const KIT_CHECKPOINT := 9
const KIT_STAND := 10
const KIT_PIT := 11
var race_checkpoint := 0
const LINE_ANGLE := 0.0
const RACE_LAPS := 3
var race_finish_rank := 0
var race_catalog := false
const PARKING_NAMES := ["İlk park", "Sağdan giriş", "Soldan giriş", "Duba geçidi", "Kavisli giriş", "Çifte koridor", "Dar cep", "Açılı park", "Tümsek geçidi", "Rampa geçidi", "Yumuşak S", "İki sıra", "Sağ şerit", "Sol şerit", "Orta cep", "Kıvrımlı yol", "Kısa manevra", "Dar tümsek", "Çift viraj", "Uzun koridor", "Çapraz geçiş", "İç cep", "Son viraj", "Ustalık parkı"]
const PARK_LEVELS := 50
const DRIFT_LEVEL := PARK_LEVELS
const DISTANCE_LEVEL := PARK_LEVELS + 1
const RETIRED_CARS := [16, 19]
const REMOVED_MAP := 4
var challenge_page: Control
var challenge_buttons: Array[Button] = []
var challenge_description: Label
var challenge_start: Button
var challenge_selected := 0
var challenge_active := -1
var challenge_completed := {}
var challenge_world: Node3D
var challenge_target := Vector3.ZERO
var challenge_angle := 0.0
var challenge_half := Vector2.ZERO
var challenge_cars: Array[Transform3D] = []
var parked_footprints: Array[PackedVector2Array] = []
var player_parking_hull := PackedVector2Array()
var parking_hull_cache := {}
var challenge_meters := 0.0
var challenge_points := 0.0
var challenge_hold := 0.0
var challenge_won := false
const PARKING_LIMITS := [45, 50, 55, 60, 65, 70, 65, 70, 75, 90, 65, 65, 70, 70, 70, 75, 75, 80, 80, 80, 85, 85, 90, 95]
var challenge_time := 0.0
var challenge_failed := false
var challenge_restart_after := 0.0
var challenge_cones: Array[Vector3] = []
var parking_gates: Array[Vector3] = []
var parking_gate_index := 0
var parking_ground_cache := {}
var parking_contact_shadow: MeshInstance3D
var parking_yard_assets := {}
var parking_yard_colliders: Array[PackedVector2Array] = []
var stream_delay := 0.0
const CIRCUIT_PACE := 0.90
var challenge_bump_z := 100.0
var challenge_air_speed := 0.0
var challenge_jumped := false
var challenge_lane_x := 0.0
var parking_cone_model: Node3D
var parking_canopy: Node3D
var parking_bay_mesh: ArrayMesh
var parking_floor_material: ShaderMaterial
var parking_goal_material: StandardMaterial3D
var parking_goal_label: Label3D
var challenge_retry: Button
var challenge_forward: Button
var race_rivals: Array[Node3D] = []
var rival_progress := PackedFloat32Array()
var rival_speed := PackedFloat32Array()
var rival_wheels: Array[Array] = []
var rival_lane_push := PackedFloat32Array()
var goal_check_delay := 0.0
var race_laps := 0
var race_time := 0.0
var race_best := 0.0
var race_countdown := 0.0
const TOP_SPEEDS := [76, 67, 82, 43, 42, 29, 38, 59, 85, 89, 104, 91, 35, 69, 38, 56, 23, 32, 22, 25, 47, 76, 64, 28, 24, 34]
const ROAD_ACCEL := [26, 19, 27, 12, 16, 13, 16, 22, 29, 29, 34, 27, 11, 23, 15, 16, 12, 10, 9, 8, 13, 21, 15, 9, 8, 10]
const RACE_PAYOUT := [420, 300, 220, 160]
const CAR_PRICES := [500, 700, 1000, 1500, 2200, 3000, 4000, 5000, 6000, 6500, 7000, 7500, 8000, 8500, 9000, 10000, 11000, 12000, 13000, 14000, 15000, 16500, 18000]
var session_start_gold := -1
var session_summary := ""
var main_session_label: Label
var rival_cars: Array[int] = []
var last_rival_draw: Array[int] = []
var race_reward := 0
var coin_badge: Label
var vehicle_shop: ColorRect
var wheel_touch_start := 0.0
var flames: Array = []
var spots: Array = []
var dust: CPUParticles3D
var spray_cloud_mesh: Mesh
var desert_plumes: Array[CPUParticles3D] = []
var sand_burst: CPUParticles3D
var sand_burst_cooldown := 0.0
var smoke: CPUParticles3D
var snow_fall: CPUParticles3D
var snow_branch: StandardMaterial3D

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var vy := 0.0
var yaw := PI
var steer := 0.0
var car_n := Vector3.UP
var grounded := true
var air_time := 0.0
var last_ground := 0.0
var wheel_angle := 0.0
var pitch_vis := 0.0
var roll_vis := 0.0
var last_vf := 0.0
var cur_vf := 0.0
var cur_vr := 0.0
var accel_f := 0.0
var boosting := false
var impact_t := 0.0
var shake := 0.0
var paint_idx := 0

# oyun
var nitro := 50.0
const GARAGE_SAVE := "user://desert_garage.cfg"
var coins_n := 0
var owned_cars: Array = [STARTER_INDEX]
var garage_order: Array[int] = []
var map_meters := {}
var map_drift := {}
var map_coins := {}
var accomplishments := {}
var achievement_page: Control
var achievement_list: VBoxContainer
var achievement_destination := 0
var achievement_buttons: Array[Button] = []
var race_lap_records := {}
var race_win_records := {}
var garage_goals: Label
var garage_balance: Label
var save_queued := false
var race_ramp_mesh: ArrayMesh
var collected_coins := {}
var distance := 0.0
var drift_score := 0.0
var drift_combo := 1
var drift_steps := 0
var drift_display_points := 0
var drift_pop_time := 0.0
var drift_chain_time := 0.0
var drift_grace := 0.0
var landing_score := 0
var msg_text := ""
var msg_t := 0.0

# izler
var skid_pool: Array = []
var skid_idx := 0
var skid_last := Vector3(1e6, 0, 1e6)

# sahne
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial

# ui
var speed_label: Label
var info_label: Label
var msg_label: Label
var drift_points_label: Label
var drift_multiplier_label: Label
var drive_controls: Control
var wheel_finger := -1
var wheel_input := 0.0
var wheel_display := 0.0
var gas_display := 0.0
var brake_display := 0.0
var gas_finger := -1
var brake_finger := -1
var nitro_bar: ProgressBar

# kaynaklar
var terrain_mat: ShaderMaterial
var mat_rock: StandardMaterial3D
var mat_cactus: StandardMaterial3D
var mat_post: StandardMaterial3D
var mat_reflect: StandardMaterial3D
var mat_coin: StandardMaterial3D
var mat_paint: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_black: StandardMaterial3D
var mat_chrome: StandardMaterial3D
var mat_tire: StandardMaterial3D
var mat_rim: StandardMaterial3D
var mat_spoke: StandardMaterial3D
var mat_mark: StandardMaterial3D
var mat_stripe: StandardMaterial3D
var lens_mat: StandardMaterial3D
var tail_mat: StandardMaterial3D
var flame_mat: StandardMaterial3D

var m_cactus_trunk: CylinderMesh
var m_cactus_arm_h: CylinderMesh
var m_cactus_arm_v: CylinderMesh
var m_cap_big: SphereMesh
var m_cap_small: SphereMesh
var m_rock: SphereMesh
var m_post: BoxMesh
var m_reflect: BoxMesh
var m_coin: CylinderMesh
var m_tire: CylinderMesh
var m_rim: CylinderMesh
var m_spoke: BoxMesh
var m_mark: BoxMesh
var obstacle_art: Texture2D
var cactus_model: Node3D
var tevy_cacti: Array[Node3D] = []
var boulder_model: Node3D
var nama_boulder: Node3D
var nama_trunk: Node3D
var forest_cover: Array[Node3D] = []



var paint_colors: Array = [
	Color("a91722"), Color("1f5fbf"), Color("f2b01e"),
	Color("e8e8ea"), Color("2a8f4a"), Color("222226"),
]


# ================================================================ Yol ve arazi fonksiyonları
# (Aynı yol formülü aşağıdaki terrain shader'ında da var; değiştirirsen ikisini birlikte değiştir.)

func road_x(z: float) -> float:
	return 40.0 * sin(z * 0.010) + 25.0 * sin(z * 0.0037 + 1.3)


func road_slope(z: float) -> float:
	return 0.4 * cos(z * 0.010) + 0.0925 * cos(z * 0.0037 + 1.3)


func road_h(z: float) -> float:
	return 1.0 + 0.65 * sin(z * 0.006) + 0.40 * sin(z * 0.019 + 0.5)


func road_dist(x: float, z: float) -> float:
	if map_index >= 5:
		var axes: Vector2 = TRACK_AXES[map_index - 5]
		var normalized := Vector2(x / axes.x, z / axes.y)
		return absf(normalized.length() - _track_radius(normalized.angle())) * axes.y
	if map_index == 4:
		return minf(absf(fposmod(x + 16.0, 32.0) - 16.0), absf(fposmod(z + 16.0, 32.0) - 16.0))
	var s := road_slope(z)
	return absf(x - road_x(z)) / sqrt(1.0 + s * s)


func dune_h(x: float, z: float) -> float:
	var nb := noise_big.get_noise_2d(x, z)
	if map_index == 0:
		var crest := pow(0.5 + 0.5 * sin(x * 0.065 + z * 0.043 + nb * 2.8), 2.5)
		return nb * 1.2 + crest * 1.8 + 0.8
	return nb * 1.5 + noise_mid.get_noise_2d(x, z) * 0.45 + 1.5


func terrain_h(x: float, z: float) -> float:
	if map_index >= 4:
		return 0.0
	var d := road_dist(x, z)
	var w := smoothstep(ROAD_HALF + 1.5, 34.0, d)
	return lerpf(road_h(z), dune_h(x, z), w)


func _ramp_for_chunk(key: Vector2i) -> Vector4:
	var seed := posmod(key.x * 313 + key.y * 173, 997)
	var direction := Vector2(0, -1).rotated(-_ramp_heading(key))
	for attempt in range(7):
		var ramp := Vector4(key.x * CHUNK + 12.0 + float((seed + attempt * 13) % 40),
			key.y * CHUNK + 12.0 + float((seed + attempt * 17) % 39),
			[7.0, 12.0, 16.0][seed % 3], [1.45, 3.5, 8.0][seed % 3])
		var clear := true
		for step in range(ceili(ramp.z) + 1):
			var at := _ramp_point(ramp, direction, float(step))
			if road_dist(at.x, at.y) < ROAD_HALF + 3.2:
				clear = false
				break
		if clear:
			return ramp
	return Vector4.ZERO


func _race_ramp_angle(key: Vector2i) -> float:
	for angle: float in ([0.45, 5.40] if map_index == 6 else [1.25, 4.30]):
		var point := _track_point(angle, 7.6)
		var local := Vector2(fposmod(point.x, CHUNK), fposmod(point.z, CHUNK))
		if Vector2i(floori(point.x / CHUNK), floori(point.z / CHUNK)) == key and minf(minf(local.x, local.y), minf(CHUNK - local.x, CHUNK - local.y)) > 5.0:
			return angle
	return -1.0


func _ramp_heading(key: Vector2i) -> float:
	if map_index >= 5:
		var tangent := _race_track_tangent(_race_ramp_angle(key), 7.6)
		return atan2(tangent.x, tangent.z)
	return float(posmod(key.x + key.y * 3, 4)) * PI * 0.5


func _ramp_point(ramp: Vector4, direction: Vector2, run: float) -> Vector2:
	return Vector2(ramp.x, ramp.y) + direction * (run - ramp.z * 0.5)


func _ramp_top(ramp: Vector4, direction: Vector2, run: float) -> float:
	var point := _ramp_point(ramp, direction, run)
	var high := terrain_h(point.x, point.y)
	if map_index >= 5:
		return 0.135 + ramp.w * run / ramp.z
	for side: float in [-2.35, -1.18, 1.18, 2.35]:
		var edge := point + direction.orthogonal() * side
		high = maxf(high, terrain_h(edge.x, edge.y))
	return high + 0.16 + ramp.w * pow(run / ramp.z, 1.7)


func _drive_surface(x: float, z: float) -> float:
	var ground := terrain_h(x, z)
	var key := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
	if not ramp_entry_active or key != ramp_entry_key or not chunks.has(key):
		return ground
	var ramp: Vector4 = chunks[key].ramp
	if ramp.z <= 0.0:
		return ground
	var direction := Vector2(0, -1).rotated(-_ramp_heading(key))
	var offset := Vector2(x - ramp.x, z - ramp.y)
	var run := offset.dot(direction) + ramp.z * 0.5
	if run >= 0.0 and run <= ramp.z and absf(offset.cross(direction)) <= 2.35:
		return maxf(ground, _ramp_top(ramp, direction, run))
	return ground


func _check_ramp_entry(previous: Vector3) -> void:
	var key := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	if not chunks.has(key):
		ramp_entry_active = false
		return
	var ramp: Vector4 = chunks[key].ramp
	if ramp.z <= 0.0:
		ramp_entry_active = false
		return
	var direction := Vector2(0, -1).rotated(-_ramp_heading(key))
	var center := Vector2(ramp.x, ramp.y)
	var offset := Vector2(pos.x, pos.z) - center
	var run := offset.dot(direction) + ramp.z * 0.5
	var lateral := absf(offset.cross(direction))
	var on_deck := run >= 0.0 and run <= ramp.z and lateral <= 2.35
	if ramp_entry_active and key == ramp_entry_key and on_deck:
		return
	if ramp_entry_active:
		ramp_entry_active = false
		# Let a car leaving the deck clear the rear and side walls.
		return
	if run < 0.0 or run > ramp.z + 1.15 or lateral > 3.35:
		return
	var before := Vector2(previous.x, previous.z) - center
	var previous_run := before.dot(direction) + ramp.z * 0.5
	if on_deck and previous_run <= 0.0 and run > previous_run and lateral <= 1.60:
		ramp_entry_key = key
		ramp_entry_active = true
	elif pos.y < _ramp_top(ramp, direction, minf(run, ramp.z)) + 0.1:
		var side_axis := direction.orthogonal()
		var wall_axis := side_axis * (1.0 if offset.dot(side_axis) >= 0.0 else -1.0)
		var separation := 3.35 - lateral
		if ramp.z + 1.15 - run < separation:
			wall_axis = direction
			separation = ramp.z + 1.15 - run
		pos.x += wall_axis.x * (separation + 0.04)
		pos.z += wall_axis.y * (separation + 0.04)
		var motion := Vector2(vel.x, vel.z)
		motion -= wall_axis * minf(0.0, motion.dot(wall_axis))
		vel.x = motion.x
		vel.z = motion.y


# ================================================================ Kurulum

func _ready() -> void:
	randomize()
	_load_garage_progress()
	_install_language()
	for i in range(VEHICLE_NAMES.size()):
		if i not in RETIRED_CARS:
			garage_order.append(i)
	garage_order.sort_custom(func(a: int, b: int) -> bool: return TOP_SPEEDS[a] < TOP_SPEEDS[b] or (TOP_SPEEDS[a] == TOP_SPEEDS[b] and a < b))
	_setup_noise()
	_make_resources()
	_build_environment()
	_build_car()
	_build_skid_pool()
	_build_ui()
	_respawn(0.0, -1.0)
	_select_map(0)
	if get_tree().root.has_meta("driftlane_startup_resources"):
		get_tree().root.remove_meta("driftlane_startup_resources")
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	cam.position = pos + _camera_offset()
	cam.look_at(pos + Vector3.UP * 0.7)
	_say(tr("Gaza bas! Altınları topla, tepelerden uç, drift yap."))


func _setup_noise() -> void:
	noise_big.seed = 1337
	noise_big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_big.frequency = 0.0065
	noise_big.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_big.fractal_octaves = 3

	noise_mid.seed = 42
	noise_mid.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_mid.frequency = 0.022

	noise_fine.seed = 7
	noise_fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_fine.frequency = 0.09


func _std(color: Color, metallic := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	return m


func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _cyl(top: float, bottom: float, h: float, seg := 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	return m


func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


func _sphere(r: float, seg := 16, rings := 8) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return m


func _inst(parent: Node3D, mesh: Mesh, mat: Material, p := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _make_resources() -> void:
	_prepare_parking_art()
	parking_cone_model = _load_3d_asset("res://traffic-cone.glb")
	if parking_cone_model != null:
		add_child(parking_cone_model)
		parking_cone_model.hide()
	var ramp_asset := _load_3d_asset("res://race-track-jump-ramp.glb")
	if ramp_asset != null:
		for child in ramp_asset.find_children("*", "MeshInstance3D", true, false):
			var source := (child as MeshInstance3D).mesh
			for index in range(source.get_surface_count()):
				var material := source.surface_get_material(index)
				if material != null and material.resource_name == "Ramp":
					race_ramp_mesh = ArrayMesh.new()
					race_ramp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(index))
					race_ramp_mesh.surface_set_material(0, material)
		ramp_asset.free()


	for path in ["barrierRed", "barrierWhite", "flagCheckers", "roadStraight", "tyre-barrier", "start-lights", "fenceStraight", "grandStandCovered", "race-track-start-finish", "race-checkpoint-arch", "race-grandstand", "race-pit-garage"]:
		var piece := _load_3d_asset("res://%s.glb" % path)
		race_models.append(piece)
		if piece != null:
			add_child(piece)
			piece.hide()
	snow_branch = _std(Color("#edf3f8"), 0.0, 0.96)
	forest_bark = _std(Color("#554035"))
	forest_needles = _std(Color("#345b39"))
	cactus_model = _load_3d_asset("res://Saguaro.glb")
	for path in ["res://TevyBarrel.glb", "res://TevyYoung.glb"]:
		var plant := _load_3d_asset(path)
		if plant != null:
			for part in plant.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := part as MeshInstance3D
				mesh_instance.material_override = _std(Color("#677b45"), 0.0, 0.93)
			add_child(plant)
			plant.hide()
			tevy_cacti.append(plant)
	boulder_model = _load_3d_asset("res://GraniteBoulder.glb")
	nama_boulder = _load_3d_asset("res://namaqualand_boulder_02.glb")
	nama_trunk = _load_3d_asset("res://dead_quiver_trunk.glb")
	for path in ["res://low-poly-grass-clump.glb", "res://low-poly-flower-patch.glb"]:
		var cover := _load_3d_asset(path)
		if cover != null:
			add_child(cover)
			cover.hide()
			forest_cover.append(cover)
	for template in [cactus_model, boulder_model, nama_boulder, nama_trunk]:
		if template != null:
			add_child(template)
			template.hide()
	var script_resource := get_script() as Script
	var art_path := script_resource.resource_path.get_base_dir().path_join("ColEngelleri.png")
	if FileAccess.file_exists(art_path):
		var art := Image.load_from_file(art_path)
		if art != null and not art.is_empty():
			obstacle_art = ImageTexture.create_from_image(art)
	# --- zemin shader'ı
	var terrain_shader := Shader.new()
	terrain_shader.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wpos;
uniform sampler2D sand_art : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_relief : repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool use_sand_relief = false;
uniform sampler2D asphalt_art : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool use_sand_art = false;
uniform bool use_asphalt_art = false;
uniform int map_style = 0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float road_x(float z) { return 40.0 * sin(z * 0.010) + 25.0 * sin(z * 0.0037 + 1.3); }
float road_slope(float z) { return 0.4 * cos(z * 0.010) + 0.0925 * cos(z * 0.0037 + 1.3); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = vnoise(p * 0.12);
	float n2 = vnoise(p * 0.7);
	float n3 = vnoise(p * 5.0);
	vec3 sand_light = vec3(0.54, 0.41, 0.30);
	vec3 sand_dark = vec3(0.34, 0.23, 0.16);
	vec3 col = mix(sand_light, sand_dark, n1 * 0.6 + n2 * 0.3 + n3 * 0.1);
	float phase = p.x * 10.0 + p.y * 6.0 + vnoise(p * 0.18) * 9.0;
	float rip = pow(sin(phase + sin(phase) * 0.30) * 0.5 + 0.5, 2.2);
	float ripple_fade = 1.0 - smoothstep(0.10, 0.65, length(fwidth(p)));
	float slope = length(vec2(dFdx(wpos.y), dFdy(wpos.y))) / max(length(fwidth(p)), 0.001);
	float dune_mask = smoothstep(0.08, 0.25, slope);
	if (use_sand_art) {
		vec3 sand_detail = texture(sand_art, p * 0.25).rgb;
		float tone = map_style == 1 ? 0.93 : 0.73;
		col = mix(col, sand_detail * tone, map_style == 0 ? mix(0.16, 0.68, dune_mask) : 0.92);
	} else {
		col *= 1.0 + ripple_fade * dune_mask * (rip * 0.26 - 0.10);
	}
	vec2 grain = p * 7.0;
	float gravel = smoothstep(0.58, 0.78, vnoise(p * 0.27 + 31.0));
	float stone = 1.0 - smoothstep(0.10, 0.25, length(fract(grain) - vec2(0.5)));
	col = mix(col, vec3(0.40, 0.29, 0.23), gravel * stone * hash12(floor(grain)) * ripple_fade);

	float s = road_slope(p.y);
	float d = abs(p.x - road_x(p.y)) / sqrt(1.0 + s * s);
	if (map_style == 4) {
		vec2 street = abs(mod(p + vec2(16.0), vec2(32.0)) - vec2(16.0));
		d = min(street.x, street.y);
	}
	float half_w = 4.2;
	if (map_style >= 5) {
		vec2 axes = map_style == 5 ? vec2(99.0, 65.0) : (map_style == 6 ? vec2(128.0, 80.0) : vec2(110.0, 69.0));
		vec2 q = p / axes;
		float a = atan(q.y, q.x + 0.00001);
		float radius = map_style == 7 ? 1.0 + 0.18 * sin(a * 3.0) + 0.06 * cos(a * 6.0) : (map_style == 6 ? pow(pow(abs(cos(a)), 5.0) + pow(abs(sin(a)), 5.0), -0.2) : 1.0 + 0.11 * sin(a * 5.0) + 0.075 * sin(a * 3.0));
		d = abs(length(q) - radius) * axes.y;
	}
	float roadmask = 1.0 - smoothstep(half_w - 0.2, half_w + 0.2, d);
	float dust_edge = 1.0 - smoothstep(half_w, half_w + 3.0, d);
	col = mix(col, col * 0.85, dust_edge * 0.6);

	vec3 asphalt = vec3(0.20, 0.19, 0.18) * (0.77 + 0.35 * n2 + 0.16 * n3);
	if (use_asphalt_art) {
		vec3 road_detail = texture(asphalt_art, p * 0.25).rgb;
		asphalt = mix(asphalt, road_detail * (map_style == 1 ? 0.60 : 0.85), 0.78);
	}
	float sand_cover = smoothstep(0.55, 0.9, vnoise(p * 0.25 + 7.0));
	asphalt = mix(asphalt, col, sand_cover * (0.10 + 0.60 * smoothstep(half_w - 1.5, half_w, d)));
	float rubber = (1.0 - smoothstep(0.18, 0.42, abs(d - 1.48 + n1 * 0.23))) * n2;
	asphalt *= 1.0 - rubber * 0.31;
	float edge_line = smoothstep(half_w - 0.62, half_w - 0.55, d) * (1.0 - smoothstep(half_w - 0.40, half_w - 0.33, d));
	float dash = (1.0 - smoothstep(0.10, 0.16, d)) * (1.0 - step(0.55, fract(p.y / 9.0)));
	float wear = 0.75 + 0.25 * vnoise(p * 3.0);
	asphalt = mix(asphalt, vec3(0.85), edge_line * wear);
	asphalt = mix(asphalt, vec3(0.9, 0.75, 0.2), dash * wear);
	col = mix(col, asphalt, roadmask);
	if (map_style >= 5) {
		vec3 turf = mix(vec3(0.12, 0.20, 0.10), vec3(0.24, 0.31, 0.15), n1);
		vec3 gravel = vec3(0.28, 0.23, 0.17) * (0.58 + n3 * 0.63 + n2 * 0.27);
		col = mix(mix(gravel, turf, smoothstep(10.5, 14.0, d)), asphalt, roadmask);
		float kerb = smoothstep(3.95, 4.12, d) * (1.0 - smoothstep(4.58, 4.75, d));
		col = mix(col, mix(vec3(0.74), vec3(0.43, 0.04, 0.035), step(0.5, fract((p.x + p.y) * 0.46))), kerb);
		float checker = mod(floor(p.x * 1.3) + floor(p.y * 1.3), 2.0);
		if (p.x > 0.0 && abs(p.y) < 1.2 && d < half_w - 0.15) {
			col = mix(vec3(0.045), vec3(0.84), checker);
		}
	}
	if (map_style == 4) {
		vec2 street = abs(mod(p + vec2(16.0), vec2(32.0)) - vec2(16.0));
		float joint = step(0.965, max(fract(p.x * 1.2), fract(p.y * 1.2)));
		float paving = mix(0.39, 0.29, joint);
		vec3 city_asphalt = mix(vec3(0.11, 0.12, 0.13), asphalt, 0.54);
		col = mix(vec3(paving * 1.05, paving, paving * 0.93), city_asphalt, roadmask);
		if (max(street.x, street.y) < 4.25) {
			col = vec3(0.18, 0.19, 0.21) * (0.9 + 0.2 * n2);
		}
	}
	if (map_style == 0) {
		vec3 beige = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), 0.32);
		col = mix(col, beige * vec3(1.03, 0.97, 0.92), 1.0 - roadmask);
	}

	ALBEDO = col;
	if (map_style == 0 && use_sand_relief) {
		vec3 relief = texture(sand_relief, p * 0.25).xyz * 2.0 - 1.0;
		vec3 axis_x = (VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
		vec3 axis_z = (VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
		NORMAL = normalize(NORMAL + (axis_x * relief.x - axis_z * relief.y)
			* mix(0.07, 0.34, dune_mask) * ripple_fade * (1.0 - roadmask));
	}
	ROUGHNESS = mix(1.0, 0.9, roadmask);
	SPECULAR = 0.0;
}
"""
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = terrain_shader
	var relief_path := "res://MeshySandNormal2K.jpg"
	var relief_texture: Texture2D
	if ResourceLoader.exists(relief_path, "Texture2D"):
		relief_texture = ResourceLoader.load(relief_path, "Texture2D") as Texture2D
	elif FileAccess.file_exists(relief_path):
		var relief_image := Image.load_from_file(relief_path)
		if relief_image != null and not relief_image.is_empty():
			relief_image.generate_mipmaps()
			relief_texture = ImageTexture.create_from_image(relief_image)
	if relief_texture != null:
		terrain_mat.set_shader_parameter("sand_relief", relief_texture)
		terrain_mat.set_shader_parameter("use_sand_relief", true)
	for texture_info: Array in [
		["res://MeshyDesertSand2K.jpg", "sand_art", "use_sand_art"],
		["res://TevyAsphalt.png", "asphalt_art", "use_asphalt_art"],
	]:
		var path: String = texture_info[0]
		var map: Texture2D
		if ResourceLoader.exists(path, "Texture2D"):
			map = ResourceLoader.load(path, "Texture2D") as Texture2D
		elif FileAccess.file_exists(path):
			var bitmap := Image.load_from_file(path)
			if bitmap != null and not bitmap.is_empty():
				bitmap.generate_mipmaps()
				map = ImageTexture.create_from_image(bitmap)
		if map != null:
			terrain_mat.set_shader_parameter(texture_info[1], map)
			terrain_mat.set_shader_parameter(texture_info[2], true)


	mat_rock = _std(Color("8e604d"), 0.0, 1.0)
	mat_cactus = _std(Color("34734c"), 0.0, 0.8)
	mat_post = _std(Color("e8e8e8"), 0.0, 0.6)
	mat_reflect = _std(Color("ff3b30"), 0.0, 0.4)
	mat_reflect.emission_enabled = true
	mat_reflect.emission = Color("ff3b30")
	mat_reflect.emission_energy_multiplier = 0.8
	mat_coin = _std(Color("ffc928"), 0.9, 0.25)
	mat_coin.emission_enabled = true
	mat_coin.emission = Color("ffb300")
	mat_coin.emission_energy_multiplier = 0.6

	# araba
	mat_paint = _std(paint_colors[0], 0.32, 0.31)
	mat_paint.clearcoat_enabled = true
	mat_paint.clearcoat = 0.8
	mat_paint.clearcoat_roughness = 0.1
	mat_glass = _std(Color(0.05, 0.08, 0.12), 0.9, 0.05)
	mat_black = _std(Color(0.06, 0.06, 0.07), 0.2, 0.6)
	mat_chrome = _std(Color(0.85, 0.85, 0.88), 1.0, 0.15)
	mat_tire = _std(Color(0.04, 0.04, 0.04), 0.0, 0.95)
	mat_rim = _std(Color("a47b49"), 0.65, 0.28)
	mat_spoke = _std(Color("cb9e66"), 0.6, 0.35)
	mat_mark = _std(Color(0.95, 0.95, 0.95), 0.0, 0.8)
	mat_stripe = _std(Color(0.95, 0.95, 0.95), 0.2, 0.4)
	lens_mat = _std(Color(1.0, 0.97, 0.85), 0.0, 0.2)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(1.0, 0.95, 0.8)
	lens_mat.emission_energy_multiplier = 0.3
	tail_mat = _std(Color(0.8, 0.05, 0.05), 0.0, 0.3)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.05, 0.05)
	tail_mat.emission_energy_multiplier = 0.8
	flame_mat = _unshaded(Color(1.0, 0.55, 0.1))

	# paylaşılan mesh'ler
	m_cactus_trunk = _cyl(0.32, 0.4, 3.2, 12)
	m_cactus_arm_h = _cyl(0.18, 0.18, 0.8, 10)
	m_cactus_arm_v = _cyl(0.18, 0.18, 1.0, 10)
	m_cap_big = _sphere(0.32, 12, 6)
	m_cap_small = _sphere(0.18, 10, 5)
	m_rock = _sphere(1.0, 8, 5)
	m_post = _box(0.12, 1.0, 0.12)
	m_reflect = _box(0.14, 0.14, 0.14)
	m_coin = _cyl(0.55, 0.55, 0.1, 16)
	m_tire = _cyl(0.38, 0.38, 0.28, 20)
	m_rim = _cyl(0.22, 0.22, 0.30, 14)
	m_spoke = _box(0.30, 0.40, 0.05)
	m_mark = _box(0.12, 0.05, 0.12)


func _build_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	env.glow_intensity = 0.28
	env.fog_enabled = true
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 46.0 if mobile_low_detail else 78.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.5
	cam.far = 700.0
	add_child(cam)
	cam.current = true

	_set_daylight()


# ================================================================ Araba modeli

func _build_car() -> void:
	car = Node3D.new()
	add_child(car)
	car_body = Node3D.new()
	car.add_child(car_body)
	var b := car_body
	var undertray := _std(Color("272729"), 0.28, 0.74)
	_inst(b, _box(1.48, 0.055, 3.62), undertray, Vector3(0, 0.29, 0))
	_inst(b, _cyl(0.056, 0.056, 2.36, 12), mat_chrome,
		Vector3(0.20, 0.25, -0.35), Vector3(PI * 0.5, 0, 0))
	_inst(b, _box(0.40, 0.13, 0.42), mat_chrome, Vector3(0.16, 0.27, -1.65))

	# gövde
	_coupe_shell(b, [
		Vector4(-2.18, 0.88, 0.43, 0.77),
		Vector4(-1.43, 1.04, 0.34, 0.91),
		Vector4(-0.45, 0.92, 0.32, 0.83),
		Vector4(0.55, 0.92, 0.32, 0.90),
		Vector4(1.38, 1.04, 0.35, 0.88),
		Vector4(2.18, 0.86, 0.38, 0.70),
	], mat_paint)
	var hood := Node3D.new()
	b.add_child(hood)
	hood.position = Vector3(0, 0.85, 1.42)
	hood.rotation.x = 0.22
	_coupe_shell(b, [
		Vector4(-2.08, 0.73, 0.72, 0.82),
		Vector4(-1.57, 0.94, 0.74, 0.98),
		Vector4(-1.18, 0.79, 0.78, 0.95),
	], mat_paint)
	for side: float in [-1.0, 1.0]:
		var vent := _inst(hood, _box(0.24, 0.035, 0.53), mat_black,
			Vector3(side * 0.43, 0.080, -0.06))
		vent.rotation.y = side * 0.16
		for slot in range(3):
			_inst(vent, _box(0.20, 0.014, 0.032), mat_spoke,
				Vector3(0, 0.021, (slot - 1) * 0.13))
	# kabin
	_coupe_shell(b, [
		Vector4(-1.34, 0.76, 0.82, 0.94),
		Vector4(-0.72, 0.78, 0.86, 1.34),
		Vector4(0.18, 0.77, 0.86, 1.34),
		Vector4(0.95, 0.75, 0.81, 0.93),
	], mat_glass)
	_coupe_shell(b, [
		Vector4(-0.76, 0.40, 1.20, 1.31),
		Vector4(-0.55, 0.60, 1.20, 1.37),
		Vector4(0.05, 0.59, 1.20, 1.37),
		Vector4(0.26, 0.40, 1.20, 1.31),
	], mat_paint)
	for sx: float in [-0.78, 0.78]:
		_inst(b, _box(0.055, 0.28, 0.065), mat_paint, Vector3(sx * 0.87, 1.05, -0.31))
	# çizgiler
	_inst(hood, _box(0.15, 0.008, 1.30), mat_stripe, Vector3(0, 0.045, 0))
	_inst(b, _box(0.15, 0.008, 0.90), mat_stripe, Vector3(0, 1.377, -0.27))
	_inst(b, _box(0.3, 0.005, 0.9), mat_stripe, Vector3(0, 1.0235, -1.6))
	# tamponlar, ızgara, etekler
	_inst(b, _box(1.42, 0.13, 0.10), mat_black, Vector3(0, 0.50, 2.18))
	_inst(b, _box(1.56, 0.12, 0.10), mat_black, Vector3(0, 0.48, -2.18))
	_inst(b, _box(1.0, 0.18, 0.05), mat_black, Vector3(0, 0.72, 2.2))
	_inst(b, _box(1.93, 0.07, 0.38), mat_black, Vector3(0, 0.33, 2.1))
	for sx: float in [-0.97, 0.97]:
		_inst(b, _box(0.1, 0.15, 2.6), mat_black, Vector3(sx, 0.4, 0))
		_inst(b, _box(0.12, 0.1, 0.2), mat_paint, Vector3(sx * 1.05, 1.0, 0.75))  # ayna
	# farlar ve stoplar
	for sx: float in [-0.65, 0.65]:
		_lamp_strip(b, signf(sx), false)
		_lamp_strip(b, signf(sx), true)
	# spoiler
	var wing := _inst(b, _box(2.10, 0.07, 0.57), mat_black, Vector3(0, 1.48, -2.05))
	wing.rotation.x = -0.17
	for side: float in [-1.0, 1.0]:
		_inst(wing, _box(0.055, 0.20, 0.63), mat_black,
			Vector3(side * 1.04, 0.025, 0))
	for sx: float in [-0.6, 0.6]:
		var pylon := _inst(b, _box(0.06, 0.54, 0.13), mat_black, Vector3(sx, 1.19, -1.98))
		pylon.rotation.x = -0.22
	# egzoz + nitro alevi
	for sx: float in [-0.45, 0.45]:
		_inst(b, _cyl(0.07, 0.07, 0.25, 10), mat_chrome, Vector3(sx, 0.42, -2.25), Vector3(PI / 2.0, 0, 0))
		var fl := _inst(b, _cyl(0.0, 0.13, 0.8, 10), flame_mat, Vector3(sx, 0.42, -2.6), Vector3(-PI / 2.0, 0, 0))
		fl.visible = false
		flames.append(fl)

	# farlar (ışık)
	for sx: float in [-0.65, 0.65]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(sx, 0.75, 2.1)
		spot.rotation_degrees = Vector3(-8.0, 180.0, 0.0)
		spot.spot_range = 45.0
		spot.spot_angle = 34.0
		spot.light_energy = 5.0
		spot.light_color = Color(1.0, 0.95, 0.8)
		spot.visible = false
		b.add_child(spot)
		spots.append(spot)

	# tekerlekler
	_make_wheel(car, Vector3(-0.97, 0.38, 1.3), true)
	_make_wheel(car, Vector3(0.97, 0.38, 1.3), true)
	_make_wheel(car, Vector3(-0.97, 0.38, -1.3), false)
	_make_wheel(car, Vector3(0.97, 0.38, -1.3), false)

	# toz ve duman
	dust = _make_particles(Color(0.86, 0.74, 0.52, 0.55), 90, 1.5)
	snow_fall = CPUParticles3D.new()
	snow_fall.emitting = false
	snow_fall.amount = 140 if mobile_low_detail else 285
	snow_fall.lifetime = 3.4
	snow_fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow_fall.emission_box_extents = Vector3(20, 4, 18)
	snow_fall.direction = Vector3(0.25, -1.0, 0.13)
	snow_fall.spread = 9
	snow_fall.initial_velocity_min = 4
	snow_fall.initial_velocity_max = 7
	snow_fall.gravity = Vector3(0, -0.8, 0)
	var flake := _sphere(0.065, 5, 3)
	flake.material = _unshaded(Color("#f4f8ff"))
	snow_fall.mesh = flake
	add_child(snow_fall)
	spray_cloud_mesh = dust.mesh
	for side: float in ([0.0] if mobile_low_detail else [-1.0, 1.0]):
		var plume := _make_particles(Color(0.80, 0.64, 0.42, 0.64), 72, 2.1 if mobile_low_detail else 3.8)
		_make_storm_cloud(plume)
		plume.position = Vector3(side * 0.89, 0.20, -1.35)
		plume.direction = Vector3(side * 0.58, 0.22, -1.0)
		plume.emission_box_extents = Vector3(0.2, 0.05, 0.25)
		plume.spread = 24.0
		plume.initial_velocity_min = 2.2
		plume.initial_velocity_max = 6.2
		plume.gravity = Vector3(0, 0.42, 0)
		plume.scale_amount_min = 1.0
		plume.scale_amount_max = 2.4 if mobile_low_detail else 3.6
		plume.angular_velocity_min = -58.0
		plume.angular_velocity_max = 58.0
		var billow := Curve.new()
		billow.max_value = 2.0
		billow.add_point(Vector2(0.0, 0.18))
		billow.add_point(Vector2(0.28, 0.9))
		billow.add_point(Vector2(0.72, 1.5))
		billow.add_point(Vector2(1.0, 1.75))
		plume.scale_amount_curve = billow
		car.add_child(plume)
		desert_plumes.append(plume)
	sand_burst = _make_particles(Color(0.85, 0.68, 0.43, 0.72), 30, 1.1)
	_make_storm_cloud(sand_burst)
	sand_burst.position = Vector3(0, 0.24, -1.48)
	sand_burst.one_shot = true
	sand_burst.explosiveness = 0.85
	sand_burst.spread = 52.0
	sand_burst.initial_velocity_min = 5.0
	sand_burst.initial_velocity_max = 11.0
	sand_burst.gravity = Vector3(0, -3.8, 0)
	car.add_child(sand_burst)
	dust.position = Vector3(0, 0.25, -1.4)
	car.add_child(dust)
	smoke = _make_particles(Color(0.85, 0.85, 0.85, 0.5), 60, 1.2)
	smoke.position = Vector3(0, 0.25, -1.4)
	car.add_child(smoke)
	vinish_car_active = _install_vinish_car(vehicle_index)


func _load_vinish_model(index: int) -> Node3D:
	if VEHICLE_FILES[index] == "DesertRaptor":
		return _make_raptor()
	return _load_3d_asset("res://%s.glb" % VEHICLE_FILES[index])


func _load_3d_asset(path: String) -> Node3D:
	var model: Node3D
	if ResourceLoader.exists(path, "PackedScene"):
		var packed := ResourceLoader.load(path, "PackedScene") as PackedScene
		if packed != null:
			model = packed.instantiate() as Node3D
	elif FileAccess.file_exists(path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) == OK:
			model = document.generate_scene(state) as Node3D
	return model


func _install_vinish_car(index: int) -> bool:
	var model := _load_vinish_model(index)
	if model == null:
		return false
	var wheels: Array[Node3D] = []
	var names := ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
	if VEHICLE_FILES[index] == "Enduro":
		names = ["Wheel_Front", "Wheel_Rear"]
	elif VEHICLE_FILES[index] in ["GrabATV", "GrabBuggy"]:
		var prefix := "atv-quad" if VEHICLE_FILES[index] == "GrabATV" else "dune-buggy"
		names = [prefix + "_wheel_fl", prefix + "_wheel_fr", prefix + "_wheel_rl", prefix + "_wheel_rr"]
	elif VEHICLE_FILES[index] == "MonsterTruck":
		names = ["monster-truck_wheel_fl", "monster-truck_wheel_fr", "monster-truck_wheel_rl", "monster-truck_wheel_rr"]
	elif index in [STARTER_INDEX, STARTER_INDEX + 1]:
		names = []
		for suffix in ["fl", "fr", "rl", "rr"]:
			names.append(str(VEHICLE_FILES[index]) + "_wheel_" + suffix)
	if VEHICLE_FILES[index] in ["TevySnowmobile", "DesertRaptor"]:
		names = []
	for wheel_name in names:
		var wheel := model.find_child(wheel_name, true, false) as Node3D
		if wheel == null:
			model.free()
			return false
		wheels.append(wheel)
	for child in car_body.get_children():
		if child is Node3D and child not in spots:
			child.hide()
	for spin in wheel_spins:
		(spin as Node3D).hide()
	wheel_spins.clear()
	wheel_pivots.clear()
	if is_instance_valid(vehicle_model):
		vehicle_model.queue_free()
	vehicle_model = model
	car_body.add_child(model)
	model.scale = Vector3.ONE * 0.93
	if VEHICLE_FILES[index] == "TevySnowmobile":
		for ski_name in ["ski_L", "ski_R"]:
			var ski := model.find_child(ski_name, true, false) as Node3D
			if ski != null:
				wheel_pivots.append(ski)
	var stand := model.find_child("Side_Stand", true, false) as Node3D
	if stand != null:
		stand.hide()
	for instance in model.find_children("*", "MeshInstance3D", true, false):
		var part := instance as MeshInstance3D
		for i in range(part.mesh.get_surface_count()):
			var original := part.mesh.surface_get_material(i)
			if original != null and PAINT_OVERRIDES.has(original.resource_name):
				var paint := _std(PAINT_OVERRIDES[original.resource_name], 0.21, 0.44)
				if original.resource_name == "Paint_Acid":
					mat_paint = paint
				part.set_surface_override_material(i, paint)
	for i in range(wheels.size()):
		var wheel := wheels[i]
		var holder := Node3D.new()
		wheel.get_parent().add_child(holder)
		holder.position = wheel.position
		var spin := Node3D.new()
		holder.add_child(spin)
		wheel.reparent(spin, false)
		wheel.position = Vector3.ZERO
		wheel_spins.append(spin)
		if i < (1 if names.size() == 2 else 2):
			wheel_pivots.append(holder)
	return true


func _lamp_strip(parent: Node3D, side: float, rear: bool) -> void:
	var depth := -1.0 if rear else 1.0
	var light_color := Color("ff243a") if rear else Color("fff3d7")
	var points := [
		Vector3(side * 0.34, 0.63, depth * 2.24),
		Vector3(side * 0.56, 0.65, depth * 2.23),
		Vector3(side * 0.73, 0.69, depth * 2.18),
		Vector3(side * 0.85, 0.74, depth * 2.07),
	]
	var led := tail_mat if rear else lens_mat
	led.emission = light_color
	for i in range(points.size() - 1):
		var start: Vector3 = points[i]
		var end: Vector3 = points[i + 1]
		var span := end - start
		var housing := _inst(parent, _cyl(0.060, 0.060, span.length() + 0.035, 10),
			mat_black, (start + end) * 0.5)
		housing.basis = Basis(Quaternion(Vector3.UP, span.normalized()))
		var strip := _inst(parent, _cyl(0.027, 0.027, span.length() + 0.024, 10),
			led, (start + end) * 0.5 + Vector3(0, 0.021, depth * 0.046))
		strip.basis = housing.basis


func _wheel_flare(parent: Node3D, side: float, axle_z: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(15):
		var angle := lerpf(-0.16, PI + 0.16, float(i) / 14.0)
		for row in range(3):
			var radius := [0.40, 0.46, 0.60][row] as float
			var outer_x := [1.10, 1.15, 0.96][row] as float
			surface.add_vertex(Vector3(side * outer_x,
				0.38 + sin(angle) * radius, axle_z + cos(angle) * radius))
	for i in range(14):
		for row in range(2):
			var a := i * 3 + row
			var ids := [a, a + 1, a + 3, a + 1, a + 4, a + 3]
			if side < 0.0:
				ids.reverse()
			for index: int in ids:
				surface.add_index(index)
	surface.generate_normals()
	_inst(parent, surface.commit(), mat_paint)


func _coupe_shell(parent: Node3D, sections: Array, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section: Vector4 in sections:
		var center := (section.z + section.w) * 0.5
		var height := (section.w - section.z) * 0.5
		for i in range(28):
			var angle := TAU * float(i) / 28.0
			var x := cos(angle)
			var y := sin(angle)
			surface.add_vertex(Vector3(signf(x) * pow(absf(x), 0.55) * section.y,
				center + signf(y) * pow(absf(y), 0.62) * height, section.x))
	for ring in range(sections.size() - 1):
		for i in range(28):
			var a := ring * 28 + i
			var b := ring * 28 + (i + 1) % 28
			for index: int in [a, a + 28, b, b, a + 28, b + 28]:
				surface.add_index(index)
	var last := (sections.size() - 1) * 28
	for i in range(1, 27):
		for index: int in [0, i, i + 1, last, last + i + 1, last + i]:
			surface.add_index(index)
			surface.add_index(index)
	surface.generate_normals()
	_inst(parent, surface.commit(), material)


func _make_wheel(parent: Node3D, p: Vector3, front: bool) -> void:
	_wheel_flare(car_body, signf(p.x), p.z)
	var pivot := Node3D.new()
	pivot.position = p
	parent.add_child(pivot)
	var spin := Node3D.new()
	pivot.add_child(spin)
	_inst(spin, m_tire, mat_tire, Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	var side := signf(p.x)
	var face := Vector3(side * 0.147, 0, 0)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.221
	lip.outer_radius = 0.252
	lip.rings = 24
	lip.ring_segments = 8
	_inst(spin, lip, mat_rim, face, Vector3(0, 0, PI / 2.0))
	_inst(spin, m_rim, mat_black, Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	_inst(spin, _cyl(0.072, 0.072, 0.029, 16), mat_rim, face, Vector3(0, 0, PI / 2.0))
	var spoke_mesh := _box(0.029, 0.17, 0.049)
	for k in range(6):
		var angle := TAU * float(k) / 6.0
		var axis := Vector3(0, cos(angle), sin(angle))
		_inst(spin, spoke_mesh, mat_spoke, face + axis * 0.14, Vector3(angle, 0, 0))
	wheel_spins.append(spin)
	if front:
		wheel_pivots.append(pivot)


func _raptor_part(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var part := _inst(parent, _sphere(0.5), material, at)
	part.scale = size
	return part


func _make_raptor() -> Node3D:
	var model := Node3D.new()
	var scales := _std(Color("#577244"))
	var belly := _std(Color("#ad9563"))
	var leather := _std(Color("#582d20"))
	var jacket := _std(Color("#246679"))
	_raptor_part(model, Vector3(0, 1.05, 0), Vector3(0.75, 0.75, 1.62), scales)
	_raptor_part(model, Vector3(0, 0.91, 0.12), Vector3(0.66, 0.55, 1.22), belly)
	var tail := _raptor_part(model, Vector3(0, 1.10, -1.29), Vector3(0.34, 0.32, 1.93), scales)
	tail.rotation.x = 0.11
	var neck := _raptor_part(model, Vector3(0, 1.42, 0.77), Vector3(0.42, 0.94, 0.43), scales)
	neck.rotation.x = 0.48
	_raptor_part(model, Vector3(0, 1.80, 1.14), Vector3(0.49, 0.43, 0.69), scales)
	_raptor_part(model, Vector3(0, 1.68, 1.49), Vector3(0.39, 0.24, 0.60), belly)
	_raptor_part(model, Vector3(0, 1.43, -0.18), Vector3(0.62, 0.19, 0.58), leather)
	_raptor_part(model, Vector3(0, 1.80, -0.16), Vector3(0.39, 0.55, 0.32), jacket)
	_raptor_part(model, Vector3(0, 2.17, -0.10), Vector3(0.30, 0.32, 0.32), mat_black)
	for side: float in [-1.0, 1.0]:
		_raptor_part(model, Vector3(side * 0.22, 1.86, 1.28), Vector3.ONE * 0.10, lens_mat)
		_raptor_part(model, Vector3(side * 0.25, 1.24, 0.70), Vector3(0.13, 0.22, 0.42), scales)
		_raptor_part(model, Vector3(side * 0.28, 1.54, -0.12), Vector3(0.18, 0.41, 0.33), mat_black)
		var arm := _raptor_part(model, Vector3(side * 0.20, 1.82, 0.08), Vector3(0.14, 0.15, 0.45), jacket)
		arm.rotation.x = 0.17
		var leg := Node3D.new()
		leg.name = "StrideLeft" if side < 0.0 else "StrideRight"
		model.add_child(leg)
		leg.position = Vector3(side * 0.29, 0.94, -0.19)
		_raptor_part(leg, Vector3(0, -0.23, 0.09), Vector3(0.32, 0.56, 0.40), scales)
		_raptor_part(leg, Vector3(0, -0.59, -0.10), Vector3(0.19, 0.51, 0.21), scales)
		_raptor_part(leg, Vector3(0, -0.85, 0.09), Vector3(0.23, 0.17, 0.48), belly)
	return model


func _make_particles(color: Color, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(8, roundi(amount * (0.31 if mobile_low_detail else 0.65)))
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.9, 0.05, 0.3)
	p.direction = Vector3(0, 0.45, -1)
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 0.5, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cloud_path := "res://DustCloud.png"
	if ResourceLoader.exists(cloud_path, "Texture2D"):
		pm.albedo_texture = ResourceLoader.load(cloud_path, "Texture2D") as Texture2D
	elif FileAccess.file_exists(cloud_path):
		var cloud := Image.load_from_file(cloud_path)
		if cloud != null and not cloud.is_empty():
			pm.albedo_texture = ImageTexture.create_from_image(cloud)
	if pm.albedo_texture != null:
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var card := QuadMesh.new()
		card.size = Vector2(1.25, 1.25)
		card.material = pm
		p.mesh = card
		return p
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = pm
	p.mesh = mesh
	return p


func _make_storm_cloud(particles: CPUParticles3D) -> void:
	var original := particles.mesh.surface_get_material(0) as StandardMaterial3D
	if original == null or original.albedo_texture == null:
		return
	var cloud := Shader.new()
	cloud.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D cloud_mask : filter_linear_mipmap;
varying vec4 dust_tint;
void vertex() {
	dust_tint = COLOR;
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * size.x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * size.y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	float mask = texture(cloud_mask, UV).a;
	float edge = 1.0 - smoothstep(0.28, 0.71, length(UV - vec2(0.5)));
	ALBEDO = dust_tint.rgb;
	ALPHA = dust_tint.a * mask * edge;
}
"""
	var material := ShaderMaterial.new()
	material.shader = cloud
	material.set_shader_parameter("cloud_mask", original.albedo_texture)
	var quad := QuadMesh.new()
	quad.size = Vector2(5.6, 3.2)
	quad.material = material
	particles.mesh = quad


func _build_skid_pool() -> void:
	var mat := _unshaded(Color(0.03, 0.03, 0.03, 0.5))
	var mesh := _box(0.28, 0.02, 0.9)
	for i in 160:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		skid_pool.append(mi)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var options := HBoxContainer.new()
	options.position = Vector2(16, 120)
	layer.add_child(options)
	var shop_button := Button.new()
	shop_button.text = tr("Ana Menü")
	options.add_child(shop_button)
	challenge_retry = Button.new()
	challenge_retry.text = tr("Yeniden dene")
	challenge_retry.hide()
	options.add_child(challenge_retry)
	challenge_retry.pressed.connect(func() -> void: _start_challenge(challenge_active))
	challenge_forward = Button.new()
	challenge_forward.text = tr("Sonraki bölüm")
	challenge_forward.hide()
	options.add_child(challenge_forward)
	challenge_forward.pressed.connect(func() -> void: _start_challenge(challenge_active + 1))
	race_heading_font = _load_race_font("res://BarlowCondensed-BoldItalic.ttf")
	race_body_font = _load_race_font("res://BarlowCondensed-SemiBold.ttf")
	var shop_content := _build_garage(layer)
	shop_button.pressed.connect(func() -> void:
		if session_start_gold >= 0:
			session_summary = _session_gold_text()
			session_start_gold = -1
		_clear_touch_controls()
		main_menu.show()
	)
	var credits := AcceptDialog.new()
	credits.title = tr("Krediler")
	credits.dialog_text = "Araçlar · vinish.dev (CC BY 4.0)\nFront-Engine Track Supercar, Wedge Supercar\nhttps://vinish.dev/free-3d-models/supercars\nMuscle Coupe, Boxy Off-Roader\nhttps://vinish.dev/free-3d-models/realistic-cars\nhttps://creativecommons.org/licenses/by/4.0/\nÖlçek uyarlandı, pist aracı yeniden renklendirildi.\n\nDireksiyon · SteeringWheel 02, looneybits (CC0)\nhttps://opengameart.org/content/steeringwheel-02"
	vehicle_shop.add_child(credits)
	var credit_button := Button.new()
	credits.dialog_text += "\nTyre Barrier ve Start Light Gantry · vinish.dev · CC BY 4.0 · Ölçek uyarlandı\nhttps://vinish.dev/free-3d-models/racing"
	credits.dialog_text += "\nUI Pack ve Racing Kit · Kenney · CC0\nhttps://opengameart.org/content/ui-pack\nhttps://opengameart.org/content/racing-kit"

	credits.dialog_text += "\nLow Poly Grass Clump ve Low Poly Flower Patch · vinish.dev · CC BY 4.0\nhttps://vinish.dev/free-3d-models/low-poly-nature"
	credits.dialog_text += "\nWind-rippled Desert Sand · Meshy / ambientCG · CC0\nhttps://www.meshy.ai/textures/ground/wind-rippled-desert-sand\nNamaqualand Boulder 02 ve Dead Quiver Trunk · Poly Haven · CC0\nhttps://polyhaven.com/collections/namaqualand"
	credits.dialog_text += "\nMonster Truck · Grab3D · CC0\nhttps://grab3d.com/models/vehicles/monster-truck/"
	credits.dialog_text += "\nLuxury SUV · vinish.dev · CC BY 4.0 · Ölçek uyarlandı\nhttps://vinish.dev/free-3d-models/realistic-cars\nDuman: Kenney Particle Pack · CC0\nÇamur: Mud Forest, Poly Haven · CC0"
	credits.dialog_text += "\nTevy Snowmobile ve zemin dokuları · CC0\nhttps://tevy.dev/models/snowmobile\nhttps://tevy.dev/materials"
	credits.dialog_text += "\nElectric Hypercar, V12 Grand Tourer, Retro City Car ve Classic Formula Racer · vinish.dev · CC BY 4.0\nÖlçek uyarlandı."
	credits.dialog_text += "\nGT Race Supercar ve American V8 Supercar · vinish.dev · CC BY 4.0\nhttps://vinish.dev/free-3d-models/supercars\nAraçların renk ve ölçekleri uyarlandı."
	credits.dialog_text += "\nSaguaro Cactus ve Granite Boulder · vinish.dev · CC BY 4.0 · Ölçek uyarlandı\nhttps://vinish.dev/free-3d-models/wild-west-props\nhttps://vinish.dev/free-3d-models/rocks"
	credits.dialog_text += "\nEnduro Motorcycle ve Rally Car · vinish.dev · CC BY 4.0\nhttps://vinish.dev/free-3d-models/motorcycles\nhttps://vinish.dev/free-3d-models/racing\nDune Buggy ve ATV Quad · Grab3D · CC0\nhttps://grab3d.com/models/vehicles/dune-buggy/\nhttps://grab3d.com/models/vehicles/atv-quad/"
	credits.dialog_text += "\nRace Track Start Finish, Race Checkpoint Arch, Race Grandstand, Race Pit Garage ve Race Track Jump Ramp · vinish.dev · CC BY 4.0 · Ölçek ve yerleşim uyarlandı.\nhttps://vinish.dev/free-3d-models/race-track-kit"
	credits.dialog_text += "\nGrand Tourer, Rear-Engine Sports Coupe, Hot Hatchback · vinish.dev · CC BY 4.0\nhttps://vinish.dev/free-3d-models/realistic-cars"
	credits.dialog_text += "\nVintage Roadster, Touring Car ve Vintage Coupe · vinish.dev · CC BY 4.0\nhttps://vinish.dev/free-3d-models/classic-cars\nTraffic Cone · vinish.dev · CC BY 4.0\nhttps://vinish.dev/free-3d-models/racing"
	credits.dialog_text += "\nCharging Bay (park boyaları) ve Solar Charging Canopy · vinish.dev · CC BY 4.0\nhttps://vinish.dev/free-3d-models/electric-cars-and-chargers"
	credits.dialog_text += "\nShipping Container, Concrete Barrier ve Oil Drum · vinish.dev · CC BY 4.0\nhttps://vinish.dev/free-3d-models/game-props"
	credit_button.text = tr("Krediler")
	credit_button.add_theme_font_size_override("font_size", 12)
	credit_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	shop_content.add_child(credit_button)
	credit_button.pressed.connect(func() -> void: credits.popup_centered())
	var pedal_path := "res://MotoCrossPedal.png"
	var wheel_path := "res://LeatherWheel.png"
	if ResourceLoader.exists(wheel_path, "Texture2D"):
		wheel_art = ResourceLoader.load(wheel_path, "Texture2D") as Texture2D
	elif FileAccess.file_exists(wheel_path):
		var wheel_image := Image.load_from_file(wheel_path)
		if wheel_image != null and not wheel_image.is_empty():
			wheel_art = ImageTexture.create_from_image(wheel_image)
	if ResourceLoader.exists(pedal_path, "Texture2D"):
		pedal_art = ResourceLoader.load(pedal_path, "Texture2D") as Texture2D
	elif FileAccess.file_exists(pedal_path):
		var bitmap := Image.load_from_file(pedal_path)
		if bitmap != null and not bitmap.is_empty():
			pedal_art = ImageTexture.create_from_image(bitmap)
	speed_label = _make_label(layer, 23)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label = _make_label(layer, 20)
	var hud_metal := _race_metal_skin(Color("#342820"), Color("#bf884e"))
	info_label.add_theme_stylebox_override("normal", hud_metal)
	speed_label.add_theme_stylebox_override("normal", hud_metal)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label = _make_label(layer, 26)
	drift_points_label = _make_label(layer, 30)
	drift_multiplier_label = _make_label(layer, 24)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.custom_minimum_size = Vector2(900, 40)
	drive_controls = Control.new()
	drive_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(drive_controls)
	drive_controls.draw.connect(_draw_drive_controls)
	coin_badge = _make_label(layer, 19)
	coin_badge.position = Vector2(47, 18)
	_build_main_menu(layer)
	nitro_bar = ProgressBar.new()
	nitro_bar.size = Vector2(300, 16)
	nitro_bar.max_value = 100.0
	nitro_bar.show_percentage = false
	nitro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(nitro_bar)


func _wheel_radius() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return clampf(minf(viewport_size.x, viewport_size.y) * 0.18, 36.0, 100.0)


func _wheel_center() -> Vector2:
	var radius := _wheel_radius()
	return Vector2(radius + 22.0, get_viewport().get_visible_rect().size.y - radius - 22.0)


func _pedal_rect(gas: bool) -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := _wheel_radius() * 0.82
	var height := _wheel_radius() * (1.60 if gas else 1.28)
	return Rect2(viewport_size.x - 22.0 - width * (1.0 if gas else 2.0) - (0.0 if gas else 12.0),
		viewport_size.y - 22.0 - height, width, height)


func _install_language() -> void:
	english_pack = Translation.new()
	english_pack.locale = "en"
	turkish_pack = Translation.new()
	turkish_pack.locale = "tr"
	for phrase in DesertLanguage.ENGLISH:
		english_pack.add_message(phrase, DesertLanguage.ENGLISH[phrase])
		turkish_pack.add_message(phrase, phrase)
	TranslationServer.add_translation(english_pack)
	TranslationServer.add_translation(turkish_pack)
	TranslationServer.set_locale("en" if ui_english else "tr")


func _exit_tree() -> void:
	if english_pack != null:
		TranslationServer.remove_translation(english_pack)
	if turkish_pack != null:
		TranslationServer.remove_translation(turkish_pack)

func _build_main_menu(layer: CanvasLayer) -> void:
	main_menu = ColorRect.new()
	(main_menu as ColorRect).color = Color("#1d1511")
	layer.add_child(main_menu)
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = _load_ui_texture("res://DesertGarage.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var buttons := VBoxContainer.new()
	main_menu.add_child(buttons)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	buttons.offset_left = 34
	buttons.offset_top = -241
	buttons.custom_minimum_size.x = 248
	buttons.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.add_theme_font_override("font", race_heading_font)
	title.text = "DRIFTLANE TRIALS"
	title.add_theme_color_override("font_color", Color("#fff0d9"))
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_constant_override("outline_size", 6)
	buttons.add_child(title)
	var balance := Label.new()
	balance.add_theme_font_override("font", race_heading_font)
	balance.add_theme_color_override("font_color", Color("#ffd16e"))
	balance.add_theme_font_size_override("font_size", 19)
	buttons.add_child(balance)
	main_session_label = Label.new()
	main_session_label.hide()
	buttons.add_child(main_session_label)
	main_menu.visibility_changed.connect(func() -> void:
		main_session_label.text = session_summary
		main_session_label.visible = not session_summary.is_empty()
	)
	main_menu.visibility_changed.connect(func() -> void: balance.text = tr("●  %d ALTIN") % coins_n)
	balance.text = tr("●  %d ALTIN") % coins_n
	for caption in ["GÖREVLER", "SERBEST DOLAŞIM", "YARIŞ", "ARAÇ GARAJI", "BAŞARIMLAR"]:
		var button := _garage_button(tr(caption), caption == "YARIŞ")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 52
		button.add_theme_font_size_override("font_size", 26)
		buttons.add_child(button)
		var tab := ["ARAÇ GARAJI", "SERBEST DOLAŞIM", "YARIŞ", "GÖREVLER", "BAŞARIMLAR"].find(caption)
		button.pressed.connect(func() -> void: _open_garage_tab(tab))

	var language := _garage_button("TÜRKÇE" if ui_english else "ENGLISH")
	buttons.add_child(language)
	language.pressed.connect(func() -> void:
		ui_english = not ui_english
		_save_garage_progress()
		get_tree().reload_current_scene()
	)

func _build_garage(layer: CanvasLayer) -> HBoxContainer:
	vehicle_shop = ColorRect.new()
	vehicle_shop.color = Color("#211814")
	layer.add_child(vehicle_shop)
	vehicle_shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vehicle_shop.hide()
	var theme := Theme.new()
	theme.default_font = race_body_font
	theme.default_font_size = 18
	vehicle_shop.theme = theme
	garage_backdrop = TextureRect.new()
	garage_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	garage_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	garage_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vehicle_shop.add_child(garage_backdrop)
	garage_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := HBoxContainer.new()
	_garage_place(vehicle_shop, header, Rect2(0.02, 0.025, 0.96, 0.09))
	header.add_theme_constant_override("separation", 9)
	var back := _garage_button(tr("❮  GERİ"))
	header.add_child(back)
	back.pressed.connect(func() -> void: vehicle_shop.hide())
	var vehicles := _garage_button(tr("ARAÇ GARAJI"), true)
	header.add_child(vehicles)
	vehicles.pressed.connect(func() -> void: _open_garage_tab(0))
	var maps := _garage_button(tr("SERBEST DOLAŞIM"))
	header.add_child(maps)
	maps.pressed.connect(func() -> void: _open_garage_tab(1))
	var race := _garage_button(tr("YARIŞ"))
	header.add_child(race)
	race.pressed.connect(func() -> void: _open_garage_tab(2))
	var challenges := _garage_button(tr("GÖREVLER"))
	header.add_child(challenges)
	challenges.pressed.connect(func() -> void: _open_garage_tab(3))
	var achievements := _garage_button(tr("BAŞARIMLAR"))
	header.add_child(achievements)
	achievements.pressed.connect(func() -> void: _open_garage_tab(4))
	garage_nav = [vehicles, maps, race, challenges, achievements]
	var balance := Label.new()
	garage_balance = balance
	balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance.add_theme_color_override("font_color", Color("#ffcb74"))
	balance.add_theme_constant_override("outline_size", 8)
	header.add_child(balance)
	vehicle_shop.visibility_changed.connect(func() -> void: balance.text = tr("%d ALTIN") % coins_n)
	garage_page = Control.new()
	_garage_place(vehicle_shop, garage_page, Rect2(0, 0.14, 1, 0.84))
	var stage := HBoxContainer.new()
	_garage_place(garage_page, stage, Rect2(0.04, 0, 0.68, 0.78))
	_build_shop_preview(stage)
	for side: int in [-1, 1]:
		var arrow := _garage_button("❮" if side < 0 else "❯")
		_garage_place(garage_page, arrow, Rect2(0.025 if side < 0 else 0.66, 0.32, 0.055, 0.15))
		arrow.pressed.connect(func() -> void: _browse_garage_car(garage_order[posmod(garage_order.find(preview_vehicle_index) + side, garage_order.size())]))
	var stats := _garage_panel(garage_page, Rect2(0.735, 0.03, 0.245, 0.72))
	garage_car_name = Label.new()
	garage_car_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	garage_car_name.add_theme_font_override("font", race_heading_font)
	garage_car_name.add_theme_font_size_override("font_size", 29)
	stats.add_child(garage_car_name)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats.add_child(spacer)
	garage_speed = Label.new()
	stats.add_child(garage_speed)
	garage_meter = ProgressBar.new()
	garage_meter.max_value = float(TOP_SPEEDS.max()) * 3.6
	garage_meter.show_percentage = false
	garage_meter.custom_minimum_size.y = 9
	var meter_skin := StyleBoxFlat.new()
	meter_skin.bg_color = Color("#edaa4a")
	garage_meter.add_theme_stylebox_override("fill", meter_skin)
	stats.add_child(garage_meter)
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats.add_child(spacer_bottom)
	garage_pick = _garage_button(tr("ARACI SEÇ"), true)
	stats.add_child(garage_pick)
	garage_pick.pressed.connect(_buy_or_select_car)
	garage_strip = HBoxContainer.new()
	garage_strip.add_theme_constant_override("separation", 8)
	_garage_place(garage_page, garage_strip, Rect2(0.025, 0.80, 0.95, 0.18))
	for slot in range(5):
		var card := _garage_button("")
		card.custom_minimum_size.y = 56
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.expand_icon = true
		card.add_theme_font_size_override("font_size", 15)
		card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		garage_strip.add_child(card)
		card.pressed.connect(func() -> void: _browse_garage_car(int(card.get_meta("car"))))
	garage_maps = Control.new()
	_garage_place(vehicle_shop, garage_maps, Rect2(0, 0.14, 1, 0.84))
	_build_map_catalog(garage_maps)
	_build_challenge_catalog()
	_build_achievement_catalog()
	return header


func _garage_place(parent: Control, child: Control, bounds: Rect2) -> void:
	parent.add_child(child)
	child.set_anchor(SIDE_LEFT, bounds.position.x)
	child.set_anchor(SIDE_TOP, bounds.position.y)
	child.set_anchor(SIDE_RIGHT, bounds.end.x)
	child.set_anchor(SIDE_BOTTOM, bounds.end.y)
	for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		child.set_offset(edge, 0.0)


func _garage_panel(parent: Control, bounds: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _race_metal_skin(Color("#30251f"), Color("#8e6d50")))
	_garage_place(parent, panel, bounds)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	return content


func _garage_button(caption: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 38
	_style_shop_button(button, Color("#98591f") if primary else Color("#322822"))
	return button


func _load_garage_progress() -> void:
	var save := ConfigFile.new()
	if save.load(GARAGE_SAVE) != OK:
		return
	ui_english = bool(save.get_value("settings", "english", false))
	coins_n = maxi(0, int(save.get_value("garage", "coins", 0)))
	owned_cars = save.get_value("garage", "owned", [STARTER_INDEX]) if int(save.get_value("garage", "economy_version", 0)) >= 1 else [STARTER_INDEX]
	if STARTER_INDEX not in owned_cars:
		owned_cars.append(STARTER_INDEX)
	var selected := int(save.get_value("garage", "car", STARTER_INDEX))
	if selected in owned_cars and selected >= 0 and selected < VEHICLE_NAMES.size() and selected not in RETIRED_CARS:
		vehicle_index = selected
	map_coins = save.get_value("goals", "coins", {})
	map_meters = save.get_value("goals", "meters", {})
	map_drift = save.get_value("goals", "drift", {})
	accomplishments = save.get_value("goals", "earned", {})
	challenge_completed = save.get_value("challenges", "done", {})
	var layout_version := int(save.get_value("challenges", "layout_version", 1))
	if layout_version < 3:
		var old_drift := 10 if layout_version < 2 else 24
		for old in [old_drift, old_drift + 1]:
			if challenge_completed.has(old):
				challenge_completed[DRIFT_LEVEL + old - old_drift] = true
				challenge_completed.erase(old)
		var old_goal := Vector2i(MAP_NAMES.size(), 1)
		if layout_version < 2 and accomplishments.has(old_goal):
			accomplishments.erase(old_goal)
	race_lap_records = save.get_value("goals", "best_laps", {})
	race_win_records = save.get_value("goals", "wins", {})


func _save_garage_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("settings", "english", ui_english)
	save.set_value("garage", "coins", coins_n)
	save.set_value("garage", "owned", owned_cars)
	save.set_value("garage", "economy_version", 1)
	save.set_value("garage", "car", vehicle_index)
	save.set_value("goals", "coins", map_coins)
	save.set_value("goals", "meters", map_meters)
	save.set_value("goals", "drift", map_drift)
	save.set_value("goals", "earned", accomplishments)
	save.set_value("goals", "best_laps", race_lap_records)
	save.set_value("goals", "wins", race_win_records)
	save.set_value("challenges", "done", challenge_completed)
	save.set_value("challenges", "layout_version", 3)
	save.save(GARAGE_SAVE)


func _queue_progress_save() -> void:
	if save_queued:
		return
	save_queued = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		save_queued = false
		_save_garage_progress()
	)

func _car_price(index: int) -> int:
	if index == STARTER_INDEX:
		return 0
	var rank := maxi(0, garage_order.find(index) - 1)
	return CAR_PRICES[mini(rank, CAR_PRICES.size() - 1)]


func _parking_level_name(index: int) -> String:
	return tr(PARKING_NAMES[index]) if index < PARKING_NAMES.size() else tr("İleri park %d") % (index + 1)


func _parking_time_limit(index: int) -> int:
	return PARKING_LIMITS[index] if index < PARKING_LIMITS.size() else maxi(73, 100 - (index - 24))


func _session_gold_text() -> String:
	return tr("KAZANILAN  +%d ALTIN   ·   TOPLAM  %d") % [maxi(coins_n - session_start_gold, 0), coins_n]

func _buy_or_select_car() -> void:
	var index := preview_vehicle_index
	var price := 0 if index in owned_cars else _car_price(index)
	if coins_n < price:
		garage_pick.text = tr("%d ALTIN EKSİK") % (price - coins_n)
		return
	if not _install_vinish_car(index):
		garage_pick.text = tr("ARAÇ YÜKLENEMEDİ")
		return
	if index not in owned_cars:
		coins_n -= price
		owned_cars.append(index)
	vehicle_index = index
	garage_balance.text = tr("%d ALTIN") % coins_n
	_save_garage_progress()
	_browse_garage_car(index)


func _map_goals(area: int = -1) -> Array:
	if area < 0:
		area = map_index
	if area == MAP_NAMES.size():
		var parks := 0
		for id in range(PARK_LEVELS):
			parks += 1 if challenge_completed.has(id) else 0
		return [[tr("5 park bölümünü bitir"), parks, 5, 55], [tr("24 park bölümünü bitir"), parks, 24, 110],
			[tr("Drift Alanı hedefini tamamla"), int(challenge_completed.has(DRIFT_LEVEL)), 1, 25],
			[tr("Mesafe Alanı hedefini tamamla"), int(challenge_completed.has(DISTANCE_LEVEL)), 1, 25], [tr("50 park bölümünü bitir"), parks, 50, 1000]]
	var coin_target := 10 if area < 5 else 8
	if area == 7:
		return [[tr("1000 drift puanı kazan"), map_drift.get(area, 0), 1000, 32], [tr("8 pist altını topla"), map_coins.get(area, 0), 8, 25]]
	if area >= 5:
		return [[tr("Bir tur tamamla"), race_lap_records.get(area, 0), 1, 22],
			[tr("Üç tur tamamla"), race_lap_records.get(area, 0), 3, 45],
			[tr("%d pist altını topla") % coin_target, map_coins.get(area, 0), coin_target, 25], [tr("Birinciliği kazan"), race_win_records.get(area, 0), 1, 75]]
	var meters := [650, 500, 450, 600, 750]
	var drift := [900, 750, 600, 850, 1000]
	return [[tr("%d metre sür") % meters[area], map_meters.get(area, 0.0), meters[area], 20],
		[tr("%d drift puanı kazan") % drift[area], map_drift.get(area, 0.0), drift[area], 28],
		[tr("%d altın topla") % coin_target, map_coins.get(area, 0), coin_target, 24]]


func _goals_text() -> String:
	var lines := PackedStringArray([tr("BAŞARIMLAR")])
	var goals := _map_goals()
	for i in range(goals.size()):
		var task: Array = goals[i]
		var done := accomplishments.has(Vector2i(map_index, i))
		lines.append(tr("%s   +%d altın") % [task[0], task[3]])
		lines.append(tr("Tamamlandı") if done else "%d / %d" % [int(task[1]), task[2]])
	return "\n".join(lines)


func _check_goals(area: int = -1) -> void:
	if area < 0:
		area = map_index
	var goals := _map_goals(area)
	var earned := 0
	for i in range(goals.size()):
		var id := Vector2i(area, i)
		var task: Array = goals[i]
		if not accomplishments.has(id) and float(task[1]) >= float(task[2]):
			accomplishments[id] = true
			earned += int(task[3])
	if earned > 0:
		coins_n += earned
		_say(tr("BAŞARIM  +%d ALTIN") % earned)
		_queue_progress_save()

func _browse_garage_car(index: int) -> void:
	preview_vehicle_index = index
	_show_shop_preview(index)
	garage_car_name.text = tr(str(VEHICLE_NAMES[index]))
	garage_meter.value = float(TOP_SPEEDS[index]) * 3.6
	garage_speed.text = tr("AZAMİ HIZ   %d km/sa") % roundi(garage_meter.value)
	garage_pick.text = tr("SEÇİLİ") if index == vehicle_index else (tr("ARACI SEÇ") if index in owned_cars else tr("SATIN AL  ·  %d ALTIN") % _car_price(index))
	garage_pick.disabled = index == vehicle_index
	for slot in range(garage_strip.get_child_count()):
		var first := clampi(garage_order.find(index) - 2, 0, garage_order.size() - garage_strip.get_child_count())
		var car := garage_order[first + slot]
		var card := garage_strip.get_child(slot) as Button
		card.set_meta("car", car)
		card.text = "%s · %s" % [tr(VEHICLE_NAMES[car]), tr("Sahip olundu") if car in owned_cars else tr("%d ALTIN") % _car_price(car)]
		_style_shop_button(card, Color("#98591f") if car == index else Color("#322822"))
		card.add_theme_font_size_override("font_size", 15)
		card.icon = _garage_car_image(car)


func _garage_car_image(index: int) -> Texture2D:
	if garage_car_images.has(index):
		return garage_car_images[index]
	var model := _load_vinish_model(index)
	if model == null:
		return null
	var portrait := SubViewport.new()
	portrait.size = Vector2i(192, 85)
	portrait.transparent_bg = true
	portrait.own_world_3d = true
	portrait.render_target_update_mode = SubViewport.UPDATE_ONCE
	vehicle_shop.add_child(portrait)
	portrait.add_child(model)
	var camera := Camera3D.new()
	portrait.add_child(camera)
	var bounds := AABB()
	var first := true
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var target := bounds.get_center()
	var extent := maxf(bounds.size.length(), 0.25)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent * 0.86
	camera.position = target + Vector3(1.1, 0.65, 1.55) * extent
	camera.look_at(target)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-43, -31, 0)
	light.light_energy = 1.25
	portrait.add_child(light)
	var image := portrait.get_texture()
	garage_car_images[index] = image
	return image


func _open_garage_tab(tab: int, destination: int = -1) -> void:
	var was_open := vehicle_shop.visible
	garage_page.visible = tab == 0
	garage_maps.visible = tab in [1, 2]
	challenge_page.visible = tab == 3
	achievement_page.visible = tab == 4
	for i in range(garage_nav.size()):
		_style_shop_button(garage_nav[i], Color("#98591f") if tab == i else Color("#322822"))
	vehicle_shop.move_to_front()
	vehicle_shop.show()
	if tab == 0:
		garage_backdrop.texture = _load_ui_texture("res://GarageWorkshop.png")
		_browse_garage_car(preview_vehicle_index if was_open else vehicle_index)
	elif tab == 4:
		garage_backdrop.texture = _load_ui_texture("res://GarageWorkshop.png")
		_refresh_achievements()
	elif tab == 3:
		garage_backdrop.texture = _load_ui_texture("res://ParkingAcademy.png")
		if garage_backdrop.texture == null:
			garage_backdrop.texture = _garage_map_image(0)
		_refresh_challenges()
	else:
		var left_challenge := challenge_active >= 0
		_leave_challenge()
		race_catalog = tab == 2
		if destination >= 0 and (left_challenge or destination != map_index):
			_select_map(destination)
		elif left_challenge or map_index == REMOVED_MAP or (map_index >= 5) != race_catalog:
			_select_map(5 if race_catalog else 0)
		_refresh_garage_map()


func _build_achievement_catalog() -> void:
	achievement_page = Control.new()
	achievement_page.hide()
	_garage_place(vehicle_shop, achievement_page, Rect2(0, 0.14, 1, 0.84))
	var filters := _garage_panel(achievement_page, Rect2(0.025, 0.03, 0.265, 0.92))
	var rail := ScrollContainer.new()
	rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.scroll_deadzone = 10
	filters.add_child(rail)
	var maps := VBoxContainer.new()
	maps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_child(maps)
	for index in range(MAP_NAMES.size() + 1):
		var label := tr("Park ve Görev Alanı") if index == MAP_NAMES.size() else tr(str(MAP_NAMES[index]))
		var button := _garage_button(label)
		maps.add_child(button)
		achievement_buttons.append(button)
		button.visible = index != REMOVED_MAP
		button.pressed.connect(func() -> void:
			achievement_destination = index
			_refresh_achievements()
		)
	var panel := _garage_panel(achievement_page, Rect2(0.31, 0.03, 0.665, 0.92))
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.scroll_deadzone = 10
	panel.add_child(scroller)
	achievement_list = VBoxContainer.new()
	achievement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_list.add_theme_constant_override("separation", 10)
	scroller.add_child(achievement_list)
	var visit := _garage_button(tr("İLGİLİ BÖLÜMÜ AÇ"), true)
	panel.add_child(visit)
	visit.pressed.connect(func() -> void:
		var area := achievement_destination
		if area == MAP_NAMES.size():
			_open_garage_tab(3)
		else:
			_open_garage_tab(1 if area < 5 else 2, area)
	)


func _refresh_achievements() -> void:
	var area := achievement_destination
	for i in range(achievement_buttons.size()):
		_style_shop_button(achievement_buttons[i], Color("#98591f") if i == area else Color("#322822"))
	for child in achievement_list.get_children():
		achievement_list.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = tr("PARK VE GÖREV ALANI") if area == MAP_NAMES.size() else tr(str(MAP_NAMES[area]))
	heading.add_theme_font_override("font", race_heading_font)
	heading.add_theme_font_size_override("font_size", 28)
	achievement_list.add_child(heading)
	var goals := _map_goals(area)
	for i in range(goals.size()):
		var task: Array = goals[i]
		var done := accomplishments.has(Vector2i(area, i))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _race_metal_skin(Color("#325445") if done else Color("#483528"),
			Color("#77a779") if done else Color("#957250")))
		achievement_list.add_child(card)
		var row := VBoxContainer.new()
		card.add_child(row)
		var title := Label.new()
		title.text = tr("%s   ·   +%d altın") % [task[0], task[3]]
		title.add_theme_font_size_override("font_size", 21)
		row.add_child(title)
		var progress := Label.new()
		progress.text = tr("Tamamlandı · Ödül alındı") if done else "%d / %d" % [mini(int(task[1]), int(task[2])), task[2]]
		row.add_child(progress)

func _build_challenge_catalog() -> void:
	challenge_page = Control.new()
	_garage_place(vehicle_shop, challenge_page, Rect2(0, 0.14, 1, 0.84))
	var rail := _garage_panel(challenge_page, Rect2(0.025, 0.04, 0.20, 0.90))
	var route := Control.new()
	_garage_place(challenge_page, route, Rect2(0.24, 0.02, 0.47, 0.92))
	var points: Array[Vector2] = []
	for index in range(PARK_LEVELS):
		var row := floori(float(index) / 10.0)
		var column := index % 10 if row % 2 == 0 else 9 - index % 10
		points.append(Vector2(0.012 + column * 0.098, 0.82 - row * 0.19))
	route.draw.connect(func() -> void:
		var line := PackedVector2Array()
		for point in points:
			line.append(point * route.size + Vector2(20, 20))
		route.draw_polyline(line, Color("#342119"), 9, true)
		route.draw_polyline(line, Color("#f8ac4c"), 3, true)
	)
	for index in range(PARK_LEVELS + 2):
		var caption := str(index + 1) if index < PARK_LEVELS else (tr("DRIFT ALANI") if index == DRIFT_LEVEL else tr("MESAFE ALANI"))
		var button := _garage_button(caption)
		if index < PARK_LEVELS:
			_garage_place(route, button, Rect2(points[index], Vector2.ZERO))
			button.custom_minimum_size = Vector2(40, 40)
		else:
			rail.add_child(button)
			button.custom_minimum_size.y = 99
			var picture := TextureRect.new()
			picture.texture = _garage_map_image(5 if index == DRIFT_LEVEL else 0)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.clip_contents = true
			_garage_place(button, picture, Rect2(0.035, 0.06, 0.93, 0.58))
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			var tag := Label.new()
			tag.text = caption
			tag.add_theme_font_override("font", race_heading_font)
			tag.add_theme_font_size_override("font_size", 21)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_garage_place(button, tag, Rect2(0.06, 0.65, 0.88, 0.33))
			button.text = ""
		button.pressed.connect(func() -> void:
			challenge_selected = index
			_refresh_challenges()
		)
		challenge_buttons.append(button)
	var stats := _garage_panel(challenge_page, Rect2(0.73, 0.04, 0.245, 0.90))
	challenge_description = Label.new()
	challenge_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	challenge_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	challenge_description.add_theme_font_size_override("font_size", 21)
	stats.add_child(challenge_description)
	challenge_start = _garage_button(tr("BAŞLA"), true)
	challenge_start.pressed.connect(func() -> void: _start_challenge(challenge_selected))
	stats.add_child(challenge_start)


func _challenge_unlocked(index: int) -> bool:
	return index in [0, DRIFT_LEVEL, DISTANCE_LEVEL] or (index > 0 and index < PARK_LEVELS and challenge_completed.has(index - 1))


func _challenge_reward(index: int) -> int:
	return 250 if index >= PARK_LEVELS else 170 + index * 10


func _refresh_challenges() -> void:
	for i in range(challenge_buttons.size()):
		var button := challenge_buttons[i]
		button.disabled = not _challenge_unlocked(i)
		_style_shop_button(button, Color("#98591f") if i == challenge_selected else Color("#322822"))
		if i < PARK_LEVELS:
			button.text = "%d%s" % [i + 1, " ✓" if challenge_completed.has(i) else (" ·" if button.disabled else "")]
	var heading := "PARK %02d  /  %s" % [challenge_selected + 1, _parking_level_name(challenge_selected)] if challenge_selected < PARK_LEVELS else (tr("DRIFT ALANI") if challenge_selected == DRIFT_LEVEL else tr("MESAFE ALANI"))
	var task := tr("Duba yolundan geç. Aracın tamamı park çizgileri içinde bir saniye dursun.") if challenge_selected < PARK_LEVELS else (tr("Kapalı alanda 500 drift puanı kazan.") if challenge_selected == DRIFT_LEVEL else tr("Kapalı alanda toplam 500 metre sür."))
	challenge_description.text = "%s\n\n%s\n\n%s" % [heading, task,
		tr("Ödül  ·  %d altın") % (roundi(_challenge_reward(challenge_selected) * 0.42) if challenge_completed.has(challenge_selected) else _challenge_reward(challenge_selected))]
	if challenge_selected < PARK_LEVELS:
		challenge_description.text += tr("\n\nSüre  ·  %d sn\nTemas edersen elenirsin.") % _parking_time_limit(challenge_selected)
		if challenge_selected == 9:
			challenge_description.text += tr("\nÖnce rampadan karşıya atla.")
		elif _is_container_course(challenge_selected):
			challenge_description.text += tr("\nRampadan konteynere çık ve diğer uçtan in.")
	challenge_start.disabled = not _challenge_unlocked(challenge_selected)


func _leave_challenge() -> void:
	parking_goal_label = null
	parking_goal_material = null
	parking_contact_shadow = null
	challenge_active = -1
	challenge_won = false
	challenge_failed = false
	challenge_restart_after = 0.0
	if is_instance_valid(challenge_world):
		challenge_world.hide()
		challenge_world.queue_free()
		challenge_world = null


func _start_challenge(index: int) -> void:
	if not _challenge_unlocked(index):
		return
	_leave_challenge()
	challenge_active = index
	session_start_gold = coins_n
	challenge_selected = index
	_select_map(4, false)
	challenge_world = Node3D.new()
	add_child(challenge_world)
	challenge_cars.clear()
	parked_footprints.clear()
	var driver_key := "driver%d" % vehicle_index
	player_parking_hull = _parking_hull(car, vehicle_model, driver_key)
	if index < PARK_LEVELS:
		car_body.position.y = -float(parking_ground_cache.get(driver_key, 0.0))
	challenge_cones.clear()
	parking_yard_colliders.clear()
	parking_gates.clear()
	parking_gate_index = 0
	car_body.position.y = 0.0
	car_body.rotation = Vector3.ZERO
	challenge_bump_z = 100.0
	challenge_time = float(_parking_time_limit(index)) if index < PARK_LEVELS else 0.0
	challenge_air_speed = 0.0
	challenge_jumped = false
	challenge_meters = 0.0
	challenge_points = 0.0
	challenge_hold = 0.0
	pos = Vector3(0, 0, 17)
	yaw = PI
	vel = Vector3.ZERO
	vy = 0.0
	grounded = true
	car_n = Vector3.UP
	wheel_angle = 0.0
	car_body.rotation = Vector3.ZERO
	_clear_touch_controls()
	_build_challenge_lot(index)
	_draw_parking_cones()
	if index < PARK_LEVELS:
		_make_parking_contact_shadow()
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	cam.position = pos + _camera_offset()
	cam.look_at(pos + Vector3.UP * 0.7)
	vehicle_shop.hide()
	main_menu.hide()
	_say(tr("HEDEF CEBE PARK ET") if index < PARK_LEVELS else (tr("500 DRIFT PUANI") if index == DRIFT_LEVEL else tr("500 METRE SÜR")))


func _lot_box(size: Vector3, at: Vector3, color: Color, turn: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_inst(challenge_world, mesh, _std(color, 0.0, 0.87), at, Vector3(0, turn, 0))


func _prepare_parking_art() -> void:
	for name in ["shipping-container", "concrete-barrier", "oil-drum"]:
		var asset := _load_3d_asset("res://parking-%s.glb" % name)
		if asset != null:
			parking_yard_assets[name] = asset
			add_child(asset)
			asset.hide()
	parking_canopy = _load_3d_asset("res://solar-charging-canopy.glb")
	if parking_canopy != null:
		add_child(parking_canopy)
		parking_canopy.hide()
	var bay := _load_3d_asset("res://charging-bay.glb")
	if bay != null:
		for child in bay.find_children("*", "MeshInstance3D", true, false):
			var source := (child as MeshInstance3D).mesh
			for surface in range(source.get_surface_count()):
				var material := source.surface_get_material(surface)
				if material == null or material.resource_name not in ["Paint_Line", "Paint_Bay"]:
					continue
				if parking_bay_mesh == null:
					parking_bay_mesh = ArrayMesh.new()
				var index := parking_bay_mesh.get_surface_count()
				parking_bay_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface))
				parking_bay_mesh.surface_set_name(index, material.resource_name)
		bay.free()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
varying vec2 world_floor;
void vertex() {
	world_floor = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 tile = world_floor / 1.75;
	vec2 cell = floor(tile);
	vec2 p = fract(tile);
	float id = fract(sin(dot(cell, vec2(45.13, 93.17))) * 43758.5453);
	float seam = min(min(p.x, 1.0-p.x), min(p.y, 1.0-p.y));
	float grout = 1.0 - smoothstep(0.006, 0.017, seam);
	float grain = sin(p.x * 22.0 + 3.0 * sin(p.y * 13.0 + id * 6.0));
	float sweep = sin((p.x - p.y * 0.72) * 17.0 + grain * 0.88 + id * 13.0);
	float veins = smoothstep(0.86, 0.999, sweep) * (0.20 + 0.8 * id);
	vec3 stone = mix(vec3(0.29, 0.33, 0.35), vec3(0.36, 0.40, 0.42), id);
	ALBEDO = mix(stone - veins * 0.042, vec3(0.16, 0.19, 0.21), grout * 0.78);
	ROUGHNESS = 0.75 + grout * 0.19;
	METALLIC = 0.0;
}
"""
	parking_floor_material = ShaderMaterial.new()
	parking_floor_material.shader = shader


func _parking_floor(size: Vector2, z: float) -> void:
	var ground := PlaneMesh.new()
	ground.size = size
	_inst(challenge_world, ground, parking_floor_material, Vector3(0, 0, z))


func _add_parking_canopies(lot: float) -> void:
	if parking_canopy == null:
		return
	for i in range(-3, 4):
		var canopy := parking_canopy.duplicate(0) as Node3D
		challenge_world.add_child(canopy)
		canopy.position = Vector3(i * 6.4, -0.24, -lot - 4.5)
		canopy.scale = Vector3.ONE * 1.65
		canopy.show()


func _build_parking_goal(frame: Basis) -> void:
	parking_goal_material = _std(Color("#566e5c"), 0.0, 0.82)
	var boundary := _std(Color("#f2f5eb"), 0.0, 0.9)
	if parking_bay_mesh != null:
		var paint_depth := challenge_half.y / 2.925
		var painted := _inst(challenge_world, parking_bay_mesh, null,
			challenge_target + frame.z * 0.325 * paint_depth + Vector3.UP * 0.009, Vector3(0, challenge_angle, 0))
		painted.scale = Vector3(challenge_half.x / 1.30, 0.13, paint_depth)
		for surface in range(parking_bay_mesh.get_surface_count()):
			var material := parking_goal_material if parking_bay_mesh.surface_get_name(surface) == "Paint_Bay" else boundary
			painted.set_surface_override_material(surface, material)
	else:
		var pad := PlaneMesh.new()
		pad.size = challenge_half * 2.0
		_inst(challenge_world, pad, parking_goal_material, challenge_target + Vector3.UP * 0.012, Vector3(0, challenge_angle, 0))
	for side: float in [-1, 1]:
		_lot_box(Vector3(0.10, 0.012, challenge_half.y * 2.0),
			challenge_target + frame.x * side * challenge_half.x + Vector3.UP * 0.016, Color("#f1f4ed"), challenge_angle)
	var entry := 1.0
	var tile_width := challenge_half.x * 2.0 / 12.0
	var checker := BoxMesh.new()
	checker.size = Vector3(tile_width, 0.010, 0.22)
	var dark := _std(Color("#202828"))
	for column in range(12):
		for row in range(2):
			var p := challenge_target + frame.x * (tile_width * (column + 0.5) - challenge_half.x)
			p += frame.z * (challenge_half.y * entry + (row - 0.5) * 0.22) + Vector3.UP * 0.021
			_inst(challenge_world, checker, boundary if (column + row) % 2 == 0 else dark, p, Vector3(0, challenge_angle, 0))
	parking_goal_label = Label3D.new()
	parking_goal_label.text = "P"
	parking_goal_label.font = race_heading_font
	parking_goal_label.font_size = 112
	parking_goal_label.outline_size = 5
	parking_goal_label.pixel_size = 0.014
	parking_goal_label.no_depth_test = false
	challenge_world.add_child(parking_goal_label)
	parking_goal_label.position = challenge_target + Vector3.UP * 0.048
	parking_goal_label.rotation = Vector3(-PI * 0.5, challenge_angle, 0.0)


func _update_goal_feedback(ready: bool) -> void:
	if parking_goal_material != null:
		parking_goal_material.albedo_color = Color("#759881") if ready else Color("#566e5c")

func _build_challenge_lot(index: int) -> void:
	var lot := 27.0 if index < PARK_LEVELS else 32.0
	_lot_box(Vector3(260, 0.18, 260), Vector3(0, -0.35, 0), Color("#8f7459"))
	if index == 9:
		_parking_floor(Vector2(lot * 2, lot - 3.0), (lot + 3.0) * 0.5)
		_parking_floor(Vector2(lot * 2, lot + 0.4), (0.4 - lot) * 0.5)
		_lot_box(Vector3(lot * 2, 0.10, 2.6), Vector3(0, -0.29, 1.7), Color("#1f201f"))
	else:
		_parking_floor(Vector2.ONE * lot * 2.0, 0.0)
	for side: float in [-1, 1]:
		_lot_box(Vector3(lot * 2, 1.0, 0.30), Vector3(0, 0.5, side * lot), Color("#a67946"))
		_lot_box(Vector3(0.30, 1.0, lot * 2), Vector3(side * lot, 0.5, 0), Color("#a67946"))
	for edge in range(-5, 6):
		var stripe := Color("#d29d31") if edge % 2 == 0 else Color("#2d3639")
		for side: float in [-1, 1]:
			_lot_box(Vector3(4.98, 0.24, 0.38), Vector3(edge * 4.9, 0.25, side * lot), stripe)
			_lot_box(Vector3(0.38, 0.24, 4.98), Vector3(side * lot, 0.25, edge * 4.9), stripe)
		for side: float in [-1, 1]:
			_lot_box(Vector3(0.36, 1.27, 0.36), Vector3(edge * 5.0, 0.63, side * lot), Color("#594536"))
			_lot_box(Vector3(0.36, 1.27, 0.36), Vector3(side * lot, 0.63, edge * 5.0), Color("#594536"))
	_add_parking_canopies(lot)
	if index >= PARK_LEVELS:
		for side: float in [-1, 1]:
			for tick in range(-4, 5):
				_lot_box(Vector3(0.2, 0.015, 2.2), Vector3(side * 21.0, 0.012, tick * 5.0), Color("#dab673"))
		return
	var player_size := _footprint_extent(player_parking_hull)
	var offset := [-4.4, 1.5, 4.4, -2.5, 3.0, -3.0]
	pos = Vector3(offset[index % offset.size()], 0, minf(22.9, 25.3 - player_size.y))
	challenge_lane_x = pos.x
	challenge_angle = [-0.20, 0.0, 0.20][index % 3] if index in [7, 14, 17, 20, 22] else 0.0
	var goal_x := float(offset[posmod(2 - index, offset.size())])
	if index in [0, 9, 10]:
		goal_x = pos.x
	challenge_target = Vector3(goal_x, 0, -14.8 - float(index % 4) * 0.75)
	challenge_half = player_size + Vector2(0.48, 0.82)
	var frame := Basis(Vector3.UP, challenge_angle)
	_build_parking_goal(frame)
	for side: float in [-1, 1]:
		var bay := challenge_target + frame.x * side * (challenge_half.x + 1.66)
		for border: float in [-1.0, 1.0]:
			_lot_box(Vector3(0.055, 0.012, 5.1), bay + frame.x * border * 1.37 + Vector3.UP * 0.013,
				Color("#e1e7e3"), challenge_angle)
		_add_parked_car(bay, challenge_angle, [20, 21, 22, 23, 24, 25][(index + (0 if side < 0.0 else 2)) % 6])

	_add_parking_yard_detail(index)
	if _is_container_course(index):
		_build_container_deck()
	if index in [4, 6, 8, 17, 21, 28, 33, 38, 44, 49]:
		challenge_bump_z = 7.0
		var bump_x := _parking_route_x(index, _parking_route_progress(7.0))
		for strip in range(10):
			var stripe_z := (strip - 4.5) * 0.15
			var rise := 0.23 * cos(stripe_z / 0.75 * PI * 0.5)
			_lot_box(Vector3(5.2, rise, 0.155), Vector3(bump_x, rise * 0.5, challenge_bump_z + stripe_z),
				Color("#deb55e") if strip % 2 == 0 else Color("#2f2d2b"))
	if index == 9 and race_ramp_mesh != null:
		var ramp := _inst(challenge_world, race_ramp_mesh, null, Vector3(challenge_lane_x, 0, 6.0))
		ramp.scale.x = 0.68

	var entrance_half := player_size.x + lerpf(1.45, 1.22, float(index) / (PARK_LEVELS - 1))
	var entry_rows := ceili((pos.z + 1.0 - 19.0) / 0.92)
	for row in range(1, entry_rows + 1):
		var z := lerpf(19.0, pos.z + 1.0, float(row) / entry_rows)
		for side: float in [-1.0, 1.0]:
			_add_parking_cone(Vector3(challenge_lane_x + side * entrance_half, 0, z))
	var exit_z := _parking_route_exit()
	var rows := ceili((19.0 - exit_z) / 0.92) + 1
	for row in range(rows):
		var progress := float(row) / (rows - 1)
		var z := lerpf(19.0, exit_z, progress)
		if index == 9 and z < 3.0 and z > 0.4:
			continue
		var center := _parking_route_x(index, progress)
		var half := entrance_half
		half += 0.24 * smoothstep(0.82, 1.0, progress)
		var height := _parking_approach_height(index, center, z)
		for side: float in [-1.0, 1.0]:
			_add_parking_cone(Vector3(center + side * half, height, z))
		if row % 3 == 0 or row == rows - 1:
			parking_gates.append(Vector3(center, half, z))
			_lot_box(Vector3(half * 1.15, 0.011, 0.055), Vector3(center, height + 0.009, z), Color("#c0c9c5"))


func _parking_route_exit() -> float:
	return challenge_target.z + maxf(4.3, challenge_half.y + 1.2)


func _parking_route_progress(z: float) -> float:
	return clampf(inverse_lerp(19.0, _parking_route_exit(), z), 0.0, 1.0)


func _parking_route_x(index: int, progress: float) -> float:
	var direct := lerpf(challenge_lane_x, challenge_target.x, smoothstep(0.08, 0.86, progress))
	if index in [0, 9, 10]:
		return direct
	var envelope := smoothstep(0.02, 0.18, progress) * (1.0 - smoothstep(0.77, 0.99, progress))
	var wave := sin(progress * (PI if index < 5 else (TAU if index < 30 else TAU * 1.5)))
	var amplitude := 1.05 if index < 5 else (2.65 if index % 3 == 0 else 1.7)
	if index >= 30:
		amplitude = 1.65 + float(index % 4) * 0.12
	return direct + wave * amplitude * envelope * (1.0 if index % 2 == 0 else -1.0)


func _parking_approach_height(index: int, x: float, z: float) -> float:
	if _is_container_course(index):
		return _parking_container_height(z)
	if index == 9 and z >= 3.0 and z <= 9.0:
		return 0.135 + 1.4 * (9.0 - z) / 6.0
	var offset := absf(z - challenge_bump_z)
	if offset < 0.75 and absf(x - _parking_route_x(index, _parking_route_progress(challenge_bump_z))) <= 2.6:
		return 0.23 * cos(offset / 0.75 * PI * 0.5)
	return 0.0

func _is_container_course(index: int) -> bool:
	return index in [15, 20, 23, 27, 32, 36, 41, 46, 48]


func _parking_container_height(z: float) -> float:
	if z > 13.0 or z < -3.0:
		return 0.0
	if z > 8.0:
		return (13.0 - z) * 0.25
	if z < 2.0:
		return (z + 3.0) * 0.25
	return 1.25


func _build_container_deck() -> void:
	var deck_width := 17.0
	var deck_x := (challenge_lane_x + challenge_target.x) * 0.5
	_lot_box(Vector3(deck_width, 1.25, 6.0), Vector3(deck_x, 0.625, 5.0), Color("#405857"))
	for side: float in [-1, 1]:
		var z := 10.5 if side < 0.0 else -0.5
		var ramp := BoxMesh.new()
		ramp.size = Vector3(deck_width, 0.18, Vector2(5.0, 1.25).length())
		_inst(challenge_world, ramp, _std(Color("#555c5e"), 0.0, 0.87),
			Vector3(deck_x, 0.538, z), Vector3(-side * atan(0.25), 0, 0))
		for stripe in range(8):
			var at := Vector3(deck_x + (stripe - 3.5) * 2.0, 0.015, 13.12 if side < 0.0 else -3.12)
			_lot_box(Vector3(2.0, 0.02, 0.20), at, Color("#b99242") if stripe % 2 == 0 else Color("#343636"))
		for rib in range(8):
			_lot_box(Vector3(0.11, 1.18, 0.08),
				Vector3(deck_x + side * (deck_width * 0.5 + 0.05), 0.59, 2.4 + rib * 0.74), Color("#58706e"))


func _add_parking_yard_detail(index: int) -> void:
	for side: float in [-1.0, 1.0]:
		_place_parking_yard_asset("shipping-container", Vector3(side * 14.6, 0, -3.5 + float(index % 4) * 2.5), PI * 0.5)
		for z: float in [17.0, 10.5, -7.5]:
			_place_parking_yard_asset("concrete-barrier", Vector3(side * 11.4, 0, z), PI * 0.5)
		for z: float in [13.6, 14.45, -9.8]:
			_place_parking_yard_asset("oil-drum", Vector3(side * 12.1, 0, z), 0)
		_lot_box(Vector3(0.095, 0.012, 37.0), Vector3(side * 11.0, 0.008, 1.3), Color("#b2a776"))

func _place_parking_yard_asset(name: String, center: Vector3, angle: float) -> void:
	if not parking_yard_assets.has(name):
		return
	var prop := (parking_yard_assets[name] as Node3D).duplicate(0) as Node3D
	challenge_world.add_child(prop)
	prop.transform = Transform3D(Basis(Vector3.UP, angle), center)
	prop.show()
	var hull := _parking_hull(prop, prop, "yard-" + name)
	parking_yard_colliders.append(_parking_placed_hull(hull, prop.transform))
	if mobile_low_detail:
		for child in prop.find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _add_parked_car(at: Vector3, angle: float, index: int) -> void:
	challenge_cars.append(Transform3D(Basis(Vector3.UP, angle), at))
	var parked := _load_vinish_model(index)
	if parked != null:
		challenge_world.add_child(parked)
		parked.transform = challenge_cars.back()
		var hull := _parking_hull(parked, parked, "parked%d" % index)
		parked_footprints.append(_parking_placed_hull(hull, parked.transform))
	else:
		_lot_box(Vector3(1.9, 1.4, 4.2), at + Vector3.UP * 0.7, Color("#825947"), angle)
		parked_footprints.append(_parking_placed_hull(_fallback_footprint(), challenge_cars.back()))


func _add_parking_cone(at: Vector3) -> void:
	challenge_cones.append(at)


func _draw_parking_cones() -> void:
	if challenge_cones.is_empty():
		return
	if parking_cone_model == null:
		for at in challenge_cones:
			_inst(challenge_world, _cyl(0.04, 0.19, 0.68, 12), _std(Color("#ec702c")), at + Vector3.UP * 0.34)
		return
	var to_local := parking_cone_model.global_transform.affine_inverse()
	for child in parking_cone_model.find_children("*", "MeshInstance3D", true, false):
		var source := child as MeshInstance3D
		if source.mesh == null:
			continue
		var local := to_local * source.global_transform
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = source.mesh
		batch.instance_count = challenge_cones.size()
		for i in range(challenge_cones.size()):
			batch.set_instance_transform(i, Transform3D(Basis.IDENTITY, challenge_cones[i]) * local)
		var mesh := MultiMeshInstance3D.new()
		mesh.multimesh = batch
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		challenge_world.add_child(mesh)


func _make_parking_contact_shadow() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = vec3(0.07, 0.075, 0.08);
	ALPHA = 0.27 * (1.0 - smoothstep(0.29, 0.94, radius));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var plane := PlaneMesh.new()
	plane.size = (_footprint_extent(player_parking_hull) + Vector2(0.32, 0.33)) * 2.0
	parking_contact_shadow = _inst(challenge_world, plane, material, pos + Vector3.UP * 0.026, Vector3(0, yaw, 0))
	parking_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _advance_parking_gates(before: Vector3) -> void:
	while parking_gate_index < parking_gates.size():
		var gate := parking_gates[parking_gate_index]
		if before.z < gate.z or pos.z > gate.z or before.z <= pos.z:
			return
		var t := (before.z - gate.z) / (before.z - pos.z)
		var through := lerpf(before.x, pos.x, t)
		if absf(through - gate.x) >= gate.y - 0.16:
			return
		parking_gate_index += 1

func _fail_parking(message: String) -> void:
	challenge_failed = true
	challenge_restart_after = 2.0
	vel = Vector3.ZERO
	_say(message)

func _fallback_footprint() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.96, -1.98), Vector2(0.96, -1.98),
		Vector2(0.96, 1.98), Vector2(-0.96, 1.98)])


func _parking_hull(reference: Node3D, model: Node3D, key: String) -> PackedVector2Array:
	if parking_hull_cache.has(key):
		return parking_hull_cache[key]
	if not is_instance_valid(model):
		return _fallback_footprint()
	var to_local := reference.global_transform.affine_inverse()
	var points := PackedVector2Array()
	var lowest := INF
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var basis := to_local * instance.global_transform
		for surface in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var outline := PackedVector2Array()
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var point := basis * vertex
				lowest = minf(lowest, point.y)
				outline.append(Vector2(point.x, point.z))
			points.append_array(Geometry2D.convex_hull(outline))
	if points.size() < 3:
		return _fallback_footprint()
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 3 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	parking_hull_cache[key] = hull
	parking_ground_cache[key] = clampf(lowest, -0.30, 0.30)
	return hull


func _footprint_extent(points: PackedVector2Array) -> Vector2:
	var span := Vector2.ZERO
	for point in points:
		span = span.max(point.abs())
	return span


func _parking_placed_hull(hull: PackedVector2Array, pose: Transform3D) -> PackedVector2Array:
	var placed := PackedVector2Array()
	for point in hull:
		var v := pose * Vector3(point.x, 0, point.y)
		placed.append(Vector2(v.x, v.z))
	return placed


func _parking_fits(frame: Basis) -> bool:
	var transform_to_bay := Transform3D(frame, challenge_target).affine_inverse() * Transform3D(Basis(Vector3.UP, yaw), pos)
	for point in _parking_placed_hull(player_parking_hull, transform_to_bay):
		if absf(point.x) > challenge_half.x - 0.04 or absf(point.y) > challenge_half.y - 0.04:
			return false
	return true


func _parking_contact() -> bool:
	var outline := _parking_placed_hull(player_parking_hull, Transform3D(Basis(Vector3.UP, yaw), pos))
	for point in outline:
		if maxf(absf(point.x), absf(point.y)) >= 26.83:
			return true
	for cone in challenge_cones:
		if absf(pos.y - cone.y) > 0.65 or pos.distance_squared_to(cone) > 32.0:
			continue
		var c := Vector2(cone.x, cone.z)
		var base := PackedVector2Array([c + Vector2(-0.19, -0.19), c + Vector2(0.19, -0.19),
			c + Vector2(0.19, 0.19), c + Vector2(-0.19, 0.19)])
		if not Geometry2D.intersect_polygons(outline, base).is_empty():
			return true
	if pos.y > 1.35:
		return false
	for obstacle in parking_yard_colliders:
		if not Geometry2D.intersect_polygons(outline, obstacle).is_empty():
			return true
	for i in range(challenge_cars.size()):
		if pos.distance_squared_to(challenge_cars[i].origin) <= 45.0:
			if not Geometry2D.intersect_polygons(outline, parked_footprints[i]).is_empty():
				return true
	return false

func _update_challenge(dt: float) -> void:
	if challenge_failed:
		challenge_restart_after -= dt
		if challenge_restart_after <= 0.0:
			_start_challenge(challenge_active)
		return
	if challenge_won:
		return
	var before := pos
	var before_yaw := yaw
	if challenge_active < PARK_LEVELS:
		challenge_time = maxf(0.0, challenge_time - dt)
		if challenge_time <= 0.0:
			_fail_parking(tr("SÜRE DOLDU"))
			return
		_update_parking_car(dt)
		_update_parking_surface(before, dt)
		if _parking_contact() and not challenge_failed:
			pos = before
			yaw = before_yaw
			vel = Vector3.ZERO
			_fail_parking(tr("TEMAS  ·  ELENDİN"))
		car.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
		var frame := Basis(Vector3.UP, challenge_angle)
		if not challenge_failed:
			_advance_parking_gates(before)
		if is_instance_valid(parking_contact_shadow):
			parking_contact_shadow.visible = pos.y < 0.34
			parking_contact_shadow.position = Vector3(pos.x, 0.026, pos.z)
			parking_contact_shadow.rotation.y = yaw
		var fit := _parking_fits(frame) and parking_gate_index == parking_gates.size()
		challenge_hold = challenge_hold + dt if fit and vel.length() < 0.45 else 0.0
		_update_goal_feedback(fit and not challenge_failed)
		if challenge_hold >= 1.0 and not challenge_failed and (challenge_active != 9 or challenge_jumped):
			_finish_challenge()
	else:
		var prior_score := drift_score
		_update_car(dt)
		if absf(pos.x) > 29.0:
			if signf(pos.x) == signf(vel.x):
				vel.x *= -0.24
			pos.x = clampf(pos.x, -29.0, 29.0)
		if absf(pos.z) > 29.0:
			if signf(pos.z) == signf(vel.z):
				vel.z *= -0.24
			pos.z = clampf(pos.z, -29.0, 29.0)
		car.position = pos
		challenge_meters += pos.distance_to(before)
		challenge_points += maxf(0.0, drift_score - prior_score)
		if (challenge_active == DRIFT_LEVEL and challenge_points >= 500.0) or (challenge_active == DISTANCE_LEVEL and challenge_meters >= 500.0):
			_finish_challenge()


func _update_parking_surface(before: Vector3, dt: float) -> void:
	if _is_container_course(challenge_active):
		pos.y = _parking_container_height(pos.z) if absf(pos.x - (challenge_lane_x + challenge_target.x) * 0.5) < 8.5 else 0.0
	elif challenge_active == 9:
		var on_ramp := absf(pos.x - challenge_lane_x) < 2.35 and pos.z >= 3.0 and pos.z <= 9.0
		if on_ramp:
			pos.y = 0.135 + 1.40 * (9.0 - pos.z) / 6.0
		elif before.z >= 3.0 and pos.z < 3.0 and before.y > 1.20 and vel.z < -4.1:
			challenge_air_speed = 2.35
			challenge_jumped = true
			pos.y = before.y
		elif challenge_air_speed != 0.0 or before.y > 0.34:
			challenge_air_speed -= 10.8 * dt
			pos.y = maxf(0.0, before.y + challenge_air_speed * dt)
			if pos.y <= 0.0:
				challenge_air_speed = 0.0
		if pos.z < 3.0 and pos.z > 0.4 and pos.y < 0.25:
			_fail_parking(tr("BOŞLUĞA DÜŞTÜN"))
	else:
		pos.y = _parking_approach_height(challenge_active, pos.x, pos.z)

func _update_parking_car(dt: float) -> void:
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	var speed := vel.dot(forward)
	var gas := gas_finger >= 0 or Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var brake := brake_finger >= 0 or Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var turn := float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	if wheel_finger >= 0:
		turn = wheel_input
	steer = move_toward(steer, turn, dt * 10)
	var maneuver_speed := clampf(float(TOP_SPEEDS[vehicle_index]) * 0.235, 5.15, 6.4)
	var requested := maneuver_speed if gas else ((0.0 if speed > 0.15 else -maneuver_speed * 0.55) if brake else 0.0)
	speed = move_toward(speed, requested, dt * (10.0 if brake else (4.1 if gas else 5.8)))
	yaw -= steer * speed * 0.39 * dt
	vel = Vector3(sin(yaw), 0, cos(yaw)) * speed
	pos += vel * dt
	wheel_angle += speed * dt / 0.36
	for wheel: Node3D in wheel_spins:
		wheel.rotation.x = wheel_angle
	for pivot: Node3D in wheel_pivots:
		pivot.rotation.y = -steer * 0.35


func _finish_challenge() -> void:
	if challenge_won:
		return
	challenge_won = true
	vel = Vector3.ZERO
	var first_clear := not challenge_completed.has(challenge_active)
	challenge_completed[challenge_active] = true
	var reward := _challenge_reward(challenge_active)
	coins_n += reward if first_clear else roundi(reward * 0.42)
	_check_goals(MAP_NAMES.size())
	_save_garage_progress()

func _challenge_status() -> String:
	if challenge_failed:
		return tr("%s  ·  %d sn") % [tr("SÜRE DOLDU") if challenge_time <= 0.0 else tr("ELENDİN"), maxi(1, ceili(challenge_restart_after))]
	if challenge_won:
		return tr("GÖREV TAMAM")
	if challenge_active < PARK_LEVELS:
		return tr("PARK %02d  /  %s    %d sn\n%s") % [challenge_active + 1, _parking_level_name(challenge_active), ceili(challenge_time),
			tr("DUR   %.1f / 1.0 sn") % challenge_hold if challenge_hold > 0.0 else (tr("DUBA GEÇİDİ  %d/%d") % [parking_gate_index, parking_gates.size()] if parking_gate_index < parking_gates.size() else tr("CEBE PARK ET"))]
	if challenge_active == DRIFT_LEVEL:
		return "DRIFT  %d / 500" % int(challenge_points)
	return tr("MESAFE  %d / 500 m") % int(challenge_meters)


func _build_map_catalog(page: Control) -> void:
	garage_map_atlas = _load_ui_texture("res://GarageMaps.png")
	var rail := ScrollContainer.new()
	rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.scroll_deadzone = 10
	_garage_place(page, rail, Rect2(0.025, 0.015, 0.22, 0.94))
	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 8)
	rail.add_child(cards)
	for index in range(MAP_NAMES.size()):
		var card := _garage_button(tr(str(MAP_NAMES[index])))
		card.custom_minimum_size.y = 82
		card.expand_icon = true
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var art := TextureRect.new()
		art.texture = _garage_map_image(5 if index == 7 else index)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.clip_contents = true
		_garage_place(card, art, Rect2(0.025, 0.07, 0.95, 0.86))
		var caption := Label.new()
		caption.text = card.text
		caption.add_theme_font_override("font", race_heading_font)
		caption.add_theme_font_size_override("font_size", 20)
		caption.add_theme_constant_override("outline_size", 10)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_garage_place(card, caption, Rect2(0.065, 0.57, 0.91, 0.34))
		card.tooltip_text = card.text
		card.text = ""
		cards.add_child(card)
		garage_map_buttons.append(card)
		card.pressed.connect(func() -> void:
			if map_index != index:
				_select_map(index)
			_refresh_garage_map()
		)
	var stats := _garage_panel(page, Rect2(0.72, 0.025, 0.26, 0.88))
	var preview := Control.new()
	preview.custom_minimum_size.y = 124
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats.add_child(preview)
	preview.draw.connect(func() -> void: _draw_route_preview(preview))
	garage_map_preview = preview
	garage_goals = Label.new()
	garage_goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_child(garage_goals)
	garage_night = CheckButton.new()
	garage_night.text = tr("Gece sürüşü")
	stats.add_child(garage_night)
	garage_night.toggled.connect(func(enabled: bool) -> void:
		desert_night = enabled
		_apply_map_lighting()
		_refresh_garage_map()
	)
	var start := _garage_button(tr("BAŞLA"), true)
	stats.add_child(start)
	start.pressed.connect(func() -> void:
		session_start_gold = coins_n
		if map_index >= 5:
			_respawn(0.0, -1.0)
		vehicle_shop.hide()
		main_menu.hide()
	)


func _garage_map_image(index: int) -> Texture2D:
	if garage_map_atlas == null:
		return null
	var thumb := AtlasTexture.new()
	thumb.atlas = garage_map_atlas
	var tile := garage_map_atlas.get_size() / Vector2(2, 4)
	thumb.region = Rect2(Vector2(index % 2, floori(index / 2.0)) * tile, tile)
	thumb.filter_clip = true
	return thumb


func _refresh_garage_map() -> void:
	garage_backdrop.texture = _garage_map_image(7 if map_index == 0 and desert_night else (5 if map_index == 7 else map_index))
	for index in range(garage_map_buttons.size()):
		garage_map_buttons[index].visible = index != REMOVED_MAP and (index >= 5) == race_catalog
		_style_shop_button(garage_map_buttons[index], Color("#98591f") if index == map_index else Color("#322822"))
	garage_night.visible = map_index == 0
	garage_night.set_pressed_no_signal(desert_night)
	garage_map_preview.queue_redraw()
	garage_goals.text = _goals_text()


func _draw_route_preview(preview: Control) -> void:
	var size := preview.size
	preview.draw_rect(Rect2(Vector2.ZERO, size), Color("#211913"))
	var title := tr(MAP_NAMES[map_index])
	preview.draw_string(race_heading_font, Vector2(20, 42), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#fff0d9"))
	var mode := tr("Kesintisiz drift") if map_index == 7 else (tr("Yapay zekâ rakipleri") if map_index >= 5 else tr("Serbest sürüş"))
	preview.draw_string(race_body_font, Vector2(20, 70), mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffbc71"))
	if map_index < 5:
		return
	var route := PackedVector2Array()
	var axes: Vector2 = TRACK_AXES[map_index - 5]
	for i in range(101):
		var point := _track_point(TAU * i / 100.0)
		route.append(Vector2(size.x * 0.50 + point.x * size.x * 0.34 / axes.x,
			size.y * 0.68 + point.z * size.y * 0.19 / axes.y))
	preview.draw_polyline(route, Color("#63472f"), 9, true)
	preview.draw_polyline(route, Color("#ffbf66"), 2, true)
	preview.draw_circle(route[0], 5, Color("#fff4d9"), true, -1, true)


func _load_ui_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		return ResourceLoader.load(path, "Texture2D") as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null


func _load_race_font(path: String) -> Font:
	if ResourceLoader.exists(path, "Font"):
		return load(path) as Font
	var font := FontFile.new()
	if FileAccess.file_exists(path) and font.load_dynamic_font(path) == OK:
		return font
	return ThemeDB.fallback_font

func _race_metal_skin(tint: Color, edge: Color) -> StyleBoxTexture:
	var key := Vector2i(tint.to_rgba32(), edge.to_rgba32())
	if race_skins.has(key):
		return race_skins[key]
	const SIDE := 48
	var surface := Image.create_empty(SIDE, SIDE, false, Image.FORMAT_RGBA8)
	for y in range(SIDE):
		for x in range(SIDE):
			var bevel := mini(mini(x, SIDE - 1 - x), mini(y, SIDE - 1 - y))
			var cut := mini(x + y, 2 * (SIDE - 1) - x - y) - 10
			var inset := mini(bevel, cut)
			if inset < 0:
				continue
			var brushed := float((x * 17 + y * 29) % 13) / 520.0
			var matte := tint.lerp(Color.BLACK, float(y) / SIDE * 0.42)
			var border := edge if y < SIDE / 2 else edge.darkened(0.26)
			surface.set_pixel(x, y, border if inset <= 1 else matte.lightened(brushed))
	var skin := StyleBoxTexture.new()
	skin.texture = ImageTexture.create_from_image(surface)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 13)
		skin.set_content_margin(side, 13 if side in [SIDE_LEFT, SIDE_RIGHT] else 7)
	race_skins[key] = skin
	return skin


func _style_shop_button(button: Button, tint: Color) -> void:
	button.add_theme_font_override("font", race_heading_font)
	button.add_theme_font_size_override("font_size", 20)
	var amber := tint.r > 0.5
	var base := Color("#8b4c16") if amber else tint.darkened(0.28)
	var border := Color("#f6af56") if amber else Color("#88725e")
	button.add_theme_stylebox_override("normal", _race_metal_skin(base, border))
	button.add_theme_stylebox_override("hover", _race_metal_skin(base.lightened(0.17), Color("#ffca84")))
	button.add_theme_stylebox_override("pressed", _race_metal_skin(Color("#a76324"), Color("#ffe0a2")))
	button.add_theme_stylebox_override("hover_pressed", _race_metal_skin(Color("#a76324"), Color("#ffe0a2")))
	button.add_theme_color_override("font_color", Color("#fff1df"))
	button.add_theme_color_override("font_pressed_color", Color("#fff8e9"))

func _select_map(index: int, build_world: bool = true) -> void:
	map_index = index
	snow_fall.emitting = index == 1
	sand_burst.restart()
	sand_burst.emitting = false
	sand_burst_cooldown = 0.0
	for plume in desert_plumes:
		plume.emitting = false
		plume.restart()
		plume.emitting = false
	var grounds := ["MeshyDesertSand2K.jpg", "TevySnow.png", "PolyMud.jpg", "TevyMeadow.png", "TevyForest.png", "TevyMeadow.png", "TevyMeadow.png", "TevyMeadow.png"]
	var roads := ["Asphalt", "SnowRoad", "Asphalt", "ForestRoad", "Asphalt", "Asphalt", "Asphalt", "Asphalt"]
	_apply_map_lighting()
	for i in range(2):
		var path: String = "res://" + (grounds[index] if i == 0 else "Tevy%s.png" % roads[index])
		var texture: Texture2D
		if ResourceLoader.exists(path, "Texture2D"):
			texture = ResourceLoader.load(path, "Texture2D") as Texture2D
		elif FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			if image != null and not image.is_empty():
				image.generate_mipmaps()
				texture = ImageTexture.create_from_image(image)
		terrain_mat.set_shader_parameter("use_sand_art" if i == 0 else "use_asphalt_art", texture != null)
		if texture != null:
			terrain_mat.set_shader_parameter("sand_art" if i == 0 else "asphalt_art", texture)
	terrain_mat.set_shader_parameter("map_style", index)
	var tint: Color = [Color("#b89c70"), Color("#ffffff"), Color("#925133"), Color("#6b5740"), Color("#a29682")][mini(index, 4)]
	var gradient := Gradient.new()
	gradient.set_color(0, Color(tint.r, tint.g, tint.b, 0.78))
	gradient.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	dust.color_ramp = gradient
	if index == 2:
		smoke.color_ramp = gradient
	else:
		var mist := Gradient.new()
		mist.set_color(0, Color(0.85, 0.88, 0.90, 0.42))
		mist.set_color(1, Color(0.85, 0.88, 0.90, 0.0))
		smoke.color_ramp = mist
	dust.mesh = spray_cloud_mesh
	if index in [2, 3]:
		var clump := _sphere(0.17 if index == 2 else 0.10, 7, 4)
		var material := _std(Color.WHITE, 0.0, 0.92)
		material.vertex_color_use_as_albedo = true
		clump.material = material
		dust.mesh = clump
	dust.restart()
	dust.emitting = false
	dust.initial_velocity_min = 3.2 if index in [1, 2] else 1.0
	dust.initial_velocity_max = 7.4 if index == 2 else (5.8 if index == 1 else 3.0)
	dust.spread = 48.0 if index in [1, 2] else 35.0
	dust.lifetime = 2.6 if index == 0 else (0.92 if index == 2 else 1.35)
	dust.gravity = Vector3(0, -8.0, 0) if index in [2, 3] else Vector3(0, -2.2, 0)
	dust.scale_amount_min = 0.18 if index == 2 else 0.8
	dust.scale_amount_max = 0.55 if index == 2 else (3.6 if index == 0 else 1.55)
	soft_props.clear()
	for data in chunks.values():
		data.node.hide()
		data.node.queue_free()
	chunks.clear()
	for mark in skid_pool:
		mark.hide()
	_respawn(0.0, -1.0)
	race_checkpoint = 0
	race_laps = 0
	race_time = 0.0
	race_best = 0.0
	if build_world:
		_update_chunks(true)


func _build_shop_preview(inventory: Container) -> void:
	var container := SubViewportContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory.add_child(container)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_view = SubViewport.new()
	shop_view.own_world_3d = true
	shop_view.transparent_bg = true
	shop_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(shop_view)
	shop_stage = Node3D.new()
	shop_view.add_child(shop_stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#261a14")
	_inst(shop_view.get_child(0) as Node3D, _cyl(3.13, 3.24, 0.18, 48),
		_std(Color("#332a24"), 0.2, 0.68), Vector3(0, -0.11, 0))
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.48
	shop_view.add_child(world)
	var light := DirectionalLight3D.new()
	light.light_energy = 0.82
	light.rotation_degrees = Vector3(-48, -28, 0)
	shop_view.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24, 144, 0)
	rim.light_color = Color("#ffb36d")
	rim.light_energy = 0.37
	shop_view.add_child(rim)
	var showcase := Camera3D.new()
	showcase.fov = 38.0
	shop_view.add_child(showcase)
	showcase.position = Vector3(3.55, 2.35, 5.15)
	showcase.look_at(Vector3(0, 0.65, 0))
	showcase.make_current()


func _show_shop_preview(index: int = -1) -> void:
	var shown_index := vehicle_index if index < 0 else index
	if is_instance_valid(shop_model):
		shop_model.queue_free()
	if shown_index == vehicle_index and is_instance_valid(vehicle_model):
		shop_model = vehicle_model.duplicate(0) as Node3D
	else:
		shop_model = _load_vinish_model(shown_index)
		if shop_model != null:
			shop_model.scale = Vector3.ONE * 0.93
			for mesh_node in shop_model.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := mesh_node as MeshInstance3D
				for i in range(mesh_instance.mesh.get_surface_count()):
					var original := mesh_instance.mesh.surface_get_material(i)
					if original != null and PAINT_OVERRIDES.has(original.resource_name):
						mesh_instance.set_surface_override_material(i, _std(PAINT_OVERRIDES[original.resource_name], 0.21, 0.44))
	if shop_model != null:
		shop_stage.add_child(shop_model)
		if VEHICLE_FILES[shown_index] in ["Enduro", "GrabATV"]:
			shop_model.scale *= 1.5


func _draw_drive_controls() -> void:
	if is_instance_valid(main_menu) and main_menu.visible:
		return
	var coin_center := Vector2(31, 30)
	drive_controls.draw_circle(coin_center, 12.0, Color("#a86b13"), true, -1, true)
	drive_controls.draw_circle(coin_center - Vector2(1, 1), 9.2, Color("#ffd35a"), true, -1, true)
	drive_controls.draw_arc(coin_center - Vector2(1, 1), 6.5, 0, TAU, 24, Color("#d99524"), 1.8, true)
	drive_controls.draw_line(coin_center + Vector2(-1, -5), coin_center + Vector2(-1, 4), Color("#ffe686"), 2.5, true)
	var radius := _wheel_radius()
	var steel := Color("#acb7bf")
	var dark := Color(0.09, 0.11, 0.14, 0.88)
	drive_controls.draw_circle(_wheel_center() + Vector2(0, 4), radius, Color(0.03, 0.04, 0.05, 0.38))
	drive_controls.draw_set_transform(_wheel_center(), wheel_display * 1.58)
	if wheel_art != null:
		var extent := Vector2.ONE * radius * 2.0
		drive_controls.draw_texture_rect_region(wheel_art, Rect2(-extent * 0.5, extent),
			Rect2(256, 0, 1024, 1024), Color(1, 1, 1, 0.68))
		drive_controls.draw_set_transform(Vector2.ZERO)
		_draw_pedal(_pedal_rect(false), tr("FREN"), brake_display, Color("#e07468"))
		_draw_pedal(_pedal_rect(true), tr("GAZ"), gas_display, Color("#62cfa1"))
		return
	drive_controls.draw_arc(Vector2.ZERO, radius * 0.86, 0, TAU, 64, dark, radius * 0.22, true)
	drive_controls.draw_arc(Vector2.ZERO, radius * 0.95, 0, TAU, 64, steel, 2.0, true)
	drive_controls.draw_arc(Vector2.ZERO, radius * 0.84, 0, TAU, 64, Color("#434950"), radius * 0.07, true)
	for angle: float in [0.0, PI, PI * 0.5]:
		var tip := Vector2.from_angle(angle) * radius * 0.79
		drive_controls.draw_line(Vector2.ZERO, tip, dark, radius * 0.23, true)
		drive_controls.draw_line(Vector2.ZERO, tip * 0.89, steel, radius * 0.10, true)
	drive_controls.draw_circle(Vector2.ZERO, radius * 0.27, dark)
	drive_controls.draw_arc(Vector2.ZERO, radius * 0.21, 0, TAU, 32, steel, 2.0, true)
	drive_controls.draw_circle(Vector2(0, -radius * 0.86), radius * 0.064, Color("#ffb268"))
	drive_controls.draw_set_transform(Vector2.ZERO)
	_draw_pedal(_pedal_rect(false), tr("FREN"), brake_display, Color("#e07468"))
	_draw_pedal(_pedal_rect(true), tr("GAZ"), gas_display, Color("#62cfa1"))


func _draw_pedal(mount: Rect2, caption: String, travel: float, accent: Color) -> void:
	if pedal_art != null:
		var face := Rect2(mount.position + Vector2(mount.size.x * 0.06, 6.0) * travel,
			mount.size * Vector2(1.0 - travel * 0.12, 1.0 - travel * 0.08))
		drive_controls.draw_texture_rect(pedal_art, face, false,
			Color.WHITE.lerp(Color("#c1c5cb"), travel))
		var label_font := ThemeDB.fallback_font
		var label_size := clampi(roundi(mount.size.x * 0.23), 11, 17)
		var label_width := label_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		var label_at := Vector2(mount.get_center().x - label_width * 0.5, mount.position.y - 4.0)
		drive_controls.draw_string_outline(label_font, label_at, caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, 4, Color.BLACK)
		drive_controls.draw_string(label_font, label_at, caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color.WHITE)
		return
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.05, 0.06, 0.08, 0.84)
	base.set_corner_radius_all(11)
	drive_controls.draw_style_box(base, Rect2(mount.position + Vector2(0, 5), mount.size))
	var rect := Rect2(mount.position + Vector2(mount.size.x * 0.035, 6.0) * travel,
		mount.size * Vector2(1.0 - travel * 0.07, 1.0 - travel * 0.06))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#58636c").lerp(accent.darkened(0.42), travel)
	panel.border_color = accent
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	drive_controls.draw_style_box(panel, rect)
	for notch in range(4 if caption == tr("GAZ") else 3):
		var y := rect.position.y + rect.size.y * (0.18 + notch * 0.12)
		drive_controls.draw_line(Vector2(rect.position.x + rect.size.x * 0.22, y),
			Vector2(rect.end.x - rect.size.x * 0.22, y), Color("#232a30"), 4.0, true)
	var font := ThemeDB.fallback_font
	var font_size := clampi(roundi(rect.size.x * 0.25), 10, 17)
	var text_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	drive_controls.draw_string(font, Vector2(rect.get_center().x - text_width * 0.5, rect.end.y - 9),
		caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


func _clear_touch_controls() -> void:
	wheel_finger = -1
	wheel_input = 0.0
	gas_finger = -1
	brake_finger = -1


func _notification(what: int) -> void:
	if is_node_ready() and what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED]:
		_save_garage_progress()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_clear_touch_controls()


func _input(event: InputEvent) -> void:
	if is_instance_valid(main_menu) and main_menu.visible:
		return
	if is_instance_valid(vehicle_shop) and vehicle_shop.visible:
		return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.index == wheel_finger:
				wheel_finger = -1
				wheel_input = 0.0
			if event.index == gas_finger:
				gas_finger = -1
			if event.index == brake_finger:
				brake_finger = -1
		elif wheel_finger == -1 and event.position.distance_to(_wheel_center()) < _wheel_radius() * 1.12:
			wheel_finger = event.index
			wheel_touch_start = event.position.x
		elif gas_finger == -1 and _pedal_rect(true).has_point(event.position):
			gas_finger = event.index
		elif brake_finger == -1 and _pedal_rect(false).has_point(event.position):
			brake_finger = event.index
	elif event is InputEventScreenDrag and event.index == wheel_finger:
		wheel_input = clampf((event.position.x - wheel_touch_start) / _wheel_radius(), -1.0, 1.0)


func _make_label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", race_heading_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# ================================================================ Chunk'lar (sonsuz dünya)

func _update_chunks(initial: bool) -> void:
	if map_index >= 5:
		if initial:
			for x in range(-3, 3):
				for z in range(-2, 2):
					var key := Vector2i(x, z)
					if not chunks.has(key):
						_build_chunk(key)
		return
	var ahead := pos if initial else pos + vel.limit_length(70.0) * 0.70
	var c := Vector2i(floori(ahead.x / CHUNK), floori(ahead.z / CHUNK))
	for key: Vector2i in chunks.keys():
		if absi(key.x - c.x) > LOAD_R + 1 or absi(key.y - c.y) > LOAD_R + 1:
			var old: ChunkData = chunks[key]
			old.node.queue_free()
			chunks.erase(key)

	var best := Vector2i.ZERO
	var best_d := INF
	var found := false
	for dx in range(-LOAD_R, LOAD_R + 1):
		for dz in range(-LOAD_R, LOAD_R + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			if chunks.has(key):
				continue
			if initial:
				_build_chunk(key)
			else:
				var center := Vector2(key) * CHUNK + Vector2.ONE * (CHUNK * 0.5)
				var d := center.distance_squared_to(Vector2(ahead.x, ahead.z))
				if d < best_d:
					best_d = d
					best = key
					found = true
	if found:
		_build_chunk(best)


func _build_chunk(key: Vector2i) -> void:
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	var grid_n := 16 if mobile_low_detail else CHUNK_N
	var cell := CHUNK / grid_n

	var root := Node3D.new()
	add_child(root)
	var cd := ChunkData.new()
	if map_index < 4:
		cd.ramp = _ramp_for_chunk(key)
	elif map_index >= 5 and race_ramp_mesh != null:
		var angle := _race_ramp_angle(key)
		if angle >= 0.0:
			var center := _track_point(angle, 7.6)
			cd.ramp = Vector4(center.x, center.z, 6.0, 1.4)
	cd.node = root
	chunks[key] = cd

	if map_index >= 5:
		var flat := PlaneMesh.new()
		flat.size = Vector2.ONE * CHUNK
		var floor_tile := _inst(root, flat, terrain_mat, Vector3(x0 + CHUNK * 0.5, 0, z0 + CHUNK * 0.5))
		floor_tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		# yükseklik ızgarası (kenarlarda 1 hücre fazladan: normaller için)
		var W := grid_n + 3
		var hs := PackedFloat32Array()
		hs.resize(W * W)
		for j in W:
			for i in W:
				hs[j * W + i] = terrain_h(x0 + (i - 1) * cell, z0 + (j - 1) * cell)

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in grid_n + 1:
			for i in grid_n + 1:
				var gi := (j + 1) * W + (i + 1)
				var h := hs[gi]
				var dhdx := (hs[gi + 1] - hs[gi - 1]) / (2.0 * cell)
				var dhdz := (hs[gi + W] - hs[gi - W]) / (2.0 * cell)
				st.set_normal(Vector3(-dhdx, 1.0, -dhdz).normalized())
				st.set_uv(Vector2(i, j) / grid_n)
				st.add_vertex(Vector3(i * cell, h, j * cell))
		for j in grid_n:
			for i in grid_n:
				var a := j * (grid_n + 1) + i
				var b := a + 1
				var c := a + (grid_n + 1)
				var d := c + 1
				st.add_index(a)
				st.add_index(b)
				st.add_index(c)
				st.add_index(b)
				st.add_index(d)
				st.add_index(c)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = terrain_mat
		mi.position = Vector3(x0, 0.0, z0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	if map_index >= 5:
		_build_race_props(root, key)
		_race_coins(root, cd, key)
		if cd.ramp.z > 0.0:
			var ramp := _inst(root, race_ramp_mesh, null, Vector3(cd.ramp.x, 0, cd.ramp.y), Vector3(0, _ramp_heading(key), 0))
			ramp.scale.x = 2.35 / 3.5
		return
	if cd.ramp.z > 0.0:
		_build_wood_ramp(root, cd.ramp, _ramp_heading(key))

	# --- dekor (her chunk için sabit rastgelelik)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(key.x, key.y, 7))
	if map_index == 3 and not forest_cover.is_empty():
		var cover_rng := RandomNumberGenerator.new()
		cover_rng.seed = hash(Vector3i(key.x, key.y, 42))
		var grass_positions: Array[Transform3D] = []
		for i in range(100):
			var x := x0 + cover_rng.randf() * CHUNK
			var z := z0 + cover_rng.randf() * CHUNK
			if road_dist(x, z) <= ROAD_HALF + 0.45:
				continue
			var size := cover_rng.randf_range(0.85, 1.65)
			var basis := Basis(Vector3.UP, cover_rng.randf() * TAU).scaled(Vector3.ONE * size)
			grass_positions.append(Transform3D(basis, Vector3(x, terrain_h(x, z) - 0.03, z)))
		for part in forest_cover[0].find_children("*", "MeshInstance3D", true, false):
			var grass := part as MeshInstance3D
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.mesh = grass.mesh
			batch.instance_count = grass_positions.size()
			var mesh_offset := forest_cover[0].global_transform.affine_inverse() * grass.global_transform
			for i in range(grass_positions.size()):
				batch.set_instance_transform(i, grass_positions[i] * mesh_offset)
			var patch := MultiMeshInstance3D.new()
			patch.multimesh = batch
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(patch)
		for i in range(14 if forest_cover.size() > 1 else 0):
			var x := x0 + cover_rng.randf() * CHUNK
			var z := z0 + cover_rng.randf() * CHUNK
			if road_dist(x, z) <= ROAD_HALF + 1.5:
				continue
			var cover := forest_cover[1].duplicate(0) as Node3D
			root.add_child(cover)
			cover.position = Vector3(x, terrain_h(x, z), z)
			cover.rotation.y = cover_rng.randf() * TAU
			cover.show()

	# kaktüsler
	for k in 2:
		var x := x0 + rng.randf() * CHUNK
		var z := z0 + rng.randf() * CHUNK
		if road_dist(x, z) < 10.0:
			continue
		var at := Vector3(x, terrain_h(x, z), z)
		if map_index == 0:
			if k % 4 == 0 and road_dist(x, z) > 15.0:
				_make_dry_tree(root, at, rng.randf_range(3.4, 4.3))
				cd.obstacles.append(Vector3(x, z, 0.66))
			else:
				_make_cactus(root, at, rng)
		elif map_index == 2:
			_make_dry_tree(root, at, 1.75)
			cd.obstacles.append(Vector3(x, z, 0.40))
		elif map_index in [1, 3]:
			_make_forest_tree(root, at, rng.randf_range(1.35, 2.1))
			cd.obstacles.append(Vector3(x, z, 0.45))

	# kayalar
	for k in 1:
		var x := x0 + rng.randf() * CHUNK
		var z := z0 + rng.randf() * CHUNK
		if road_dist(x, z) < 9.0:
			continue
		var sx := rng.randf_range(0.8, 2.6)
		var sy := rng.randf_range(0.6, 1.8)
		var sz := rng.randf_range(0.8, 2.6)
		var rotation_y := rng.randf() * TAU
		var rock_source := nama_boulder if map_index == 0 and k % 2 == 0 and nama_boulder != null else boulder_model
		if rock_source != null:
			var rock := rock_source.duplicate(0) as Node3D
			root.add_child(rock)
			rock.position = Vector3(x, terrain_h(x, z) - 0.12, z)
			rock.scale = Vector3(sx * 0.62, sy, sz * 0.67)
			if rock_source == nama_boulder:
				rock.scale *= 0.68
			rock.rotation.y = rotation_y
			rock.show()
		else:
			var rock := _inst(root, m_rock, mat_rock, Vector3(x, terrain_h(x, z) + sy * 0.3, z))
			rock.scale = Vector3(sx, sy, sz)
			rock.rotation.y = rotation_y
		cd.obstacles.append(Vector3(x, z, maxf(sx, sz) * 0.85))

	# yol kenarı reflektör direkleri
	var zz := ceilf(z0 / 24.0) * 24.0
	while zz < z0 + CHUNK:
		for side: float in [-1.0, 1.0]:
			var px := road_x(zz) + side * (ROAD_HALF + 1.2)
			if px >= x0 and px < x0 + CHUNK:
				var gy := terrain_h(px, zz)
				_inst(root, m_post, mat_post, Vector3(px, gy + 0.5, zz))
				_inst(root, m_reflect, mat_reflect, Vector3(px, gy + 0.85, zz))
		zz += 24.0

	# Her bölümde en fazla bir çöl engeli, asfaltın dışında.
	var obstacle_z := z0 + 34.0
	var side := -1.0 if key.y % 2 == 0 else 1.0
	var obstacle_x := road_x(obstacle_z) + side * 7.6
	if key.y % 6 == 0 and obstacle_x >= x0 and obstacle_x < x0 + CHUNK:
		var ground := terrain_h(obstacle_x, obstacle_z)
		var steel := _std(Color("88624b"), 0.42, 0.78)
		var rust := _std(Color("623729"), 0.16, 0.94)
		var barrel := _inst(root, _cyl(0.51, 0.51, 1.17, 20), steel,
			Vector3(obstacle_x, ground + 0.59, obstacle_z))
		for y in [-0.55, -0.23, 0.23, 0.55]:
			_inst(barrel, _cyl(0.537, 0.537, 0.045, 20), rust, Vector3(0, y, 0))
		_inst(barrel, _cyl(0.14, 0.14, 0.045, 12), rust, Vector3(0.21, 0.59, 0.09))
		soft_props.append(barrel)

	# altın dizisi
	if rng.randf() < 0.7:
		var zs := z0 + rng.randf() * (CHUNK - 40.0)
		var lanes: Array = [-2.4, 0.0, 2.4]
		var lane: float = lanes[rng.randi() % 3]
		for k in 5:
			var cz := zs + k * 7.0
			var cx := road_x(cz) + lane
			if cx >= x0 and cx < x0 + CHUNK:
				var coin_id := Vector4i(key.x, key.y, k, map_index)
				if collected_coins.has(coin_id):
					continue
				var coin := Node3D.new()
				coin.set_meta("coin_id", coin_id)
				coin.position = Vector3(cx, terrain_h(cx, cz) + 1.3, cz)
				root.add_child(coin)
				_inst(coin, m_coin, mat_coin, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
				cd.coins.append(coin)


func _obstacle_sprite(parent: Node3D, at: Vector3, cactus: bool, size: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = obstacle_art
	sprite.region_enabled = true
	sprite.region_rect = Rect2(1105, 18, 578, 850) if cactus else Rect2(37, 68, 790, 793)
	sprite.pixel_size = size / sprite.region_rect.size.y
	sprite.centered = false
	sprite.offset = Vector2(-sprite.region_rect.size.x * 0.5, 0.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.45
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	sprite.position = at


func _make_dry_tree(parent: Node3D, at: Vector3, size: float) -> void:
	if map_index == 0 and nama_trunk != null and posmod(floori(at.x + at.z), 3) == 0:
		var trunk := nama_trunk.duplicate(0) as Node3D
		parent.add_child(trunk)
		trunk.position = at - Vector3.UP * 0.10
		trunk.scale = Vector3.ONE * size
		trunk.rotation.y = fposmod(at.x * 0.37 + at.z * 0.29, TAU)
		trunk.show()
		return
	var tree := Node3D.new()
	parent.add_child(tree)
	tree.position = at
	tree.scale = Vector3.ONE * size
	_inst(tree, _cyl(0.08, 0.34, 3.3, 8), forest_bark, Vector3(0, 1.65, 0))
	for i in range(5):
		var radial := Vector3(sin(i * 2.4), 0, cos(i * 2.4))
		var root := Vector3(0, 1.1 + i * 0.37, 0)
		var branch := radial * (1.05 - i * 0.09) + Vector3.UP * 0.85
		var twig := _inst(tree, _cyl(0.023, 0.13 - i * 0.012, branch.length(), 6),
			forest_bark, root + branch * 0.5)
		twig.basis = Basis(Quaternion(Vector3.UP, branch.normalized()))


func _make_forest_tree(parent: Node3D, at: Vector3, size: float) -> void:
	var tree := Node3D.new()
	parent.add_child(tree)
	tree.position = at
	tree.scale = Vector3.ONE * size
	_inst(tree, _cyl(0.13, 0.27, 2.8, 8), forest_bark, Vector3(0, 1.4, 0))
	for layer_index in range(4):
		var radius := 1.45 - layer_index * 0.24
		_inst(tree, _cyl(0.0, radius, 1.7, 10), forest_needles,
			Vector3(0, 1.9 + layer_index * 0.75, 0))
		if map_index == 1:
			_inst(tree, _cyl(0.0, radius * 0.84, 1.36, 10), snow_branch,
				Vector3(0, 2.22 + layer_index * 0.75, 0))


func _make_cactus(parent: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.8, 1.6)
	var template := cactus_model
	if not tevy_cacti.is_empty():
		var variant := posmod(floori(p.x * 2.1 + p.z * 1.7), tevy_cacti.size() + 1)
		if variant < tevy_cacti.size():
			template = tevy_cacti[variant]
	if template != null:
		var cactus := template.duplicate(0) as Node3D
		parent.add_child(cactus)
		cactus.position = p - Vector3.UP * 0.08
		cactus.rotation.y = rng.randf() * TAU
		cactus.scale = Vector3.ONE * s
		cactus.show()
		rng.randf()
		rng.randf()
		cactus.set_meta("breakable_cactus", true)
		soft_props.append(cactus)
		return
	var n := Node3D.new()
	n.position = p
	n.rotation.y = rng.randf() * TAU
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	_inst(n, m_cactus_trunk, mat_cactus, Vector3(0, 1.6, 0))
	_inst(n, m_cap_big, mat_cactus, Vector3(0, 3.2, 0))
	if rng.randf() < 0.8:
		_inst(n, m_cactus_arm_h, mat_cactus, Vector3(0.55, 1.9, 0), Vector3(0, 0, PI / 2.0))
		_inst(n, m_cactus_arm_v, mat_cactus, Vector3(0.95, 2.4, 0))
		_inst(n, m_cap_small, mat_cactus, Vector3(0.95, 2.9, 0))
	if rng.randf() < 0.6:
		_inst(n, m_cactus_arm_h, mat_cactus, Vector3(-0.55, 2.3, 0), Vector3(0, 0, PI / 2.0))
		_inst(n, m_cactus_arm_v, mat_cactus, Vector3(-0.95, 2.8, 0))
		_inst(n, m_cap_small, mat_cactus, Vector3(-0.95, 3.3, 0))
	n.set_meta("breakable_cactus", true)
	soft_props.append(n)


# ================================================================ Ana döngü

func _track_radius(angle: float) -> float:
	if map_index == 7:
		return 1.0 + 0.18 * sin(angle * 3.0) + 0.06 * cos(angle * 6.0)
	if map_index == 6:
		return pow(pow(absf(cos(angle)), 5.0) + pow(absf(sin(angle)), 5.0), -0.2)
	return 1.0 + 0.11 * sin(angle * 5.0) + 0.075 * sin(angle * 3.0)


func _track_point(angle: float, edge: float = 0.0) -> Vector3:
	var axes: Vector2 = TRACK_AXES[map_index - 5]
	var radius := _track_radius(angle) + edge / axes.y
	return Vector3(cos(angle) * axes.x, 0, sin(angle) * axes.y) * radius


func _build_race_props(root: Node3D, key: Vector2i) -> void:
	var mobile_tires: Array[Transform3D] = []
	for i in range(152):
		var angle := TAU * float(i) / 152.0
		for side: float in [-1.0, 1.0]:
			var at := _track_point(angle, side * 11.4)
			var along := _track_point(angle + 0.02, side * 11.4) - at
			var heading := atan2(-along.z, along.x)
			if mobile_low_detail:
				if Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK)) == key:
					var along_wall := Vector3(cos(heading), 0, -sin(heading))
					for offset: float in [-1.15, 0.0, 1.15]:
						for row in range(3):
							mobile_tires.append(Transform3D(Basis.IDENTITY, at + along_wall * offset + Vector3.UP * (0.16 + 0.22 * row)))
			else:
				_add_race_prop(root, key, 4, at, Vector3(1.7, 1, 1), heading)
			if i % (4 if mobile_low_detail else 2) == 0:
				_add_race_prop(root, key, 6, _track_point(angle, side * 13.0), Vector3(2.0, 1.25, 1.0), heading)
	if not mobile_tires.is_empty():
		_add_mobile_tires(root, mobile_tires)
	var start_tangent := -_race_track_tangent(LINE_ANGLE)
	var start_heading := atan2(start_tangent.x, start_tangent.z)
	var line_center := _track_point(LINE_ANGLE)
	_add_race_prop(root, key, 5, line_center, Vector3(1.6, 0.68, 0.85), start_heading)
	if Vector2i(floori(line_center.x / CHUNK), floori(line_center.z / CHUNK)) == key:
		_build_race_line(root, line_center, start_tangent)
func _add_mobile_tires(root: Node3D, transforms: Array[Transform3D]) -> void:
	var tire := TorusMesh.new()
	tire.inner_radius = 0.27
	tire.outer_radius = 0.58
	tire.rings = 8
	tire.ring_segments = 6
	tire.material = _std(Color("#272a2a"), 0.0, 0.93)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = tire
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)

func _race_coins(root: Node3D, chunk: ChunkData, key: Vector2i) -> void:
	for i in range(32):
		var lane := -2.2 if i % 8 < 4 else 2.2
		var at := _track_point(-TAU * (i + 0.5) / 32.0, lane)
		if Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK)) == key:
			_put_road_coin(root, chunk, key, i, at + Vector3.UP * 1.15)


func _put_road_coin(root: Node3D, chunk: ChunkData, key: Vector2i, slot: int, at: Vector3) -> void:
	var id := Vector4i(key.x, key.y, slot, map_index)
	if collected_coins.has(id):
		return
	var coin := Node3D.new()
	root.add_child(coin)
	coin.position = at
	coin.set_meta("coin_id", id)
	_inst(coin, m_coin, mat_coin, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	chunk.coins.append(coin)

func _build_race_line(root: Node3D, center: Vector3, forward: Vector3) -> void:
	var across := Vector3(forward.z, 0.0, -forward.x)
	var ends := PackedFloat32Array()
	for direction: float in [-1.0, 1.0]:
		var width := 0.0
		while width < 12.0 and road_dist(center.x + across.x * direction * width, center.z + across.z * direction * width) < ROAD_HALF - 0.25:
			width += 0.1
		ends.append(width)
	var tile_width := (ends[0] + ends[1]) / 14.0
	var tile := BoxMesh.new()
	tile.size = Vector3(tile_width + 0.004, 0.012, 0.46)
	var white := _std(Color("#ebe5d6"), 0.0, 0.91)
	var dark := _std(Color("#211e1c"), 0.0, 0.92)
	for column in range(14):
		for row in range(2):
			var at := center + across * (tile_width * (column + 0.5) - ends[0])
			at += forward * (row - 0.5) * 0.46 + Vector3.UP * 0.014
			_inst(root, tile, white if (column + row) % 2 == 0 else dark, at, Vector3(0, atan2(forward.x, forward.z), 0))


func _choose_race_rivals() -> Array[int]:
	var pool: Array[int] = []
	for index in range(VEHICLE_NAMES.size()):
		if index != vehicle_index and index not in [4, 14, 16, 19]:
			pool.append(index)
	var target := float(TOP_SPEEDS[vehicle_index])
	pool.sort_custom(func(a: int, b: int) -> bool:
		return absf(float(TOP_SPEEDS[a]) - target) < absf(float(TOP_SPEEDS[b]) - target))
	var eligible := 0
	for index in pool:
		if absf(float(TOP_SPEEDS[index]) - target) <= maxf(target * 0.17, 6.0):
			eligible += 1
	pool.resize(clampi(eligible, 4, 7))
	var lineup: Array[int] = []
	for attempt in range(10):
		pool.shuffle()
		lineup.assign(pool.slice(0, 3))
		lineup.sort()
		if lineup != last_rival_draw:
			break
	last_rival_draw.assign(lineup)
	lineup.shuffle()
	return lineup

func _reset_race_rivals() -> void:
	for rival in race_rivals:
		rival.hide()
		rival.queue_free()
	race_rivals.clear()
	rival_progress.clear()
	rival_speed.clear()
	rival_wheels.clear()
	rival_lane_push.clear()
	if map_index < 5 or map_index == 7:
		return
	rival_cars.clear()
	for model_index in _choose_race_rivals():
		var rival := _load_vinish_model(model_index)
		if rival == null:
			continue
		add_child(rival)
		race_rivals.append(rival)
		rival_cars.append(model_index)
		var wheels: Array[Node3D] = []
		for wheel_name in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
			var wheel := rival.find_child(wheel_name, true, false) as Node3D
			if wheel != null:
				wheels.append(wheel)
		rival_wheels.append(wheels)
		rival_progress.append(-0.07 - race_rivals.size() * 0.035)
		rival_speed.append(0.0)
		rival_lane_push.append(0.0)
	_update_race_rivals(0.0)


func _update_race_rivals(dt: float) -> void:
	
	for i in range(race_rivals.size()):
		var progress := float(rival_progress[i])
		var angle := -progress
		rival_lane_push[i] = move_toward(rival_lane_push[i], 0.0, dt * 2.5)
		var lane := float(i - 1) * 1.3 + sin(progress * 2.2 + i * 1.7) * 1.35 + rival_lane_push[i]
		var near := _track_point(angle + 0.012, lane)
		var far := _track_point(angle - 0.012, lane)
		var stride := maxf(far.distance_to(near) / 0.024, 1.0)
		var rated := float(TOP_SPEEDS[rival_cars[i]])
		var pace := 0.94 + 0.055 * sin(progress * 2.5 + i * 2.1)
		var target := rated * CIRCUIT_PACE * pace * clampf(stride / 82.0, 0.74, 1.0)
		rival_speed[i] = move_toward(rival_speed[i], target, float(ROAD_ACCEL[rival_cars[i]]) * 0.66 * dt)
		rival_progress[i] = progress + rival_speed[i] * dt / stride
		angle = -rival_progress[i]
		var heading := -_race_track_tangent(angle, lane)
		var rival := race_rivals[i]
		rival.position = _track_point(angle, lane) + Vector3.UP * 0.045
		rival.rotation.y = atan2(heading.x, heading.z)
		for wheel: Node3D in rival_wheels[i]:
			wheel.rotate_x(rival_speed[i] * dt / 0.36)
	if dt > 0.0:
		_resolve_race_contacts()

func _race_contact(a: Vector3, a_forward: Vector3, b: Vector3, b_forward: Vector3) -> Vector3:
	if absf(a.y - b.y) > 1.15 or a.distance_squared_to(b) > 28.0:
		return Vector3.ZERO
	var push := Vector3.ZERO
	for sa: float in [-1.35, 0.0, 1.35]:
		for sb: float in [-1.35, 0.0, 1.35]:
			var delta := a + a_forward * sa - b - b_forward * sb
			delta.y = 0.0
			var separation := delta.length()
			if separation < 1.83 and 1.83 - separation > push.length():
				push = (delta / separation if separation > 0.001 else a_forward.cross(Vector3.UP)) * (1.83 - separation)
	return push


func _push_rival(index: int, shove: Vector3) -> void:
	var rival := race_rivals[index]
	var forward := rival.transform.basis.z
	var side := forward.cross(Vector3.UP)
	var center := _track_point(-rival_progress[index])
	var radial := (_track_point(-rival_progress[index], 1.0) - center).normalized()
	rival_lane_push[index] = clampf(rival_lane_push[index] + shove.dot(side) * signf(side.dot(radial)), -4.5, 4.5)
	var stride := _track_point(-rival_progress[index] + 0.01).distance_to(_track_point(-rival_progress[index] - 0.01)) / 0.02
	rival_progress[index] += shove.dot(forward) / maxf(stride, 1.0)
	rival.position += shove
	rival_speed[index] *= 0.79


func _resolve_race_contacts() -> void:
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	for i in range(race_rivals.size()):
		var rival := race_rivals[i]
		var hit := _race_contact(pos, forward, rival.position, rival.transform.basis.z)
		if hit.length_squared() > 0.0001:
			var normal := hit.normalized()
			var closing := (vel - rival.transform.basis.z * rival_speed[i]).dot(normal)
			vel -= normal * minf(closing, 0.0) * 0.72
			pos += hit * 0.53
			_push_rival(i, -hit * 0.47)
			_keep_car_in_track()
			car.position = pos
			if closing < -3.0:
				shake = maxf(shake, 0.28)
		for j in range(i + 1, race_rivals.size()):
			var other := race_rivals[j]
			hit = _race_contact(rival.position, rival.transform.basis.z, other.position, other.transform.basis.z)
			if hit.length_squared() > 0.0001:
				_push_rival(i, hit * 0.5)
				_push_rival(j, -hit * 0.5)

func _race_rank() -> int:
	var axes: Vector2 = TRACK_AXES[map_index - 5]
	var angle := -Vector2(pos.x / axes.x, pos.z / axes.y).angle()
	var gate := race_checkpoint * TAU / 8.0
	var partial := gate + wrapf(angle - gate, -PI, PI)
	var player := race_laps * TAU + partial
	var rank := 1
	for progress in rival_progress:
		if progress > player:
			rank += 1
	return rank

func _race_track_tangent(angle: float, edge: float = 0.0) -> Vector3:
	return (_track_point(angle + 0.01, edge) - _track_point(angle - 0.01, edge)).normalized()

func _add_race_prop(root: Node3D, key: Vector2i, model_index: int, at: Vector3, size: Vector3, heading: float) -> void:
	if race_models[model_index] == null or Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK)) != key:
		return
	var prop := race_models[model_index].duplicate(0) as Node3D
	root.add_child(prop)
	prop.position = at
	prop.scale = size
	prop.rotation.y = heading
	prop.show()


func _keep_car_in_track() -> void:
	var axes: Vector2 = TRACK_AXES[map_index - 5]
	var angle := Vector2(pos.x / axes.x, pos.z / axes.y).angle()
	var middle := _track_point(angle)
	var error := (Vector2(pos.x / axes.x, pos.z / axes.y).length() - _track_radius(angle)) * axes.y
	if absf(error) <= RACE_LIMIT:
		return
	var edge := _track_point(angle, signf(error) * RACE_LIMIT)
	var normal := (edge - middle).normalized()
	pos.x = edge.x
	pos.z = edge.z
	vel -= normal * maxf(vel.dot(normal), 0.0)
	vel *= 0.83


func _update_race(dt: float) -> void:
	if map_index < 5 or map_index == 7 or race_finish_rank > 0:
		return
	race_time += dt
	_update_race_rivals(dt)
	var next := _track_point(-TAU * float((race_checkpoint + 1) % 8) / 8.0)
	if race_checkpoint == 7 and (pos - next).dot(-_race_track_tangent(LINE_ANGLE)) < -0.03:
		return
	if Vector2(pos.x - next.x, pos.z - next.z).length() < 12.0:
		race_checkpoint += 1
		if race_checkpoint == 8:
			race_laps += 1
			race_lap_records[map_index] = maxi(race_laps, int(race_lap_records.get(map_index, 0)))
			_queue_progress_save()
			if race_best == 0.0 or race_time < race_best:
				race_best = race_time
			_say(tr("Tur %d · %.2f sn") % [race_laps, race_time])
			race_time = 0.0
			race_checkpoint = 0
			if race_laps >= RACE_LAPS:
				race_finish_rank = _race_rank()
				race_reward = RACE_PAYOUT[clampi(race_finish_rank - 1, 0, RACE_PAYOUT.size() - 1)]
				coins_n += race_reward
				if race_finish_rank == 1:
					race_win_records[map_index] = 1
				_save_garage_progress()
			_check_goals()


func _physics_process(dt: float) -> void:
	if is_instance_valid(main_menu) and main_menu.visible:
		return
	if is_instance_valid(vehicle_shop) and vehicle_shop.visible:
		return
	msg_t = maxf(0.0, msg_t - dt)
	if challenge_active >= 0:
		_update_challenge(dt)
		return
	impact_t = maxf(0.0, impact_t - dt)
	if map_index >= 5 and race_finish_rank > 0:
		vel = Vector3.ZERO
		return
	if map_index >= 5 and race_countdown > 0.0:
		race_countdown = maxf(0.0, race_countdown - dt)
		_say(str(ceili(race_countdown)) if race_countdown > 0.0 else tr("BAŞLA!"))
		return
	_update_car(dt)
	_update_race(dt)
	if map_index < 4:
		stream_delay = maxf(0.0, stream_delay - dt)
		if stream_delay <= 0.0:
			_update_chunks(false)
			stream_delay = 0.085 if mobile_low_detail else 0.045
	_update_coins(dt)


func _process(delta: float) -> void:
	if map_index == 1:
		snow_fall.position = pos + Vector3(0, 14, 0)
	drift_pop_time = maxf(0.0, drift_pop_time - delta)
	if is_instance_valid(shop_model) and vehicle_shop.visible:
		shop_model.rotate_y(delta * 0.52)
	var visual_step := 1.0 - exp(-19.0 * delta)
	wheel_display = lerpf(wheel_display, wheel_input if wheel_finger >= 0 else steer, visual_step)
	var gas_active := gas_finger >= 0 or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var brake_active := brake_finger >= 0 or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	gas_display = lerpf(gas_display, float(gas_active), visual_step)
	brake_display = lerpf(brake_display, float(brake_active), visual_step)
	_update_camera(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if e == null or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_R:
			var sgn := signf(cos(yaw))
			if sgn == 0.0:
				sgn = -1.0
			_respawn(pos.z, sgn)
		KEY_C:
			paint_idx = (paint_idx + 1) % paint_colors.size()
			mat_paint.albedo_color = paint_colors[paint_idx]


func _respawn(z: float, dir_sign: float) -> void:
	ramp_entry_active = false
	drift_combo = 1
	drift_steps = 0
	drift_display_points = 0
	drift_pop_time = 0.0
	drift_chain_time = 0.0
	drift_grace = 0.0
	var slope := road_slope(z)
	var dir := Vector3(slope * dir_sign, 0.0, dir_sign).normalized()
	yaw = atan2(dir.x, dir.z)
	pos = Vector3(road_x(z), road_h(z), z)
	if map_index >= 5:
		pos = _track_point(LINE_ANGLE + 0.048)
		var race_forward := -_race_track_tangent(0.0)
		yaw = atan2(race_forward.x, race_forward.z)
		race_checkpoint = 0
		race_time = 0.0
		race_countdown = 3.0
		race_finish_rank = 0
		race_reward = 0
		race_laps = 0
	_reset_race_rivals()
	vel = Vector3.ZERO
	vy = 0.0
	steer = 0.0
	last_ground = pos.y
	car_n = Vector3.UP
	grounded = true
	air_time = 0.0
	last_vf = 0.0
	accel_f = 0.0


# ================================================================ Araba fiziği

func _build_wood_ramp(parent: Node3D, ramp: Vector4, heading: float) -> void:
	var direction := Vector2(0, -1).rotated(-heading)
	var wood := [_std(Color("#a57542")), _std(Color("#b8844b")), _std(Color("#92643a"))]
	for i in range(roundi(ramp.z * 2.0)):
		var run := float(i) * 0.5
		var a := _ramp_top(ramp, direction, run)
		var b := _ramp_top(ramp, direction, run + 0.5)
		var slope := atan2(b - a, 0.5)
		var middle := _ramp_point(ramp, direction, run + 0.25)
		_inst(parent, _box(4.7, 0.15, Vector2(0.5, b - a).length() + 0.015),
			wood[i % 3], Vector3(middle.x, (a + b) * 0.5 - 0.07, middle.y),
			Vector3(slope, heading, 0))
		for side: float in [-2.27, 2.27]:
			var wall := middle + direction.orthogonal() * side
			var foot := terrain_h(wall.x, wall.y) - 0.22
			var top := (a + b) * 0.5 - 0.07
			var height := maxf(top - foot, 0.0)
			if height > 0.12:
				_inst(parent, _box(0.16, height, 0.50), wood[(i + 1) % 3],
					Vector3(wall.x, top - height * 0.5, wall.y), Vector3(0, heading, 0))
		if i % 5 == 4:
			for side: float in [-2.0, 2.0]:
				var at := _ramp_point(ramp, direction, run) + direction.orthogonal() * side
				var bottom := terrain_h(at.x, at.y) - 0.15
				var height := maxf(a - bottom, 0.18)
				_inst(parent, _box(0.22, height, 0.25), forest_bark,
					Vector3(at.x, bottom + height * 0.5, at.y))


func _ground_pt(p: Vector3) -> Vector3:
	return Vector3(p.x, _drive_surface(p.x, p.z), p.z)


func _update_car(dt: float) -> void:
	var throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle -= 1.0
	var steer_t := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer_t += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer_t -= 1.0
	var handbrake := Input.is_key_pressed(KEY_SPACE)
	if gas_finger >= 0:
		throttle = 1.0
	if brake_finger >= 0:
		throttle = -1.0
	if wheel_finger >= 0:
		steer_t = wheel_input

	boosting = Input.is_key_pressed(KEY_SHIFT) and nitro > 0.0 and throttle >= 0.0
	if boosting:
		throttle = 1.0
		nitro = maxf(0.0, nitro - 28.0 * dt)
	else:
		nitro = minf(100.0, nitro + 1.5 * dt)

	steer = move_toward(steer, steer_t, dt * (11.0 if steer_t != 0.0 else 15.0))

	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := fwd.cross(Vector3.UP)
	var on_road := challenge_active >= 0 or road_dist(pos.x, pos.z) < ROAD_HALF + 0.3
	var in_mud := map_index == 2 and not on_road
	var drifting := false

	if grounded:
		# eğim kuvveti
		var gx := (terrain_h(pos.x + 1.0, pos.z) - terrain_h(pos.x - 1.0, pos.z)) * 0.5
		var gz := (terrain_h(pos.x, pos.z + 1.0) - terrain_h(pos.x, pos.z - 1.0)) * 0.5
		vel.x -= gx * 7.0 * dt
		vel.z -= gz * 7.0 * dt

		var vf := vel.dot(fwd)
		var vr := vel.dot(right)
		var rated := float(TOP_SPEEDS[vehicle_index])
		var supercar := vehicle_index in [2, 8, 9, 10, 11]
		var off_roader := vehicle_index in [3, 5, 6, 14, 15, 17]
		var surface_factor := 1.0 if on_road else (0.94 if supercar else (0.87 if off_roader else 0.77))
		if map_index >= 5 and not on_road:
			surface_factor = 0.92
		var max_speed := rated * surface_factor * (CIRCUIT_PACE if map_index in [5, 6] else 1.0)
		var accel := float(ROAD_ACCEL[vehicle_index])
		if boosting:
			max_speed *= 1.35
			accel *= 1.9

		if throttle > 0.0:
			if vf < max_speed:
				vf += accel * (1.0 - clampf(vf / max_speed, 0.0, 1.0) * 0.72) * dt
			else:
				vf -= 8.0 * dt
		elif throttle < 0.0:
			if vf > 0.5:
				vf -= 40.0 * dt
			else:
				vf = maxf(vf - 14.0 * dt, -14.0)

		var rr := 2.0 if on_road else (3.0 if off_roader or vehicle_index >= STARTER_INDEX else (2.5 if supercar else 7.0))
		if map_index >= 5 and not on_road:
			rr = 3.8
		vf -= signf(vf) * minf(absf(vf), rr * dt)
		vf -= vf * absf(vf) * 0.0006 * dt
		if handbrake:
			vf -= signf(vf) * minf(absf(vf), 16.0 * dt)

		var grip := 9.0 if on_road else 5.0
		if supercar:
			grip = 12.0 if on_road else 1.55
		elif off_roader and not on_road:
			grip = 8.0
		if handbrake:
			grip = 0.9
		elif vehicle_index in [1, 21, 22] or challenge_active == DRIFT_LEVEL or map_index == 7:
			grip = lerpf(6.0, 2.4, clampf(absf(steer) * 1.4, 0.0, 1.0))
		if map_index >= 5 and not on_road:
			grip = minf(grip, 1.7)
		if map_index == 1:
			grip *= 0.42
		elif in_mud:
			grip *= 0.88 if off_roader else 0.55
			vf = move_toward(vf, 0.0, (1.8 if off_roader else 4.8) * dt)
		vr *= exp(-grip * dt)
		drifting = absf(vr) > (2.4 if challenge_active == DRIFT_LEVEL or map_index == 7 else 3.5) and absf(vf) > (6.0 if challenge_active == DRIFT_LEVEL or map_index == 7 else 8.0)

		vel = fwd * vf + right * vr

		var sf := clampf(absf(vf) / 4.0, 0.0, 1.0)
		var turn := lerpf(2.65, 0.8, clampf(absf(vf) / 38.0, 0.0, 1.0))
		if handbrake:
			turn *= 1.45
		yaw -= steer * turn * sf * signf(vf) * dt

		accel_f = lerpf(accel_f, (vf - last_vf) / dt, 1.0 - exp(-8.0 * dt))
		last_vf = vf
		cur_vf = vf
		cur_vr = vr
	else:
		yaw -= steer * 0.5 * dt

	# konum
	var before_move := pos
	pos.x += vel.x * dt
	pos.z += vel.z * dt
	if map_index >= 5:
		_keep_car_in_track()
	var traveled := Vector2(vel.x, vel.z).length() * dt
	distance += traveled
	if (map_index < 5 or map_index == 7) and challenge_active < 0:
		map_meters[map_index] = float(map_meters.get(map_index, 0.0)) + traveled
		goal_check_delay -= dt
		if goal_check_delay <= 0.0:
			goal_check_delay = 0.4
			_check_goals()
	_collide()
	_check_ramp_entry(before_move)

	if drifting:
		drift_grace = 1.35
		var previous_combo := drift_combo
		drift_chain_time += dt
		drift_combo = clampi(1 + floori(drift_chain_time / 0.85), 1, 5)
		if drift_combo > previous_combo:
			drift_pop_time = 0.72
		var steps := floori(drift_chain_time / 0.24)
		if steps > drift_steps:
			var gain := 50 * drift_combo * (steps - drift_steps)
			drift_display_points += gain
			drift_score += gain
			if challenge_active < 0:
				map_drift[map_index] = float(map_drift.get(map_index, 0.0)) + gain
			drift_steps = steps
	else:
		drift_grace = maxf(0.0, drift_grace - dt)
		if drift_grace <= 0.0:
			drift_chain_time = 0.0
			drift_combo = 1
			drift_steps = 0
			drift_display_points = 0
			drift_pop_time = 0.0

	# dikey hareket ve zemin
	var f2 := Vector3(sin(yaw), 0.0, cos(yaw))
	var r2 := f2.cross(Vector3.UP)
	var p_fl := _ground_pt(pos + f2 * 1.3 - r2)
	var p_fr := _ground_pt(pos + f2 * 1.3 + r2)
	var p_rl := _ground_pt(pos - f2 * 1.3 - r2)
	var p_rr := _ground_pt(pos - f2 * 1.3 + r2)
	var ground_y := (p_fl.y + p_fr.y + p_rl.y + p_rr.y) * 0.25
	var natural_center := terrain_h(pos.x, pos.z)
	var center_surface := _drive_surface(pos.x, pos.z)
	if center_surface > natural_center + 0.07 or ground_y > natural_center + 0.36:
		ground_y = center_surface

	vy -= GRAVITY * dt
	pos.y += vy * dt
	if pos.y - ground_y > 0.5:
		air_time += dt
	if pos.y <= ground_y:
		if air_time >= 0.30:
			var bonus := roundi(air_time * 100.0)
			landing_score += bonus
		if air_time > 0.2 and vy < -6.0:
			shake = minf(1.0, shake + (-vy) / 25.0)
			impact_t = 0.5
			vel *= 0.93
		air_time = 0.0
		pos.y = ground_y
		var launch_limit := minf(25.0, Vector2(vel.x, vel.z).length() * 0.86)
		vy = clampf((ground_y - last_ground) / dt, -25.0, launch_limit)
	last_ground = ground_y
	grounded = pos.y - ground_y < 0.3

	# yüzey normali ve yönelim
	var n := (p_fl - p_rr).cross(p_fr - p_rl)
	if n.y < 0.0:
		n = -n
	n = n.normalized()
	var rate := 14.0 if grounded else 2.5
	car_n = car_n.slerp(n, 1.0 - exp(-rate * dt)).normalized()
	var bz := (f2 - car_n * f2.dot(car_n)).normalized()
	var bx := car_n.cross(bz)
	car.global_transform = Transform3D(Basis(bx, car_n, bz), pos)

	# gövde eğilmesi (gaz/fren ve viraj)
	var pitch_t := clampf(-accel_f * 0.004, -0.08, 0.08)
	var roll_t := clampf(-steer * clampf(cur_vf, -40.0, 40.0) * 0.002, -0.09, 0.09)
	pitch_vis = lerpf(pitch_vis, pitch_t, 1.0 - exp(-8.0 * dt))
	roll_vis = lerpf(roll_vis, roll_t, 1.0 - exp(-8.0 * dt))
	car_body.rotation = Vector3(pitch_vis, 0.0, roll_vis)
	car_body.position.y = lerpf(car_body.position.y, -0.24 if in_mud and grounded else 0.0, minf(1.0, dt * 8.0))

	# tekerlekler
	wheel_angle += cur_vf * dt / 0.38
	if VEHICLE_FILES[vehicle_index] == "DesertRaptor" and is_instance_valid(vehicle_model):
		var stride := sin(wheel_angle * 0.62) * minf(absf(cur_vf) / 5.0, 1.0) * 0.54
		(vehicle_model.get_node("StrideLeft") as Node3D).rotation.x = stride
		(vehicle_model.get_node("StrideRight") as Node3D).rotation.x = -stride
	for w: Node3D in wheel_spins:
		w.rotation.x = wheel_angle
	for p: Node3D in wheel_pivots:
		p.rotation.y = -steer * 0.5

	# ışıklar ve alevler
	tail_mat.emission_energy_multiplier = 3.0 if (throttle < 0.0 and cur_vf > 0.5) or handbrake else 0.8
	for f: MeshInstance3D in flames:
		f.visible = boosting
		f.scale = Vector3(1.0, randf_range(0.8, 1.3), 1.0)

	# toz / duman
	var spd := Vector2(vel.x, vel.z).length()
	dust.emitting = map_index in [1, 2, 3] and grounded and spd > (1.5 if in_mud or map_index == 1 else 4.0) and (in_mud or map_index == 1 or (not on_road) or drifting or impact_t > 0.0)
	if in_mud or map_index == 1:
		var turning := clampf(absf(steer) + absf(cur_vr) * 0.10, 0.0, 1.0)
		dust.direction = Vector3(clampf(-cur_vr * 0.12, -0.9, 0.9), 0.45 + turning * 0.75, -1.0)
		dust.initial_velocity_max = 4.6 + turning * 7.0
		dust.scale_amount_max = (0.55 + turning * 0.75) if in_mud else (1.45 + turning * 1.65)
	var rolling_dust := map_index == 0 and grounded and spd > 2.8 and (not on_road or drifting or impact_t > 0.0)
	for plume in desert_plumes:
		plume.emitting = rolling_dust
		plume.speed_scale = lerpf(0.72, 1.36, clampf((spd + absf(cur_vr) * 1.6) / 30.0, 0.0, 1.0))
	sand_burst_cooldown = maxf(0.0, sand_burst_cooldown - dt)
	if not mobile_low_detail and rolling_dust and sand_burst_cooldown <= 0.0 and (drifting or (not on_road and spd > 13.0)):
		sand_burst.direction = Vector3(clampf(-cur_vr * 0.10, -0.85, 0.85), 0.55, -1.0)
		sand_burst.restart()
		sand_burst.emitting = true
		sand_burst_cooldown = 0.62
	dust.speed_scale = lerpf(0.65, 1.35, clampf(spd / 24.0, 0.0, 1.0))
	smoke.emitting = grounded and spd > 4.0 and (
		((in_mud or map_index == 1) and (absf(steer) > 0.28 or drifting))
		or (not mobile_low_detail and map_index == 3 and drifting and on_road)
	)

	# kayma izleri
	if map_index in [2, 3, 7] and grounded and on_road and (drifting or handbrake) and spd > 6.0:
		_mark_skids(f2, r2)


func _mark_skids(f2: Vector3, r2: Vector3) -> void:
	if pos.distance_to(skid_last) < (1.9 if mobile_low_detail else 0.9):
		return
	skid_last = pos
	for side: float in [-1.0, 1.0]:
		var p := pos - f2 * 1.35 + r2 * side * 0.97
		var m: MeshInstance3D = skid_pool[skid_idx]
		skid_idx = (skid_idx + 1) % skid_pool.size()
		m.visible = true
		m.global_transform = Transform3D(car.global_transform.basis, Vector3(p.x, terrain_h(p.x, p.z) + 0.06, p.z))


func _collide() -> void:
	for i in range(soft_props.size() - 1, -1, -1):
		var prop := soft_props[i]
		if not is_instance_valid(prop) or not prop.is_inside_tree():
			soft_props.remove_at(i)
		elif pos.distance_to(prop.global_position) < 1.85 and vel.length() > 2.0:
			var fall := create_tween().set_parallel(true)
			fall.tween_property(prop, "rotation:z", 1.52, 0.27)
			fall.tween_property(prop, "position", prop.position + vel.normalized() * 1.8 - Vector3.UP * 0.27, 0.34)
			if prop.has_meta("breakable_cactus"):
				fall.tween_property(prop, "scale", prop.scale * Vector3(0.65, 0.34, 0.65), 0.29)
			soft_props.remove_at(i)
	var c := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not chunks.has(key):
				continue
			var cd: ChunkData = chunks[key]
			for o: Vector3 in cd.obstacles:
				var obstacle_height := 1.9 if o.z < 3.0 else o.z * 1.8
				if pos.y > terrain_h(o.x, o.y) + obstacle_height + 0.22:
					continue
				var d := Vector2(pos.x - o.x, pos.z - o.y)
				var min_d := o.z * (0.78 if o.z < 3.0 else 1.0) + 0.75
				var l := d.length()
				if l < min_d:
					var nrm := d / l if l > 0.001 else Vector2.RIGHT
					pos.x = o.x + nrm.x * min_d
					pos.z = o.y + nrm.y * min_d
					var vn := vel.x * nrm.x + vel.z * nrm.y
					if vn < 0.0:
						vel.x -= nrm.x * vn * 1.35
						vel.z -= nrm.y * vn * 1.35
						vel *= 0.9
						if -vn > 4.0:
							shake = minf(1.0, shake + (-vn) / 25.0)
							impact_t = 0.4
						if -vn > 10.0:
							_say(tr("Çarpma!"))


func _update_coins(dt: float) -> void:
	for key: Vector2i in chunks.keys():
		var cd: ChunkData = chunks[key]
		for i in range(cd.coins.size() - 1, -1, -1):
			var coin: Node3D = cd.coins[i]
			coin.rotation.y += dt * 3.0
			var d := Vector2(coin.position.x - pos.x, coin.position.z - pos.z).length()
			if d < 2.6 and absf(coin.position.y - pos.y) < 3.5:
				collected_coins[coin.get_meta("coin_id")] = true
				coin.queue_free()
				cd.coins.remove_at(i)
				coins_n += 1
				map_coins[map_index] = int(map_coins.get(map_index, 0)) + 1
				_check_goals()
				_queue_progress_save()
				nitro = minf(100.0, nitro + 20.0)


# ================================================================ Kamera

func _camera_offset() -> Vector3:
	var view_distance := CAMERA_DISTANCE * (0.85 if challenge_active in range(PARK_LEVELS) else 1.0)
	var diagonal := Vector3(0.55, 0.0, 1.0).normalized() * view_distance
	return diagonal + Vector3.UP * (tan(deg_to_rad(camera_angle)) * view_distance)


func _update_camera(dt: float) -> void:
	var spd := Vector2(vel.x, vel.z).length()
	var focus := pos + Vector3.UP * 0.7 + vel.limit_length(32.0) * 0.20
	if challenge_active in range(PARK_LEVELS):
		focus += (challenge_target - pos).limit_length(22.0) * 0.37
	var offset := _camera_offset()
	cam.position = cam.position.lerp(focus + offset, 1.0 - exp(-6.0 * dt))
	cam.look_at(cam.position - offset)
	var fov_t := 48.0 + minf(spd, 60.0) * 0.25 + (6.0 if boosting else 0.0)
	cam.fov = lerpf(cam.fov, fov_t, 1.0 - exp(-4.0 * dt))
	shake = move_toward(shake, 0.0, dt * 2.0)
	if shake > 0.0:
		cam.h_offset = randf_range(-1.0, 1.0) * shake * 0.6
		cam.v_offset = randf_range(-1.0, 1.0) * shake * 0.6
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# ================================================================ Gündüz - gece

func _apply_map_lighting() -> void:
	_set_daylight()
	var night := map_index == 0 and desert_night
	if challenge_active >= 0:
		sun.light_energy = 0.56
		env.ambient_light_energy = 0.34
	for spot: SpotLight3D in spots:
		spot.visible = night
	if night:
		sun.light_energy = 0.27
		sun.light_color = Color("#a6bbf4")
		env.ambient_light_energy = 0.34
		env.ambient_light_color = Color("#a3acc9")
		env.fog_light_color = Color("#384459")
		sky_mat.sky_top_color = Color("#10182d")
		sky_mat.sky_horizon_color = Color("#414c67")
		sky_mat.ground_horizon_color = Color("#414c67")
		sky_mat.ground_bottom_color = Color("#27263a")


func _set_daylight() -> void:
	sun.rotation_degrees = Vector3(-32.0 if map_index == 0 else -48.0, -58.0, 0.0)
	sun.light_energy = 0.91
	sun.light_color = Color("fff1d8")
	env.ambient_light_color = Color("c9dcf0")
	env.ambient_light_energy = 0.48
	env.fog_light_color = Color("d6b089")
	sky_mat.sky_top_color = Color("527fa5")
	sky_mat.sky_horizon_color = Color("d9caba")
	sky_mat.ground_horizon_color = Color("ccb18e")
	sky_mat.ground_bottom_color = Color("8b6248")
	lens_mat.emission_energy_multiplier = 1.3


# ================================================================ HUD

func _say(text: String) -> void:
	msg_text = text
	msg_t = 2.6


func _update_hud() -> void:
	var vp := get_viewport().get_visible_rect().size
	var kmh := Vector2(vel.x, vel.z).length() * 3.6
	speed_label.text = "%d km/h" % int(kmh)
	speed_label.size.x = 120.0
	speed_label.position = Vector2(vp.x - 140.0, 18.0)

	nitro_bar.size.x = 110.0
	nitro_bar.position = Vector2(vp.x - 130.0, 62.0)
	nitro_bar.value = nitro

	info_label.position = Vector2(24, 20)
	coin_badge.visible = not main_menu.visible
	coin_badge.text = tr("ALTIN  %d") % coins_n
	info_label.position.y = 47
	info_label.text = tr("SKOR   %d\nMESAFE   %.2f km") % [
		int(drift_score) + landing_score, distance / 1000.0]
	if map_index == 7:
		info_label.text = tr("DRIFT PİSTİ\nPUAN  %d") % int(map_drift.get(7, 0))
	elif map_index >= 5:
		info_label.text = tr("TUR  %d / %d   %.1f sn\nSIRA  %d / %d") % [mini(race_laps + 1, RACE_LAPS), RACE_LAPS, race_time, _race_rank(), race_rivals.size() + 1]
		if race_finish_rank > 0:
			info_label.text = tr("YARIŞ BİTTİ   +%d ALTIN\nSIRA  %d / %d") % [race_reward, race_finish_rank, race_rivals.size() + 1]
		if race_best > 0.0:
			info_label.text += tr("\nEn iyi %.2f sn") % race_best
	var driving := not main_menu.visible and not vehicle_shop.visible
	for label in [speed_label, info_label, msg_label, coin_badge, nitro_bar]:
		label.visible = driving
	nitro_bar.visible = driving and not (challenge_active in range(PARK_LEVELS))
	challenge_retry.visible = driving and challenge_active >= 0
	challenge_forward.visible = driving and challenge_won and challenge_active in range(PARK_LEVELS - 1)
	if challenge_active >= 0:
		info_label.text = _challenge_status()
	var show_drift := driving and drift_display_points > 0 and drift_grace > 0.0 and air_time < 0.30 and not main_menu.visible
	drift_points_label.visible = show_drift
	drift_points_label.text = "+%d" % drift_display_points
	drift_points_label.position = Vector2(vp.x * 0.5 - 62.0, vp.y * 0.18)
	drift_multiplier_label.visible = show_drift and drift_pop_time > 0.0
	drift_multiplier_label.text = "×%d" % drift_combo
	drift_multiplier_label.position = drift_points_label.position + Vector2(104.0, 4.0 - (0.72 - drift_pop_time) * 24.0)
	var accent: Color = [Color.WHITE, Color.WHITE, Color("#ffd668"), Color("#ff995c"), Color("#ff73b7"), Color("#76e9ff")][drift_combo]
	accent.a = clampf(drift_pop_time * 3.0, 0.0, 1.0)
	drift_multiplier_label.modulate = accent
	drift_multiplier_label.scale = Vector2.ONE * (1.0 + 0.32 * clampf((drift_pop_time - 0.48) / 0.24, 0.0, 1.0))

	msg_label.position = Vector2(vp.x / 2.0 - 450.0, 40.0)
	msg_label.text = "+%d  ·  %.1f sn" % [roundi(air_time * 100.0), air_time] if air_time >= 0.30 else (msg_text if msg_t > 0.0 else "")
	if driving and session_start_gold >= 0 and (challenge_won or challenge_failed or (map_index in [5, 6] and race_finish_rank > 0)):
		msg_label.text = _session_gold_text()
	drive_controls.queue_redraw()
