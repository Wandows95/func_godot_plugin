class_name FuncGodotMapParser extends RefCounted

var scope:= FuncGodotMapParser.ParseScope.FILE
var comment: bool = false
var entity_idx: int = -1
var brush_idx: int = -1
var face_idx: int = -1
var component_idx: int = 0
var prop_key: String = ""
var current_property: String = ""
var valve_uvs: bool = false

var current_face: FuncGodotMapData.FuncGodotFace
var current_brush: FuncGodotMapData.FuncGodotBrush
var current_entity: FuncGodotMapData.FuncGodotEntity

var map_data: FuncGodotMapData
var _keep_tb_groups: bool = false

#### TASTYSPLEEN_CLASSY 4/15/2025 ####	
var _chunk_worldspawn_geo: bool = false
var _worldspawn_geo_chunk_size: int = 512
var _worldspawn_geo_entity_name: String = ""
#### TASTYSPLEEN_CLASSY 4/15/2025 ####	

#### TASTYSPLEEN_REKI 4/17/20205 ####
class MaterialProperties:
	var contentbits : int = 0x0
	var isvisible : bool = false
	pass

var _json_materials : Dictionary = {}
#### TASTYSPLEEN_REKI 4/17/20205 ####

func _init(in_map_data: FuncGodotMapData) -> void:
	map_data = in_map_data

#### TASTYSPLEEN_CLASSY 4/15/2025 ####	
'''
func load_map(map_file: String, keep_tb_groups: bool) -> bool:
'''
func load_map(map_file: String, keep_tb_groups: bool, chunk_worldspawn_geo: bool, worldspawn_geo_chunk_size: int, worldspawn_geo_entity_name: String) -> bool:
	_chunk_worldspawn_geo = chunk_worldspawn_geo
	_worldspawn_geo_chunk_size = worldspawn_geo_chunk_size
	_worldspawn_geo_entity_name = worldspawn_geo_entity_name
#### TASTYSPLEEN_CLASSY 4/15/2025 ####
	current_face = FuncGodotMapData.FuncGodotFace.new()
	current_brush = FuncGodotMapData.FuncGodotBrush.new()
	current_entity = FuncGodotMapData.FuncGodotEntity.new()

	load_material_flags()
	
	scope = FuncGodotMapParser.ParseScope.FILE
	comment = false
	entity_idx = -1
	brush_idx = -1
	face_idx = -1
	component_idx = 0
	valve_uvs = false
	_keep_tb_groups = keep_tb_groups
	
	var lines: PackedStringArray = []
	
	var map: FileAccess = FileAccess.open(map_file, FileAccess.READ)
	
	if map == null:
		printerr("Error: Failed to open map file (" + map_file + ")")
		return false
	
	if map_file.ends_with(".import"):
		while not map.eof_reached():
			var line: String = map.get_line()
			if line.begins_with("path"):
				map.close()
				line = line.replace("path=", "");
				line = line.replace('"', '')
				var map_data: String = (load(line) as QuakeMapFile).map_data
				if map_data.is_empty():
					printerr("Error: Failed to open map file (" + line + ")")
					return false
				lines = map_data.split("\n")
				break
	else:
		while not map.eof_reached():
			var line: String = map.get_line()
			lines.append(line)
	
	for line in lines:
		if comment:
			comment = false
		var tokens := split_string(line, [" ", "\t"], true)
		for s in tokens:
			token(s)
	
	return true

func split_string(s: String, delimeters: Array[String], allow_empty: bool = true) -> Array[String]:
	var parts: Array[String] = []
	
	var start := 0
	var i := 0
	
	while i < s.length():
		if s[i] in delimeters:
			if allow_empty or start < i:
				parts.push_back(s.substr(start, i - start))
			start = i + 1
		i += 1
	
	if allow_empty or start < i:
		parts.push_back(s.substr(start, i - start))
	
	return parts
	
func set_scope(new_scope: FuncGodotMapParser.ParseScope) -> void:
	"""
	match new_scope:
		ParseScope.FILE:
			print("Switching to file scope.")
		ParseScope.ENTITY:
			print("Switching to entity " + str(entity_idx) + "scope")
		ParseScope.PROPERTY_VALUE:
			print("Switching to property value scope")
		ParseScope.BRUSH:
			print("Switching to brush " + str(brush_idx) + " scope")
		ParseScope.PLANE_0:
			print("Switching to face " + str(face_idx) + " plane 0 scope")
		ParseScope.PLANE_1:
			print("Switching to face " + str(face_idx) + " plane 1 scope")
		ParseScope.PLANE_2:
			print("Switching to face " + str(face_idx) + " plane 2 scope")
		ParseScope.TEXTURE:
			print("Switching to texture scope")
		ParseScope.U:
			print("Switching to U scope")
		ParseScope.V:
			print("Switching to V scope")
		ParseScope.VALVE_U:
			print("Switching to Valve U scope")
		ParseScope.VALVE_V:
			print("Switching to Valve V scope")
		ParseScope.ROT:
			print("Switching to rotation scope")
		ParseScope.U_SCALE:
			print("Switching to U scale scope")
		ParseScope.V_SCALE:
			print("Switching to V scale scope")
	"""
	scope = new_scope

func token(buf_str: String) -> void:
	if comment:
		return
	elif buf_str == "//":
		comment = true
		return
	
	match scope:
		FuncGodotMapParser.ParseScope.FILE:
			if buf_str == "{":
				entity_idx += 1
				brush_idx = -1
				set_scope(FuncGodotMapParser.ParseScope.ENTITY)
		FuncGodotMapParser.ParseScope.ENTITY:
			if buf_str.begins_with('"'):
				prop_key = buf_str.substr(1)
				if prop_key.ends_with('"'):
					prop_key = prop_key.left(-1)
					set_scope(FuncGodotMapParser.ParseScope.PROPERTY_VALUE)
			elif buf_str == "{":
				brush_idx += 1
				face_idx = -1
				set_scope(FuncGodotMapParser.ParseScope.BRUSH)
			elif buf_str == "}":
				commit_entity()
				set_scope(FuncGodotMapParser.ParseScope.FILE)
		FuncGodotMapParser.ParseScope.PROPERTY_VALUE:
			var is_first = buf_str[0] == '"'
			var is_last = buf_str.right(1) == '"'
			
			if is_first:
				if current_property != "":
					current_property = ""
				
			if not is_last:
				current_property += buf_str + " "
			else:
				current_property += buf_str
				
			if is_last:
				current_entity.properties[prop_key] = current_property.substr(1, len(current_property) - 2)
				set_scope(FuncGodotMapParser.ParseScope.ENTITY)
		FuncGodotMapParser.ParseScope.BRUSH:
			if buf_str == "(":
				face_idx += 1
				component_idx = 0
				set_scope(FuncGodotMapParser.ParseScope.PLANE_0)
			elif buf_str == "}":
				commit_brush()
				set_scope(FuncGodotMapParser.ParseScope.ENTITY)
		FuncGodotMapParser.ParseScope.PLANE_0:
			if buf_str == ")":
				component_idx = 0
				set_scope(FuncGodotMapParser.ParseScope.PLANE_1)
			else:
				match component_idx:
					0:
						current_face.plane_points.v0.x = float(buf_str)
					1:
						current_face.plane_points.v0.y = float(buf_str)
					2:
						current_face.plane_points.v0.z = float(buf_str)
						
				component_idx += 1
		FuncGodotMapParser.ParseScope.PLANE_1:
			if buf_str != "(":
				if buf_str == ")":
					component_idx = 0
					set_scope(FuncGodotMapParser.ParseScope.PLANE_2)
				else:
					match component_idx:
						0:
							current_face.plane_points.v1.x = float(buf_str)
						1:
							current_face.plane_points.v1.y = float(buf_str)
						2:
							current_face.plane_points.v1.z = float(buf_str)
							
					component_idx += 1
		FuncGodotMapParser.ParseScope.PLANE_2:
			if buf_str != "(":
				if buf_str == ")":
					component_idx = 0
					set_scope(FuncGodotMapParser.ParseScope.TEXTURE)
				else:
					match component_idx:
						0:
							current_face.plane_points.v2.x = float(buf_str)
						1:
							current_face.plane_points.v2.y = float(buf_str)
						2:
							current_face.plane_points.v2.z = float(buf_str)
							
					component_idx += 1
		FuncGodotMapParser.ParseScope.TEXTURE:
			current_face.texture_idx = map_data.register_texture(buf_str)
			set_scope(FuncGodotMapParser.ParseScope.U)
		FuncGodotMapParser.ParseScope.U:
			if buf_str == "[":
				valve_uvs = true
				component_idx = 0
				set_scope(FuncGodotMapParser.ParseScope.VALVE_U)
			else:
				valve_uvs = false
				current_face.uv_standard.x = float(buf_str)
				set_scope(FuncGodotMapParser.ParseScope.V)
		FuncGodotMapParser.ParseScope.V:
				current_face.uv_standard.y = float(buf_str)
				set_scope(FuncGodotMapParser.ParseScope.ROT)
		FuncGodotMapParser.ParseScope.VALVE_U:
			if buf_str == "]":
				component_idx = 0
				set_scope(FuncGodotMapParser.ParseScope.VALVE_V)
			else:
				match component_idx:
					0:
						current_face.uv_valve.u.axis.x = float(buf_str)
					1:
						current_face.uv_valve.u.axis.y = float(buf_str)
					2:
						current_face.uv_valve.u.axis.z = float(buf_str)
					3:
						current_face.uv_valve.u.offset = float(buf_str)
					
				component_idx += 1
		FuncGodotMapParser.ParseScope.VALVE_V:
			if buf_str != "[":
				if buf_str == "]":
					set_scope(FuncGodotMapParser.ParseScope.ROT)
				else:
					match component_idx:
						0:
							current_face.uv_valve.v.axis.x = float(buf_str)
						1:
							current_face.uv_valve.v.axis.y = float(buf_str)
						2:
							current_face.uv_valve.v.axis.z = float(buf_str)
						3:
							current_face.uv_valve.v.offset = float(buf_str)
						
					component_idx += 1
		FuncGodotMapParser.ParseScope.ROT:
			current_face.uv_extra.rot = float(buf_str)
			set_scope(FuncGodotMapParser.ParseScope.U_SCALE)
		FuncGodotMapParser.ParseScope.U_SCALE:
			current_face.uv_extra.scale_x = float(buf_str)
			set_scope(FuncGodotMapParser.ParseScope.V_SCALE)
		FuncGodotMapParser.ParseScope.V_SCALE:
			current_face.uv_extra.scale_y = float(buf_str)
			commit_face()
			set_scope(FuncGodotMapParser.ParseScope.BRUSH)
				
#### TASTYSPLEEN_CLASSY 4/15/2025 ####
func load_material_flags():
	var json_string : String = "
	{
		\"dev/dev_playerclip\": {
			\"invisible\": true,
			\"clip_player\": true,
			\"parent\": \"\"
		},
		\"dev/dev_noclip\": {
			\"invisible\": true,
			\"clip_misc\": false,
			\"parent\": \"\"
		},
		\"dev_weapon_and_player_clip\": {
			\"invisible\": true,
			\"clip_player\": true,
			\"clip_weapon\": true,
			\"parent\": \"\"
		}
	}"

	var flag_json = JSON.new()
	var error = flag_json.parse(json_string)
	
	if error != OK:
		print("JSON Parse Error: ", flag_json.get_error_message(), " in ", json_string, " at line ", flag_json.get_error_line())
		return

	for key in flag_json.data.keys():
		_json_materials[key] = build_material_clip_flags(flag_json.data[key])

func build_material_clip_flags(flag_dict: Dictionary) -> MaterialProperties:
	var mat_definition : MaterialProperties = MaterialProperties.new()
	var clip_master_list: Array[String] = ["clip_player", "clip_weapon", "clip_misc"]
	var clip_flag_mask: int = 0xFFFFFFF
	var clip_uninitialized: bool = true

	for idx in clip_master_list.size():
		if !(clip_master_list[idx] in flag_dict):
			continue
		if (clip_uninitialized):
			clip_uninitialized = false
			clip_flag_mask = 0x0000000
		
		var flag: bool = flag_dict[clip_master_list[idx]]
		clip_flag_mask |= int(flag) << idx
	mat_definition.contentbits = clip_flag_mask

	if ("invisible" in flag_dict):
		mat_definition.isvisible = !bool(flag_dict["invisible"])

	if (!mat_definition.isvisible):
		pass

	return mat_definition


#### TASTYSPLEEN_CLASSY 4/15/2025 ####

func commit_entity() -> void:
	#print("resulting material clip dict " + str(dickt))
#### TASTYSPLEEN_CLASSY 4/15/2025 ####
# if current_entity.properties.has('_tb_type') and map_data.entities.size() > 0:
#### TASTYSPLEEN_CLASSY 4/15/2025 ####
	if !_chunk_worldspawn_geo and current_entity.properties.has('_tb_type') and map_data.entities.size() > 0:
		map_data.entities[0].brushes.append_array(current_entity.brushes)
		current_entity.brushes.clear()
		if !_keep_tb_groups:
			current_entity = FuncGodotMapData.FuncGodotEntity.new()
			return
	
	var new_entity:= FuncGodotMapData.FuncGodotEntity.new()
	new_entity.spawn_type = FuncGodotMapData.FuncGodotEntitySpawnType.ENTITY
	new_entity.properties = current_entity.properties

	

#### TASTYSPLEEN_CLASSY 4/15/2025 ####
	'''
	new_entity.brushes = current_entity.brushes
	'''
	# Determine if we are ingesting a worldspawn entity
	var is_worldspawn : bool = true
	
	if current_entity.properties.has("classname"):
		if current_entity.properties["classname"] != "worldspawn":
			is_worldspawn = false
	else:
		is_worldspawn = false

	if !is_worldspawn or !_chunk_worldspawn_geo:
		new_entity.brushes = current_entity.brushes
#### TASTYSPLEEN_CLASSY 4/15/2025 ####

	map_data.entities.append(new_entity)

#### TASTYSPLEEN_CLASSY 4/15/2025 ####
	if is_worldspawn and _chunk_worldspawn_geo:
		var chunk_bucket : Dictionary = {}

		# Iterate over ever brush in worldspawn
		for brush in current_entity.brushes:
			var found_bucket : bool = false
			var brush_center : Vector3 = brush.find_center_naive()
			var brush_flags : int = brush.find_contentbits(map_data, _json_materials)
			# Determine which chunk this brush will be in
			var chunk_x = int(brush_center.x/_worldspawn_geo_chunk_size)
			var chunk_y = int(brush_center.y/_worldspawn_geo_chunk_size)
			var chunk_content = brush_flags
			# Iterate over chunks
			for chunk in chunk_bucket:
				# Check if brush should be in chunk
				if (chunk[0] == chunk_x) and (chunk[1] == chunk_y) and (chunk[2] == chunk_content):
					chunk_bucket[chunk].append(brush)
					found_bucket = true
					break
				# If no chunk found, make a new one
			if !found_bucket:
				chunk_bucket[[chunk_x, chunk_y, chunk_content]] = [brush]
			found_bucket = false

		# Convert chunk bucket into entities
		for chunk in chunk_bucket:
			var chunk_entity:= FuncGodotMapData.FuncGodotEntity.new()
			chunk_entity.spawn_type = FuncGodotMapData.FuncGodotEntitySpawnType.ENTITY
			chunk_entity.properties["classname"] = _worldspawn_geo_entity_name
			chunk_entity.properties["contentbits"] = chunk[2]

			for chunk_brush in chunk_bucket[chunk]:
				chunk_entity.brushes.append(chunk_brush)

			map_data.entities.append(chunk_entity)
#### TASTYSPLEEN_CLASSY 4/15/2025 ####
	
	current_entity = FuncGodotMapData.FuncGodotEntity.new()
	
func commit_brush() -> void:
	current_entity.brushes.append(current_brush)
	current_brush = FuncGodotMapData.FuncGodotBrush.new()
	
func commit_face() -> void:
	var v0v1: Vector3 = current_face.plane_points.v1 - current_face.plane_points.v0
	var v1v2: Vector3 = current_face.plane_points.v2 - current_face.plane_points.v1
	current_face.plane_normal = v1v2.cross(v0v1).normalized()
	current_face.plane_dist = current_face.plane_normal.dot(current_face.plane_points.v0)
	current_face.is_valve_uv = valve_uvs
	
	current_brush.faces.append(current_face)
	current_face = FuncGodotMapData.FuncGodotFace.new()

# Nested
enum ParseScope{
	FILE,
	COMMENT,
	ENTITY,
	PROPERTY_VALUE,
	BRUSH,
	PLANE_0,
	PLANE_1,
	PLANE_2,
	TEXTURE,
	U,
	V,
	VALVE_U,
	VALVE_V,
	ROT,
	U_SCALE,
	V_SCALE
}
