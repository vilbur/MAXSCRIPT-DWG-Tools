/*
WinDoorManager.ms
Version: 0.22
Purpose:
	Replace selected master objects by AEC window/door objects.
	Selected listbox AEC object is used as template first.
	If no listbox template is selected, closest existing AEC object is used.
	If no existing AEC object is usable, new AEC object is generated.

Axis mapping:
	Master local X = AEC width
	Master local Y = AEC height
	Master local Z = AEC depth

Alignment:
	Rotation is aligned by master pivot XYZ rotation.
	Position is center-aligned in world X/Y.
	Final world bottom is aligned by AEC pivot-bottom rule: asset.pos.z = master.min.z.
	No guessed half-height/depth offset is applied.
	No bbox operation is executed on generated AEC objects.

Rules:
	Bounding-box operations are executed only on original selected master objects.
	AEC window/door objects are rejected before any bounding-box operation.
	Replacement AEC objects are never measured by bounding-box functions.
	Replacement AEC objects are never updated with update().
*/

function WinDoorManager =
(
	global winDoorManager_rollout_ref

	try
	(
		destroyDialog winDoorManager_rollout_ref
	)
	catch()

	try
	(
		destroyDialog winDoorManagerRollout
	)
	catch()

	try
	(
		destroyDialog aec_bbox_replacer_rollout
	)
	catch()

	rollout winDoorManagerRollout "WinDoor Manager 0.22" width:256 height:780
	(
		local window_nodes = #()
		local door_nodes = #()
		local default_width_value = (try (units.decodeValue "100cm") catch 100.0)
		local default_height_value = (try (units.decodeValue "200cm") catch 200.0)
		local default_depth_value = (try (units.decodeValue "20cm") catch 20.0)
		local default_frame_size_value = (try (units.decodeValue "5cm") catch 5.0)

		groupBox grp_windows "AEC Windows" pos:[8,8] width:240 height:130
		multiListBox mlb_windows "" pos:[16,28] width:224 height:6 items:#()

		groupBox grp_doors "AEC Doors" pos:[8,146] width:240 height:130
		multiListBox mlb_doors "" pos:[16,166] width:224 height:6 items:#()

		button btn_refresh "Refresh Scene Lists" pos:[8,284] width:240 height:28

		groupBox grp_asset "Generated Asset Type" pos:[8,322] width:240 height:70
		dropDownList ddl_asset_type "" pos:[16,344] width:224 height:22 items:#("Fixed Window", "Pivot Door", "Sliding Door", "BiFold Door") selection:1

		groupBox grp_settings "Replacement Settings" pos:[8,402] width:240 height:250

		checkbox chk_include_instances "Include master instances" pos:[16,424] width:220 height:18 checked:true
		checkbox chk_delete_masters "Delete master objects" pos:[16,446] width:220 height:18 checked:true

		spinner spn_fallback_width "Fallback width: " pos:[16,476] width:220 height:16 range:[0.001,1000000,default_width_value] type:#worldUnits scale:1
		spinner spn_fallback_height "Fallback height: " pos:[16,502] width:220 height:16 range:[0.001,1000000,default_height_value] type:#worldUnits scale:1
		spinner spn_fallback_depth "Fallback depth: " pos:[16,528] width:220 height:16 range:[default_depth_value,1000000,default_depth_value] type:#worldUnits scale:1
		spinner spn_min_depth "Min depth: " pos:[16,554] width:220 height:16 range:[default_depth_value,1000000,default_depth_value] type:#worldUnits scale:1
		spinner spn_frame_size "Frame size: " pos:[16,580] width:220 height:16 range:[default_frame_size_value,1000000,default_frame_size_value] type:#worldUnits scale:1
		spinner spn_size_tolerance "Instance tolerance: " pos:[16,606] width:220 height:16 range:[0.0,1000000,0.01] type:#worldUnits scale:0.01

		button btn_replace "Replace Current Selection" pos:[8,664] width:240 height:34

		editText edt_status "" pos:[8,708] width:240 height:56 readOnly:true text:"Ready."

		/*
		Add node to array only once.
		Returns changed array.
		*/
		function appendUniqueNode node_array node_value =
		(
			if isValidNode node_value then
			(
				if (findItem node_array node_value) == 0 then
				(
					append node_array node_value
				)
			)

			node_array -- return
		)


		/*
		Format distance by current display units.
		Used for status text.
		*/
		function formatDistanceValue distance_value =
		(
			result_text = distance_value as string

			try
			(
				result_text = units.formatValue distance_value
			)
			catch()

			result_text -- return
		)

		/*
		Get class text from node and base object.
		Node name is not used, because master objects can contain door/window in name.
		*/
		function getNodeClassText source_node =
		(
			class_text = ""

			if isValidNode source_node then
			(
				try
				(
					class_text += " " + ((classof source_node) as string)
				)
				catch()

				try
				(
					class_text += " " + ((classof source_node.baseObject) as string)
				)
				catch()
			)

			toLower class_text -- return
		)

		/*
		Test if node is AEC door or window.
		This function is hard blocker before bbox operations.
		*/
		function isAecDoorOrWindowNode source_node =
		(
			result_value = false

			if isValidNode source_node then
			(
				class_text = getNodeClassText source_node

				if (findString class_text "fixedwindow") != undefined then
				(
					result_value = true
				)

				if (findString class_text "casementwindow") != undefined then
				(
					result_value = true
				)

				if (findString class_text "awningwindow") != undefined then
				(
					result_value = true
				)

				if (findString class_text "pivotedwindow") != undefined then
				(
					result_value = true
				)

				if (findString class_text "projectedwindow") != undefined then
				(
					result_value = true
				)

				if (findString class_text "slidingwindow") != undefined then
				(
					result_value = true
				)

				if (findString class_text "pivotdoor") != undefined then
				(
					result_value = true
				)

				if (findString class_text "slidingdoor") != undefined then
				(
					result_value = true
				)

				if (findString class_text "bifolddoor") != undefined then
				(
					result_value = true
				)

				if (findString class_text "bifold") != undefined then
				(
					result_value = true
				)

				try
				(
					if (getUserProp source_node "WinDoorManager_AEC") == "true" then
					(
						result_value = true
					)
				)
				catch()
			)

			result_value -- return
		)

		/*
		Test if node is AEC door.
		Used only for UI list.
		*/
		function isAecDoorNode source_node =
		(
			result_value = false

			if isValidNode source_node then
			(
				class_text = getNodeClassText source_node

				if (findString class_text "pivotdoor") != undefined then
				(
					result_value = true
				)

				if (findString class_text "slidingdoor") != undefined then
				(
					result_value = true
				)

				if (findString class_text "bifolddoor") != undefined then
				(
					result_value = true
				)

				if (findString class_text "bifold") != undefined then
				(
					result_value = true
				)
			)

			result_value -- return
		)

		/*
		Test if node is AEC window.
		Used only for UI list.
		*/
		function isAecWindowNode source_node =
		(
			result_value = false

			if isValidNode source_node then
			(
				if not (isAecDoorNode source_node) then
				(
					class_text = getNodeClassText source_node

					if (findString class_text "fixedwindow") != undefined then
					(
						result_value = true
					)

					if (findString class_text "casementwindow") != undefined then
					(
						result_value = true
					)

					if (findString class_text "awningwindow") != undefined then
					(
						result_value = true
					)

					if (findString class_text "pivotedwindow") != undefined then
					(
						result_value = true
					)

					if (findString class_text "projectedwindow") != undefined then
					(
						result_value = true
					)

					if (findString class_text "slidingwindow") != undefined then
					(
						result_value = true
					)
				)
			)

			result_value -- return
		)

		/*
		Check if node is allowed as bbox master.
		AEC door/window objects are always rejected.
		*/
		function isSafeMasterCandidate source_node =
		(
			result_value = false

			if isValidNode source_node then
			(
				if not (isAecDoorOrWindowNode source_node) then
				(
					result_value = true
				)
			)

			result_value -- return
		)

		/*
		Get all instances of node.
		Falls back to source node.
		*/
		function getNodeInstanceArray source_node =
		(
			instance_array = #()

			if isValidNode source_node then
			(
				try
				(
					InstanceMgr.GetInstances source_node &instance_array
				)
				catch
				(
					instance_array = #()
				)

				if instance_array.count == 0 then
				(
					instance_array = #(source_node)
				)
			)

			instance_array -- return
		)

		/*
		Get one representative AEC node per instance group.
		Type can be #window or #door.
		*/
		function getRepresentativeAecNodes aec_type:#window =
		(
			result_array = #()
			visited_nodes = #()

			for node_value in objects do
			(
				if isValidNode node_value then
				(
					type_match = false

					if aec_type == #door then
					(
						type_match = isAecDoorNode node_value
					)
					else
					(
						type_match = isAecWindowNode node_value
					)

					if type_match then
					(
						if (findItem visited_nodes node_value) == 0 then
						(
							append result_array node_value
							instance_array = getNodeInstanceArray node_value

							for instance_node in instance_array do
							(
								appendUniqueNode visited_nodes instance_node
							)
						)
					)
				)
			)

			result_array -- return
		)

		/*
		Build list item label.
		Shows node name and instance count.
		*/
		function getListLabel source_node =
		(
			label_text = ""

			if isValidNode source_node then
			(
				instance_array = getNodeInstanceArray source_node
				label_text = source_node.name + " x" + (instance_array.count as string)
			)

			label_text -- return
		)

		/*
		Refresh AEC scene lists.
		List boxes are selection helpers only.
		*/
		function refreshLists =
		(
			window_nodes = getRepresentativeAecNodes aec_type:#window
			door_nodes = getRepresentativeAecNodes aec_type:#door

			window_items = for node_value in window_nodes collect (getListLabel node_value)
			door_items = for node_value in door_nodes collect (getListLabel node_value)

			mlb_windows.items = window_items
			mlb_doors.items = door_items

			mlb_windows.selection = #{}
			mlb_doors.selection = #{}

			edt_status.text = "Windows: " + (window_nodes.count as string) + "    Doors: " + (door_nodes.count as string) + "\nMin depth: " + (formatDistanceValue spn_min_depth.value) + "    Frame: " + (formatDistanceValue spn_frame_size.value)

			true -- return
		)

		/*
		Select all instances from clicked list item.
		No replacement is executed here.
		*/
		function selectInstancesFromList aec_type:#window clicked_index:0 =
		(
			result_nodes = #()
			selected_indexes = #()

			if aec_type == #door then
			(
				source_nodes = door_nodes
				selected_bits = mlb_doors.selection
			)
			else
			(
				source_nodes = window_nodes
				selected_bits = mlb_windows.selection
			)

			for item_index in selected_bits do
			(
				append selected_indexes item_index
			)

			if selected_indexes.count == 0 then
			(
				if clicked_index > 0 then
				(
					append selected_indexes clicked_index
				)
			)

			for item_index in selected_indexes do
			(
				if item_index <= source_nodes.count then
				(
					instance_array = getNodeInstanceArray source_nodes[item_index]

					for instance_node in instance_array do
					(
						appendUniqueNode result_nodes instance_node
					)
				)
			)

			if result_nodes.count > 0 then
			(
				select result_nodes
				edt_status.text = "Selected instances: " + (result_nodes.count as string)
			)

			result_nodes -- return
		)

		/*
		Get rotation-only matrix from node transform.
		Pivot position is ignored, pivot rotation is preserved.
		*/
		function getNodeRotationOnlyMatrix source_node =
		(
			source_tm = source_node.transform

			x_axis = source_tm.row1
			y_axis = source_tm.row2
			z_axis = source_tm.row3

			if (length x_axis) < 0.000001 then
			(
				x_axis = [1,0,0]
			)
			else
			(
				x_axis = normalize x_axis
			)

			if (length y_axis) < 0.000001 then
			(
				y_axis = [0,1,0]
			)
			else
			(
				y_axis = normalize y_axis
			)

			if (length z_axis) < 0.000001 then
			(
				z_axis = [0,0,1]
			)
			else
			(
				z_axis = normalize z_axis
			)

			rotation_matrix = matrix3 x_axis y_axis z_axis [0,0,0]

			rotation_matrix -- return
		)

		/*
		Read oriented bbox data from one master object.
		This function refuses AEC objects before nodeGetBoundingBox.
		World bottom min.z is calculated from transformed bbox corners.
		*/
		function snapshotMasterBoxData master_node =
		(
			result_data = undefined

			if isSafeMasterCandidate master_node then
			(
				box_matrix = getNodeRotationOnlyMatrix master_node
				bbox_array = undefined

				try
				(
					bbox_array = nodeGetBoundingBox master_node box_matrix
				)
				catch
				(
					bbox_array = undefined
				)

				if bbox_array != undefined then
				(
					bbox_min = bbox_array[1]
					bbox_max = bbox_array[2]
					bbox_size = bbox_max - bbox_min
					bbox_center_local = (bbox_min + bbox_max) * 0.5
					bbox_center_world = bbox_center_local * box_matrix

					corners_world = #(
						[bbox_min.x, bbox_min.y, bbox_min.z] * box_matrix,
						[bbox_max.x, bbox_min.y, bbox_min.z] * box_matrix,
						[bbox_min.x, bbox_max.y, bbox_min.z] * box_matrix,
						[bbox_max.x, bbox_max.y, bbox_min.z] * box_matrix,
						[bbox_min.x, bbox_min.y, bbox_max.z] * box_matrix,
						[bbox_max.x, bbox_min.y, bbox_max.z] * box_matrix,
						[bbox_min.x, bbox_max.y, bbox_max.z] * box_matrix,
						[bbox_max.x, bbox_max.y, bbox_max.z] * box_matrix
					)

					world_min_z = corners_world[1].z

					for corner_index = 2 to corners_world.count do
					(
						if corners_world[corner_index].z < world_min_z then
						(
							world_min_z = corners_world[corner_index].z
						)
					)

					result_data = #(master_node, box_matrix, bbox_min, bbox_max, bbox_size, bbox_center_world, world_min_z)
				)
			)

			result_data -- return
		)

		/*
		Replace near-zero dimension by fallback value.
		Used for flat shapes or zero-depth objects.
		*/
		function getSafeSizeValue size_value fallback_value zero_epsilon:0.001 =
		(
			result_value = abs size_value

			if result_value < zero_epsilon then
			(
				result_value = fallback_value
			)

			result_value -- return
		)

		/*
		Get safe AEC size from already captured master bbox.
		Master local X is width, local Y is height, local Z is depth.
		Returned Point3 stores local axis order: [width, height, depth].
		*/
		function getSafeSizeFromSnapshot master_data fallback_width:100.0 fallback_depth:20.0 fallback_height:200.0 min_depth_value:20.0 zero_epsilon:0.001 =
		(
			result_size = undefined

			if master_data != undefined then
			(
				raw_size = master_data[5]

				safe_width = getSafeSizeValue raw_size.x fallback_width zero_epsilon:zero_epsilon
				safe_height = getSafeSizeValue raw_size.y fallback_height zero_epsilon:zero_epsilon
				safe_depth = getSafeSizeValue raw_size.z fallback_depth zero_epsilon:zero_epsilon

				if safe_depth < min_depth_value then
				(
					safe_depth = min_depth_value
				)

				result_size = [safe_width, safe_height, safe_depth]
			)

			result_size -- return
		)

		/*
		Compare two Point3 sizes.
		Used to keep generated replacements instanced.
		*/
		function areSizesClose size_a size_b tolerance:0.01 =
		(
			result_value = false

			if size_a != undefined and size_b != undefined then
			(
				x_close = (abs (size_a.x - size_b.x)) <= tolerance
				y_close = (abs (size_a.y - size_b.y)) <= tolerance
				z_close = (abs (size_a.z - size_b.z)) <= tolerance

				if x_close and y_close and z_close then
				(
					result_value = true
				)
			)

			result_value -- return
		)

		/*
		Check if all captured master records have same bbox size.
		If true, generated AEC replacements can be instances.
		*/
		function isSnapshotGroupSameSize master_data_array fallback_width:100.0 fallback_depth:20.0 fallback_height:200.0 min_depth_value:20.0 zero_epsilon:0.001 size_tolerance:0.01 =
		(
			result_value = true

			if master_data_array.count > 1 then
			(
				first_size = getSafeSizeFromSnapshot master_data_array[1] fallback_width:fallback_width fallback_depth:fallback_depth fallback_height:fallback_height min_depth_value:min_depth_value zero_epsilon:zero_epsilon

				if first_size == undefined then
				(
					result_value = false
				)
				else
				(
					for item_index = 2 to master_data_array.count do
					(
						test_size = getSafeSizeFromSnapshot master_data_array[item_index] fallback_width:fallback_width fallback_depth:fallback_depth fallback_height:fallback_height min_depth_value:min_depth_value zero_epsilon:zero_epsilon

						if not (areSizesClose first_size test_size tolerance:size_tolerance) then
						(
							result_value = false
						)
					)
				)
			)

			result_value -- return
		)

		/*
		Get selected asset type from dropdown.
		Returns symbol used by generator.
		*/
		function getSelectedAssetType =
		(
			asset_type = #fixedWindow

			case ddl_asset_type.selection of
			(
				1: asset_type = #fixedWindow
				2: asset_type = #pivotDoor
				3: asset_type = #slidingDoor
				4: asset_type = #biFoldDoor
				default: asset_type = #fixedWindow
			)

			asset_type -- return
		)


		/*
		Get property value from node or base object.
		Used to read AEC width, height and depth without bbox.
		*/
		function getNodeOrBaseProperty source_node property_name default_value:undefined =
		(
			result_value = default_value

			if isValidNode source_node then
			(
				if isProperty source_node property_name then
				(
					try
					(
						result_value = getProperty source_node property_name
					)
					catch()
				)

				if result_value == default_value then
				(
					try
					(
						if isProperty source_node.baseObject property_name then
						(
							result_value = getProperty source_node.baseObject property_name
						)
					)
					catch()
				)
			)

			result_value -- return
		)

		/*
		Set property value on node or base object.
		Used to resize copied AEC templates.
		*/
		function setNodeOrBaseProperty source_node property_name property_value =
		(
			result_value = false

			if isValidNode source_node then
			(
				if isProperty source_node property_name then
				(
					try
					(
						setProperty source_node property_name property_value
						result_value = true
					)
					catch()
				)
				else
				(
					try
					(
						if isProperty source_node.baseObject property_name then
						(
							setProperty source_node.baseObject property_name property_value
							result_value = true
						)
					)
					catch()
				)
			)

			result_value -- return
		)

		/*
		Read AEC object dimensions without bbox.
		Returned Point3 order is [width, height, depth].
		*/
		function getAecSizeFromNode source_node =
		(
			result_size = undefined

			if isValidNode source_node then
			(
				width_value = getNodeOrBaseProperty source_node #width default_value:undefined
				height_value = getNodeOrBaseProperty source_node #height default_value:undefined
				depth_value = getNodeOrBaseProperty source_node #depth default_value:undefined

				if width_value != undefined and height_value != undefined and depth_value != undefined then
				(
					result_size = [width_value, height_value, depth_value]
				)
			)

			result_size -- return
		)

		/*
		Set AEC object dimensions without bbox or update.
		Input Point3 order is [width, height, depth].
		*/
		function setAecSizeProperties asset_node size_value =
		(
			result_value = false

			if isValidNode asset_node and size_value != undefined then
			(
				width_set = setNodeOrBaseProperty asset_node #width size_value.x
				height_set = setNodeOrBaseProperty asset_node #height size_value.y
				depth_set = setNodeOrBaseProperty asset_node #depth size_value.z

				if width_set or height_set or depth_set then
				(
					result_value = true
				)
			)

			result_value -- return
		)

		/*
		Return selected AEC source from listboxes.
		Window list has priority over door list when both have selection.
		*/
		function getSelectedTemplateFromLists =
		(
			template_node = undefined

			for item_index in mlb_windows.selection while template_node == undefined do
			(
				if item_index <= window_nodes.count then
				(
					if isValidNode window_nodes[item_index] then
					(
						template_node = window_nodes[item_index]
					)
				)
			)

			if template_node == undefined then
			(
				for item_index in mlb_doors.selection while template_node == undefined do
				(
					if item_index <= door_nodes.count then
					(
						if isValidNode door_nodes[item_index] then
						(
							template_node = door_nodes[item_index]
						)
					)
				)
			)

			template_node -- return
		)

		/*
		Collect AEC templates from scene by preferred asset type.
		If preferred class group is empty, all AEC templates are returned.
		*/
		function getTemplateCandidates asset_type =
		(
			candidate_nodes = #()

			window_nodes = getRepresentativeAecNodes aec_type:#window
			door_nodes = getRepresentativeAecNodes aec_type:#door

			if asset_type == #fixedWindow then
			(
				for node_value in window_nodes do
				(
					appendUniqueNode candidate_nodes node_value
				)
			)
			else
			(
				for node_value in door_nodes do
				(
					appendUniqueNode candidate_nodes node_value
				)
			)

			if candidate_nodes.count == 0 then
			(
				for node_value in window_nodes do
				(
					appendUniqueNode candidate_nodes node_value
				)

				for node_value in door_nodes do
				(
					appendUniqueNode candidate_nodes node_value
				)
			)

			candidate_nodes -- return
		)

		/*
		Find existing AEC object with size closest to target size.
		No bbox operation is used on AEC objects.
		*/
		function findClosestTemplateBySize target_size asset_type =
		(
			best_node = undefined
			best_score = undefined

			if target_size != undefined then
			(
				candidate_nodes = getTemplateCandidates asset_type

				for candidate_node in candidate_nodes do
				(
					candidate_size = getAecSizeFromNode candidate_node

					if candidate_size != undefined then
					(
						width_delta = abs (candidate_size.x - target_size.x)
						height_delta = abs (candidate_size.y - target_size.y)
						depth_delta = abs (candidate_size.z - target_size.z)
						score_value = width_delta + height_delta + depth_delta

						if best_score == undefined then
						(
							best_score = score_value
							best_node = candidate_node
						)
						else
						(
							if score_value < best_score then
							(
								best_score = score_value
								best_node = candidate_node
							)
						)
					)
				)
			)

			best_node -- return
		)

		/*
		Create generated AEC object by default size properties.
		Input size order is [width, height, depth].
		*/
		function createGeneratedAecObject asset_type size_value frame_size_value:5.0 =
		(
			created_node = undefined

			if size_value != undefined then
			(
				width_text = size_value.x as string
				height_text = size_value.y as string
				depth_text = size_value.z as string
				frame_size_text = frame_size_value as string
				frame_thickness_text = (frame_size_value * 0.5) as string
				asset_type_text = toLower (asset_type as string)

				if (findString asset_type_text "fixedwindow") != undefined then
				(
					command_text = "Fixed height:" + height_text + " width:" + width_text + " depth:" + depth_text + " Horizontal_Frame_Width:" + frame_size_text + " Vertical_Frame_Width:" + frame_size_text + " Frame_Thickness:" + frame_thickness_text + " Rail_Width:" + frame_size_text

					try
					(
						created_node = execute command_text
					)
					catch
					(
						created_node = undefined
					)
				)

				if (findString asset_type_text "pivotdoor") != undefined then
				(
					command_text = "PivotDoor height:" + height_text + " width:" + width_text + " depth:" + depth_text

					try
					(
						created_node = execute command_text
					)
					catch
					(
						created_node = undefined
					)
				)

				if (findString asset_type_text "slidingdoor") != undefined then
				(
					command_text = "SlidingDoor height:" + height_text + " width:" + width_text + " depth:" + depth_text

					try
					(
						created_node = execute command_text
					)
					catch
					(
						created_node = undefined
					)
				)

				if ((findString asset_type_text "bifolddoor") != undefined) or ((findString asset_type_text "bifold") != undefined) then
				(
					command_text = "BiFold height:" + height_text + " width:" + width_text + " depth:" + depth_text

					try
					(
						created_node = execute command_text
					)
					catch
					(
						created_node = undefined
					)
				)

				if isValidNode created_node then
				(
					setUserProp created_node "WinDoorManager_AEC" "true"
				)
			)

			created_node -- return
		)

		/*
		Create replacement AEC from template or generator.
		Selected listbox template wins; otherwise closest existing template is used; generator is fallback.
		*/
		function createReplacementAecObject asset_type size_value selected_template_node:undefined frame_size_value:5.0 =
		(
			created_node = undefined
			template_node = selected_template_node

			if template_node == undefined then
			(
				template_node = findClosestTemplateBySize size_value asset_type
			)

			if isValidNode template_node then
			(
				try
				(
					created_node = copy template_node
				)
				catch
				(
					created_node = undefined
				)

				if isValidNode created_node then
				(
					setAecSizeProperties created_node size_value
					setUserProp created_node "WinDoorManager_AEC" "true"
				)
			)

			if not (isValidNode created_node) then
			(
				created_node = createGeneratedAecObject asset_type size_value frame_size_value:frame_size_value
			)

			created_node -- return
		)

		/*
		Copy layer and wirecolor from master.
		Generated node name uses master name suffix.
		*/
		function copyMasterOrganization master_node asset_node suffix:"_AEC" =
		(
			if isValidNode master_node and isValidNode asset_node then
			(
				asset_node.name = uniqueName (master_node.name + suffix)
				asset_node.wirecolor = master_node.wirecolor

				try
				(
					master_layer = master_node.layer
					master_layer.addNode asset_node
				)
				catch()
			)

			asset_node -- return
		)

		/*
		Fit generated AEC object using already captured master data.
		This simulates Align Selection: position center in X/Y, then bottom in world Z.
		AEC windows/doors use their pivot/origin as the bottom reference for this tool.
		No bbox operation is performed on generated AEC objects.
		No update operation is performed on generated AEC objects.
		*/
		function fitGeneratedAecNodeToSnapshot asset_node master_data size_value =
		(
			if isValidNode asset_node and master_data != undefined and size_value != undefined then
			(
				master_matrix = master_data[2]
				target_center_world = master_data[6]
				master_world_min_z = master_data[7]

				asset_position = target_center_world
				asset_position.z = master_world_min_z

				asset_node.transform = matrix3 master_matrix.row1 master_matrix.row2 master_matrix.row3 asset_position
			)

			asset_node -- return
		)

		/*
		Build snapshot groups from current selected master objects.
		All bbox data is captured before any AEC object is created.
		*/
		function buildSelectedMasterSnapshotGroups include_master_instances:true =
		(
			group_array = #()
			visited_nodes = #()

			selected_nodes = selection as array

			for selected_node in selected_nodes do
			(
				if isSafeMasterCandidate selected_node then
				(
					if (findItem visited_nodes selected_node) == 0 then
					(
						if include_master_instances then
						(
							instance_array = getNodeInstanceArray selected_node
						)
						else
						(
							instance_array = #(selected_node)
						)

						master_data_array = #()

						for instance_node in instance_array do
						(
							if isSafeMasterCandidate instance_node then
							(
								if (findItem visited_nodes instance_node) == 0 then
								(
									master_data = snapshotMasterBoxData instance_node

									if master_data != undefined then
									(
										append master_data_array master_data
										appendUniqueNode visited_nodes instance_node
									)
								)
							)
						)

						if master_data_array.count > 0 then
						(
							append group_array master_data_array
						)
					)
				)
			)

			group_array -- return
		)

		/*
		Process one already captured master snapshot group.
		Same-size group creates instanced AEC objects.
		*/
		function processSnapshotGroup master_data_array asset_type selected_template_node:undefined delete_masters:true fallback_width:100.0 fallback_depth:20.0 fallback_height:200.0 min_depth_value:20.0 frame_size_value:5.0 zero_epsilon:0.001 size_tolerance:0.01 =
		(
			created_nodes = #()
			master_nodes_to_delete = #()

			if master_data_array.count > 0 then
			(
				same_size = isSnapshotGroupSameSize master_data_array fallback_width:fallback_width fallback_depth:fallback_depth fallback_height:fallback_height min_depth_value:min_depth_value zero_epsilon:zero_epsilon size_tolerance:size_tolerance

				if same_size then
				(
					seed_size = getSafeSizeFromSnapshot master_data_array[1] fallback_width:fallback_width fallback_depth:fallback_depth fallback_height:fallback_height min_depth_value:min_depth_value zero_epsilon:zero_epsilon
					seed_node = createReplacementAecObject asset_type seed_size selected_template_node:selected_template_node frame_size_value:frame_size_value

					if isValidNode seed_node then
					(
						for item_index = 1 to master_data_array.count do
						(
							master_data = master_data_array[item_index]
							master_node = master_data[1]

							if item_index == 1 then
							(
								asset_node = seed_node
							)
							else
							(
								asset_node = instance seed_node
								setUserProp asset_node "WinDoorManager_AEC" "true"
							)

							copyMasterOrganization master_node asset_node
							fitGeneratedAecNodeToSnapshot asset_node master_data seed_size

							append created_nodes asset_node
							appendUniqueNode master_nodes_to_delete master_node
						)
					)
				)
				else
				(
					for master_data in master_data_array do
					(
						master_node = master_data[1]
						asset_size = getSafeSizeFromSnapshot master_data fallback_width:fallback_width fallback_depth:fallback_depth fallback_height:fallback_height min_depth_value:min_depth_value zero_epsilon:zero_epsilon
						asset_node = createReplacementAecObject asset_type asset_size selected_template_node:selected_template_node frame_size_value:frame_size_value

						if isValidNode asset_node then
						(
							copyMasterOrganization master_node asset_node
							fitGeneratedAecNodeToSnapshot asset_node master_data asset_size

							append created_nodes asset_node
							appendUniqueNode master_nodes_to_delete master_node
						)
					)
				)

				if delete_masters then
				(
					if master_nodes_to_delete.count > 0 then
					(
						delete master_nodes_to_delete
					)
				)
			)

			created_nodes -- return
		)

		/*
		Replace current selected master objects by AEC objects.
		Template priority: selected listbox object, closest existing AEC object, generated fallback.
		*/
		function processCurrentSelection delete_masters:true include_master_instances:true fallback_width:100.0 fallback_depth:20.0 fallback_height:200.0 min_depth_value:20.0 frame_size_value:5.0 zero_epsilon:0.001 size_tolerance:0.01 =
		(
			result_text = "Nothing processed."
			created_nodes = #()
			deleted_count = 0

			group_array = buildSelectedMasterSnapshotGroups include_master_instances:include_master_instances

			if group_array.count == 0 then
			(
				result_text = "Select master object(s). AEC door/window objects are ignored."
			)
			else
			(
				asset_type = getSelectedAssetType()
				selected_template_node = getSelectedTemplateFromLists()
				source_text = "generated fallback"

				if isValidNode selected_template_node then
				(
					source_text = "list template: " + selected_template_node.name
				)
				else
				(
					probe_size = getSafeSizeFromSnapshot group_array[1][1] fallback_width:fallback_width fallback_depth:fallback_depth fallback_height:fallback_height min_depth_value:min_depth_value zero_epsilon:zero_epsilon
					probe_template = findClosestTemplateBySize probe_size asset_type

					if isValidNode probe_template then
					(
						source_text = "closest template: " + probe_template.name
					)
				)

				for master_data_array in group_array do
				(
					if delete_masters then
					(
						deleted_count += master_data_array.count
					)

					new_nodes = processSnapshotGroup master_data_array asset_type selected_template_node:selected_template_node delete_masters:delete_masters fallback_width:fallback_width fallback_depth:fallback_depth fallback_height:fallback_height min_depth_value:min_depth_value frame_size_value:frame_size_value zero_epsilon:zero_epsilon size_tolerance:size_tolerance

					for new_node in new_nodes do
					(
						appendUniqueNode created_nodes new_node
					)
				)

				if created_nodes.count > 0 then
				(
					select created_nodes
					result_text = "Created: " + (created_nodes.count as string) + "    Deleted masters: " + (deleted_count as string) + "\nSource: " + source_text
				)
				else
				(
					result_text = "No AEC object was created."
				)
			)

			result_text -- return
		)

		on winDoorManagerRollout open do
		(
			refreshLists()
		)

		on btn_refresh pressed do
		(
			refreshLists()
		)

		on mlb_windows doubleClicked item_index do
		(
			selectInstancesFromList aec_type:#window clicked_index:item_index
		)

		on mlb_doors doubleClicked item_index do
		(
			selectInstancesFromList aec_type:#door clicked_index:item_index
		)

		on btn_replace pressed do
		(
			with undo "WinDoorManager Replace Current Selection" on
			(
				result_text = processCurrentSelection delete_masters:chk_delete_masters.checked include_master_instances:chk_include_instances.checked fallback_width:spn_fallback_width.value fallback_depth:spn_fallback_depth.value fallback_height:spn_fallback_height.value min_depth_value:spn_min_depth.value frame_size_value:spn_frame_size.value size_tolerance:spn_size_tolerance.value

				edt_status.text = result_text
			)

			refreshLists()
		)
	)

	winDoorManager_rollout_ref = winDoorManagerRollout
	createDialog winDoorManager_rollout_ref

	winDoorManager_rollout_ref -- return
)


/*
Test AEC blocker.
Creates FixedWindow and verifies that snapshot refuses it before bbox.
*/
function testWinDoorManagerAecBlock =
(
	test_window = undefined

	try
	(
		test_window = Fixed height:50 width:40 depth:20
	)
	catch
	(
		test_window = undefined
	)

	if isValidNode test_window then
	(
		block_result = winDoorManager_rollout_ref.isAecDoorOrWindowNode test_window
		snapshot_result = winDoorManager_rollout_ref.snapshotMasterBoxData test_window

		format "AEC blocked: %\n" block_result
		format "Snapshot must be undefined: %\n" snapshot_result

		#(block_result, snapshot_result) -- return
	)
	else
	(
		format "FixedWindow was not created.\n"

		#() -- return
	)
)


/*
Test rotation alignment.
Created window rotation must match source master rotation.
*/
function testWinDoorManagerRotationMatch =
(
	delete objects

	test_master = box length:180 width:220 height:24
	test_master.name = uniqueName "TEST_MASTER_ROTATION_MATCH"

	test_rot = (eulerAngles 0 0 0) as matrix3
	test_master.transform = matrix3 test_rot.row1 test_rot.row2 test_rot.row3 [0,0,0]

	select test_master
	winDoorManager()

	format "Press Replace Current Selection. Created AEC rotation should match source rotation.\n"

	test_master -- return
)


/*
Test WinDoorManager.
Creates two instanced master boxes and opens manager.
*/
function testWinDoorManager =
(
	delete objects

	test_master_a = box length:180 width:220 height:24
	test_master_a.name = uniqueName "TEST_MASTER_X_WIDTH_Y_HEIGHT_Z_DEPTH"

	test_rot_a = (eulerAngles 0 0 25) as matrix3
	test_master_a.transform = matrix3 test_rot_a.row1 test_rot_a.row2 test_rot_a.row3 [0,0,0]

	test_master_b = instance test_master_a
	test_master_b.name = uniqueName "TEST_MASTER_INSTANCE"

	test_rot_b = (eulerAngles 0 0 -35) as matrix3
	test_master_b.transform = matrix3 test_rot_b.row1 test_rot_b.row2 test_rot_b.row3 [350,0,0]

	select #(test_master_a)

	winDoorManager()

	#(test_master_a, test_master_b) -- return
)


/*
Test center alignment.
Generated AEC rotation must match source. Position is centered in world X/Y and bottom-aligned in world Z.
*/
function testWinDoorManagerCenterMatch =
(
	delete objects

	test_master = box length:180 width:220 height:8
	test_master.name = uniqueName "TEST_MASTER_CENTER_MATCH"

	test_rot = (eulerAngles 0 0 20) as matrix3
	test_master.transform = matrix3 test_rot.row1 test_rot.row2 test_rot.row3 [100,50,0]

	select test_master
	winDoorManager()

	format "Press Replace Current Selection. Created AEC should visually center on master box.\n"

	test_master -- return
)


/*
Test world bottom alignment.
Generated object should satisfy generated.min.z = master.min.z by calculated transform.
*/
function testWinDoorManagerBottomZ =
(
	delete objects

	test_master = box length:180 width:220 height:24
	test_master.name = uniqueName "TEST_MASTER_BOTTOM_Z"

	test_rot = (eulerAngles 35 0 20) as matrix3
	test_master.transform = matrix3 test_rot.row1 test_rot.row2 test_rot.row3 [100,50,30]

	select test_master
	winDoorManager()

	format "Press Replace Current Selection. Generated AEC object should have same world min.z as master.\n"

	test_master -- return
)


/*
Manual tests:

testWinDoorManager()
-- Press Replace Current Selection.

testWinDoorManagerAecBlock()
-- Expected:
-- AEC blocked: true
-- Snapshot must be undefined: undefined

testWinDoorManagerRotationMatch()
-- Press Replace Current Selection.
-- Created AEC rotation must match source master rotation.
*/
