(
global TransformLockClassManager_v
global TransformLockClassManager
global TransformLockClassManager_ui

try
(
	callbacks.removeScripts id:#TransformLockClassManagerNodeCreated
)
catch
(
)

try
(
	callbacks.removeScripts id:#TransformLockClassManagerSelectionChanged
)
catch
(
)

try
(
	callbacks.removeScripts id:#TransformLockClassManagerSceneRefresh
)
catch
(
)

try
(
	if (TransformLockClassManager_ui != undefined) then
	(
		destroyDialog TransformLockClassManager_ui
	)
)
catch
(
)

struct TransformLockClassManager_v
(
	version = "0.17",

	node_created_callback_id = #TransformLockClassManagerNodeCreated,
	selection_changed_callback_id = #TransformLockClassManagerSelectionChanged,
	scene_refresh_callback_id = #TransformLockClassManagerSceneRefresh,

	class_keys = #(),
	class_names = #(),
	ignored_class_keys = #(),

	transform_names = #("Position", "Rotation", "Scale"),
	axis_names = #("X", "Y", "Z"),

	values = #(),
	ui_is_updating = false,

	/* Initialize default lock values.
	All transform locks are false.
	*/
	function initValues =
	(
		values = #()

		for class_index = 1 to class_keys.count do
		(
			append values #(false, false, false, false, false, false, false, false, false)
		)

		values -- return
	),

	/* Get ini path for scene storage.
	Saved scene stores ini next to scene file.
	*/
	function getIniPath =
	(
		ini_path = ""

		if (maxFilePath != undefined and maxFilePath != "") then
		(
			ini_path = maxFilePath + "TransformLockClassManager.ini"
		)
		else
		(
			ini_path = (getDir #userScripts) + "\\TransformLockClassManager.ini"
		)

		ini_path -- return
	),

	/* Get per scene ini section.
	Section name is base scene filename without suffix.
	*/
	function getSceneSectionName =
	(
		section_name = "UNSAVED_SCENE"

		if (maxFileName != undefined and maxFileName != "") then
		(
			section_name = getFilenameFile maxFileName
		)

		if (section_name == undefined or section_name == "") then
		(
			section_name = "UNSAVED_SCENE"
		)

		section_name -- return
	),

	/* Set rollout status text.
	Safe to call when rollout is closed.
	*/
	function setStatus status_text =
	(
		try
		(
			TransformLockClassManager_ui.lb_status.text = status_text
		)
		catch
		(
		)

		status_text -- return
	),

	/* Get transform lock flag index.
	Order is position xyz, rotation xyz, scale xyz.
	*/
	function getFlagIndex transform_index axis_index =
	(
		(((transform_index - 1) * 3) + axis_index) -- return
	),

	/* Sanitize class name for ini key.
	Spaces and tabs are changed to underscores.
	*/
	function getIniSafeName name_text =
	(
		safe_text = name_text as string
		safe_text = substituteString safe_text " " "_"
		safe_text = substituteString safe_text "\t" "_"

		safe_text -- return
	),

	/* Get ini key name.
	Key is built from class, transform and axis names.
	*/
	function getIniKey class_index transform_index axis_index =
	(
		(getIniSafeName class_names[class_index] + "_" + transform_names[transform_index] + "_" + axis_names[axis_index]) -- return
	),

	/* Get ignore ini key name.
	Ignored classes are saved per scene and class key.
	*/
	function getIgnoreIniKey class_index =
	(
		(getIniSafeName class_names[class_index] + "_Ignored") -- return
	),

	/* Test whether class key is ignored.
	Ignored classes are skipped by all transform actions.
	*/
	function isClassKeyIgnored class_key =
	(
		((findItem ignored_class_keys class_key) > 0) -- return
	),

	/* Test whether class index is ignored.
	Index is checked against current dynamic class list.
	*/
	function isClassIndexIgnored class_index =
	(
		ignored_state = false

		if (class_index >= 1 and class_index <= class_keys.count) then
		(
			ignored_state = isClassKeyIgnored class_keys[class_index]
		)

		ignored_state -- return
	),

	/* Load ignored class flags from ini.
	Only current scene classes are read.
	*/
	function loadIgnoredValues =
	(
		ignored_class_keys = #()
		ini_path = getIniPath()
		section_name = getSceneSectionName()

		for class_index = 1 to class_keys.count do
		(
			key_name = getIgnoreIniKey class_index
			value_text = getINISetting ini_path section_name key_name

			if (value_text == "1" or value_text == "true" or value_text == "TRUE") then
			(
				append ignored_class_keys class_keys[class_index]
			)
		)

		ignored_class_keys -- return
	),

	/* Save ignored class flags to ini.
	All current scene classes are stored.
	*/
	function saveIgnoredValues =
	(
		ini_path = getIniPath()
		section_name = getSceneSectionName()

		for class_index = 1 to class_keys.count do
		(
			key_name = getIgnoreIniKey class_index
			value_text = if (isClassIndexIgnored class_index) then "1" else "0"
			setINISetting ini_path section_name key_name value_text
		)

		true -- return
	),

	/* Load values from per scene ini section.
	Missing values stay false.
	*/
	function loadValues =
	(
		initValues()

		ini_path = getIniPath()
		section_name = getSceneSectionName()

		for class_index = 1 to class_keys.count do
		(
			for transform_index = 1 to transform_names.count do
			(
				for axis_index = 1 to axis_names.count do
				(
					flag_index = getFlagIndex transform_index axis_index
					key_name = getIniKey class_index transform_index axis_index
					value_text = getINISetting ini_path section_name key_name

					if (value_text == "1" or value_text == "true" or value_text == "TRUE") then
					(
						values[class_index][flag_index] = true
					)
				)
			)
		)

		values -- return
	),

	/* Save values to per scene ini section.
	Section name is base scene filename without suffix.
	*/
	function saveValues =
	(
		ini_path = getIniPath()
		section_name = getSceneSectionName()

		for class_index = 1 to class_keys.count do
		(
			for transform_index = 1 to transform_names.count do
			(
				for axis_index = 1 to axis_names.count do
				(
					flag_index = getFlagIndex transform_index axis_index
					key_name = getIniKey class_index transform_index axis_index
					value_text = if (values[class_index][flag_index] == true) then "1" else "0"

					setINISetting ini_path section_name key_name value_text
				)
			)
		)

		true -- return
	),

	/* Get class key from scene node.
	Group head has priority, otherwise baseObject real class is used.
	*/
	function getNodeClassKey scene_node =
	(
		class_key = undefined

		if (isValidNode scene_node) then
		(
			if (isGroupHead scene_node) then
			(
				class_key = "Group"
			)
			else
			(
				base_object_value = undefined

				try
				(
					base_object_value = scene_node.baseObject
				)
				catch
				(
					base_object_value = undefined
				)

				if (base_object_value != undefined) then
				(
					try
					(
						class_key = (classOf base_object_value) as string
					)
					catch
					(
						class_key = undefined
					)
				)
			)
		)

		class_key -- return
	),

	/* Load real baseObject classes used by scene nodes.
	This is the only primary scanner and uses objects directly.
	*/
	function loadSceneClasses =
	(
		found_keys = #()

		for scene_node in objects do
		(
			try
			(
				class_key = getNodeClassKey scene_node

				if (class_key != undefined and class_key != "" and findItem found_keys class_key == 0) then
				(
					append found_keys class_key
				)
			)
			catch
			(
			)
		)

		sort found_keys
		class_keys = found_keys
		class_names = for class_key in class_keys collect class_key

		class_names -- return
	),

	/* Get formatted class listbox items.
	Ignored classes are prefixed but kept visible.
	*/
	function getClassListboxItems =
	(
		listbox_items = #()

		for class_index = 1 to class_names.count do
		(
			prefix_text = if (isClassIndexIgnored class_index) then "[IGN] " else "[USE] "
			append listbox_items (prefix_text + class_names[class_index])
		)

		listbox_items -- return
	),

	/* Populate class listbox from current dynamic class list.
	Selection can be preserved when class names still exist.
	*/
	function populateClassListbox preserve_selection:true =
	(
		previous_names = #()
		previous_selection = #{}

		try
		(
			previous_selection = TransformLockClassManager_ui.lbx_classes.selection

			for item_index = 1 to class_names.count do
			(
				if (previous_selection[item_index] == true) then
				(
					append previous_names class_names[item_index]
				)
			)
		)
		catch
		(
		)

		try
		(
			TransformLockClassManager_ui.lbx_classes.items = getClassListboxItems()

			if (preserve_selection == true) then
			(
				selected_flags = #{}

				for previous_name in previous_names do
				(
					class_index = findItem class_names previous_name

					if (class_index > 0) then
					(
						selected_flags[class_index] = true
					)
				)

				TransformLockClassManager_ui.lbx_classes.selection = selected_flags
			)
			else
			(
				TransformLockClassManager_ui.lbx_classes.selection = #{}
			)
		)
		catch
		(
		)

		class_names.count -- return
	),

	/* Refresh scene classes, values and listbox.
	Called on rollout open and after max file changes.
	*/
	function updateUiByScene apply_locks:true preserve_selection:true source_name:"Scene refresh" =
	(
		loadSceneClasses()
		loadIgnoredValues()
		loadValues()
		populateClassListbox preserve_selection:preserve_selection

		if (apply_locks == true) then
		(
			TransformLockClassManager.applyAllClassesToScene()
		)

		TransformLockClassManager.updateUi()
		setStatus (source_name + " | Classes: " + (class_names.count as string) + " | Section: " + getSceneSectionName())

		class_names.count -- return
	),

	/* Convert class values to transform lock bitarray.
	Bitarray is used by setTransformLockFlags.
	*/
	function getFlagsFromClassIndex class_index =
	(
		flag_array = #{}

		for flag_index = 1 to 9 do
		(
			flag_array[flag_index] = values[class_index][flag_index]
		)

		flag_array -- return
	),

	/* Get selected class indices from multi-listbox.
	Returns only explicit listbox selection.
	*/
	function getSelectedClassIndices =
	(
		selected_indices = #()

		try
		(
			selected_flags = TransformLockClassManager_ui.lbx_classes.selection

			for item_index = 1 to class_keys.count do
			(
				if (selected_flags[item_index] == true) then
				(
					append selected_indices item_index
				)
			)
		)
		catch
		(
			selected_indices = #()
		)

		selected_indices -- return
	),

	/* Get effective class indices.
	If listbox selection is empty, global mode uses all non-ignored classes.
	*/
	function getEffectiveClassIndices =
	(
		selected_indices = getSelectedClassIndices()

		if (selected_indices.count == 0) then
		(
			selected_indices = for class_index = 1 to class_keys.count collect class_index
		)

		filtered_indices = #()

		for class_index in selected_indices do
		(
			if ((isClassIndexIgnored class_index) == false) then
			(
				append filtered_indices class_index
			)
		)

		filtered_indices -- return
	),

	/* Check if listbox is in global mode.
	Empty selection means all classes.
	*/
	function isGlobalMode =
	(
		((getSelectedClassIndices()).count == 0) -- return
	),

	/* Get class indices from node array.
	Used to sync listbox with current selection.
	*/
	function getClassIndicesFromNodes node_array =
	(
		class_indices = #()

		for scene_node in node_array do
		(
			node_class_key = getNodeClassKey scene_node
			class_index = findItem class_keys node_class_key

			if (class_index > 0 and findItem class_indices class_index == 0) then
			(
				append class_indices class_index
			)
		)

		sort class_indices

		class_indices -- return
	),

	/* Get button color from state.
	Green is unlocked, red is locked, orange is mixed.
	*/
	function getStateColor state_value =
	(
		color_class = dotNetClass "System.Drawing.Color"
		color_value = color_class.FromArgb 190 245 190

		case state_value of
		(
			0:
			(
				color_value = color_class.FromArgb 190 245 190
			)
			1:
			(
				color_value = color_class.FromArgb 255 170 170
			)
			2:
			(
				color_value = color_class.FromArgb 255 215 145
			)
		)

		color_value -- return
	),

	/* Setup dotNet button as colored flat lock button.
	Button has larger font and zero padding.
	*/
	function setupColorButton button_control button_text =
	(
		flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"
		color_class = dotNetClass "System.Drawing.Color"
		font_style_class = dotNetClass "System.Drawing.FontStyle"
		content_align_class = dotNetClass "System.Drawing.ContentAlignment"

		button_control.text = button_text
		button_control.flatStyle = flat_style_class.Flat
		button_control.useVisualStyleBackColor = false
		button_control.backColor = color_class.FromArgb 190 245 190
		button_control.foreColor = color_class.Black
		button_control.font = dotNetObject "System.Drawing.Font" "Segoe UI" 10.0 font_style_class.Bold
		button_control.padding = dotNetObject "System.Windows.Forms.Padding" 0
		button_control.margin = dotNetObject "System.Windows.Forms.Padding" 0
		button_control.textAlign = content_align_class.MiddleCenter
		button_control.flatAppearance.borderSize = 0

		true -- return
	),

	/* Setup normal action button.
	Used for Hide and Freeze only.
	*/
	function setupActionButton button_control button_text =
	(
		flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"
		color_class = dotNetClass "System.Drawing.Color"
		font_style_class = dotNetClass "System.Drawing.FontStyle"
		content_align_class = dotNetClass "System.Drawing.ContentAlignment"

		button_control.text = button_text
		button_control.flatStyle = flat_style_class.System
		button_control.useVisualStyleBackColor = true
		button_control.font = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0 font_style_class.Regular
		button_control.padding = dotNetObject "System.Windows.Forms.Padding" 0
		button_control.margin = dotNetObject "System.Windows.Forms.Padding" 0
		button_control.textAlign = content_align_class.MiddleCenter
		button_control.foreColor = color_class.Black

		true -- return
	),

	/* Set colored lock button state.
	0 unlocked green, 1 locked red, 2 mixed orange.
	*/
	function setColorButtonState button_control state_value button_text =
	(
		button_control.text = button_text
		button_control.useVisualStyleBackColor = false
		button_control.backColor = getStateColor state_value

		true -- return
	),

	/* Get axis dotNet button control by transform and axis index.
	Only X Y Z lock buttons are returned here.
	*/
	function getAxisButtonControl transform_index axis_index =
	(
		control_value = undefined

		case transform_index of
		(
			1:
			(
				case axis_index of
				(
					1: control_value = TransformLockClassManager_ui.dn_pos_x
					2: control_value = TransformLockClassManager_ui.dn_pos_y
					3: control_value = TransformLockClassManager_ui.dn_pos_z
				)
			)
			2:
			(
				case axis_index of
				(
					1: control_value = TransformLockClassManager_ui.dn_rot_x
					2: control_value = TransformLockClassManager_ui.dn_rot_y
					3: control_value = TransformLockClassManager_ui.dn_rot_z
				)
			)
			3:
			(
				case axis_index of
				(
					1: control_value = TransformLockClassManager_ui.dn_scl_x
					2: control_value = TransformLockClassManager_ui.dn_scl_y
					3: control_value = TransformLockClassManager_ui.dn_scl_z
				)
			)
		)

		control_value -- return
	),

	/* Get All dotNet button control by transform index.
	All is one colored button per transform row.
	*/
	function getAllButtonControl transform_index =
	(
		control_value = undefined

		case transform_index of
		(
			1:
			(
				control_value = TransformLockClassManager_ui.dn_pos_all
			)
			2:
			(
				control_value = TransformLockClassManager_ui.dn_rot_all
			)
			3:
			(
				control_value = TransformLockClassManager_ui.dn_scl_all
			)
		)

		control_value -- return
	),

	/* Get mixed lock state for effective classes.
	0 is unlocked, 1 is locked, 2 is mixed.
	*/
	function getMixedLockState transform_index axis_index class_indices =
	(
		has_true = false
		has_false = false

		for class_index in class_indices do
		(
			if (axis_index == 0) then
			(
				for axis_loop_index = 1 to 3 do
				(
					flag_index = getFlagIndex transform_index axis_loop_index

					if (values[class_index][flag_index] == true) then
					(
						has_true = true
					)
					else
					(
						has_false = true
					)
				)
			)
			else
			(
				flag_index = getFlagIndex transform_index axis_index

				if (values[class_index][flag_index] == true) then
				(
					has_true = true
				)
				else
				(
					has_false = true
				)
			)
		)

		state_value = 0

		if (has_true == true and has_false == true) then
		(
			state_value = 2
		)
		else if (has_true == true) then
		(
			state_value = 1
		)

		state_value -- return
	),

	/* Apply stored class lock to one node.
	Used by nodeCreated callback.
	*/
	function applyLockToNode scene_node =
	(
		is_locked = false

		if (isValidNode scene_node) then
		(
			node_class_key = getNodeClassKey scene_node
			class_index = findItem class_keys node_class_key

			if (class_index > 0 and ((isClassIndexIgnored class_index) == false)) then
			(
				flag_array = getFlagsFromClassIndex class_index

				try
				(
					setTransformLockFlags scene_node flag_array
					is_locked = true
				)
				catch
				(
					is_locked = false
				)
			)
		)

		is_locked -- return
	),

	/* Apply lock to callback parameter.
	Supports single node and array value.
	*/
	function applyLockToCallbackParam callback_value =
	(
		updated_count = 0

		loadSceneClasses()
		loadIgnoredValues()
		loadValues()
		populateClassListbox preserve_selection:true

		if (callback_value != undefined) then
		(
			if (isKindOf callback_value Array) then
			(
				for callback_item in callback_value do
				(
					if (applyLockToNode callback_item) then
					(
						updated_count += 1
					)
				)
			)
			else
			(
				if (applyLockToNode callback_value) then
				(
					updated_count = 1
				)
			)
		)

		if (updated_count > 0) then
		(
			TransformLockClassManager.setStatus ("Auto locked new node: " + (updated_count as string) + " | Classes: " + (class_names.count as string))
		)

		updated_count -- return
	),

	/* Register manager callbacks.
	Old callbacks with same IDs are removed first.
	*/
	function registerCallbacks =
	(
		try
		(
			callbacks.removeScripts id:node_created_callback_id
		)
		catch
		(
		)

		try
		(
			callbacks.removeScripts id:selection_changed_callback_id
		)
		catch
		(
		)

		try
		(
			callbacks.removeScripts id:scene_refresh_callback_id
		)
		catch
		(
		)

		node_script = "try (if (TransformLockClassManager != undefined) then (TransformLockClassManager.applyLockToCallbackParam (callbacks.notificationParam()))) catch()"
		selection_script = "try (if (TransformLockClassManager != undefined) then (TransformLockClassManager.updateListboxSelectionByCurrentSelection())) catch()"
		refresh_script = "try (if (TransformLockClassManager != undefined) then (TransformLockClassManager.updateUiByScene apply_locks:true preserve_selection:false source_name:\"File scene refresh\")) catch()"

		try
		(
			callbacks.addScript #nodeCreated node_script id:node_created_callback_id persistent:false
		)
		catch
		(
		)

		try
		(
			callbacks.addScript #selectionSetChanged selection_script id:selection_changed_callback_id persistent:false
		)
		catch
		(
		)

		try
		(
			callbacks.addScript #filePostOpen refresh_script id:scene_refresh_callback_id persistent:false
		)
		catch
		(
		)

		try
		(
			callbacks.addScript #systemPostNew refresh_script id:scene_refresh_callback_id persistent:false
		)
		catch
		(
		)

		try
		(
			callbacks.addScript #systemPostReset refresh_script id:scene_refresh_callback_id persistent:false
		)
		catch
		(
		)

		try
		(
			callbacks.addScript #postMerge refresh_script id:scene_refresh_callback_id persistent:false
		)
		catch
		(
		)

		true -- return
	),

	/* Unregister manager callbacks.
	Useful before reloading script or disabling manager.
	*/
	function unregisterCallbacks =
	(
		try
		(
			callbacks.removeScripts id:node_created_callback_id
		)
		catch
		(
		)

		try
		(
			callbacks.removeScripts id:selection_changed_callback_id
		)
		catch
		(
		)

		try
		(
			callbacks.removeScripts id:scene_refresh_callback_id
		)
		catch
		(
		)

		true -- return
	),

	/* Apply effective class settings to scene nodes.
	Empty listbox selection means all non-ignored classes.
	*/
	function applyEffectiveClassesToScene =
	(
		class_indices = getEffectiveClassIndices()
		updated_count = 0

		for scene_node in objects do
		(
			node_class_key = getNodeClassKey scene_node
			class_index = findItem class_keys node_class_key

			if (class_index > 0 and findItem class_indices class_index > 0) then
			(
				flag_array = getFlagsFromClassIndex class_index

				try
				(
					setTransformLockFlags scene_node flag_array
					updated_count += 1
				)
				catch
				(
				)
			)
		)

		if (isGlobalMode()) then
		(
			setStatus ("Global mode | Locked: " + (updated_count as string) + " nodes | Section: " + getSceneSectionName())
		)
		else
		(
			setStatus ("Selected classes | Locked: " + (updated_count as string) + " nodes | Section: " + getSceneSectionName())
		)

		updated_count -- return
	),

	/* Apply all stored class settings to scene nodes.
	Used on rollout open and scene reload.
	*/
	function applyAllClassesToScene =
	(
		updated_count = 0

		for scene_node in objects do
		(
			node_class_key = getNodeClassKey scene_node
			class_index = findItem class_keys node_class_key

			if (class_index > 0 and ((isClassIndexIgnored class_index) == false)) then
			(
				flag_array = getFlagsFromClassIndex class_index

				try
				(
					setTransformLockFlags scene_node flag_array
					updated_count += 1
				)
				catch
				(
				)
			)
		)

		setStatus ("Loaded | Locked: " + (updated_count as string) + " nodes | Section: " + getSceneSectionName())

		updated_count -- return
	),

	/* Show or hide all nodes of effective classes.
	False shows nodes, true hides nodes.
	*/
	function setEffectiveClassesHidden hidden_state =
	(
		class_indices = getEffectiveClassIndices()
		updated_count = 0

		for scene_node in objects do
		(
			node_class_key = getNodeClassKey scene_node
			class_index = findItem class_keys node_class_key

			if (class_index > 0 and findItem class_indices class_index > 0) then
			(
				try
				(
					if (hidden_state == true) then
					(
						hide scene_node
					)
					else
					(
						unhide scene_node
					)

					updated_count += 1
				)
				catch
				(
				)
			)
		)

		if (hidden_state == true) then
		(
			setStatus ("Hidden class nodes: " + (updated_count as string))
		)
		else
		(
			setStatus ("Shown class nodes: " + (updated_count as string))
		)

		updated_count -- return
	),

	/* Freeze or unfreeze all nodes of effective classes.
	Frozen objects are shown in gray.
	*/
	function setEffectiveClassesFrozen frozen_state =
	(
		class_indices = getEffectiveClassIndices()
		updated_count = 0

		for scene_node in objects do
		(
			node_class_key = getNodeClassKey scene_node
			class_index = findItem class_keys node_class_key

			if (class_index > 0 and findItem class_indices class_index > 0) then
			(
				try
				(
					scene_node.showFrozenInGray = true
				)
				catch
				(
				)

				try
				(
					scene_node.isFrozen = frozen_state
					updated_count += 1
				)
				catch
				(
				)
			)
		)

		if (frozen_state == true) then
		(
			setStatus ("Frozen class nodes: " + (updated_count as string) + " | Frozen in gray: true")
		)
		else
		(
			setStatus ("Unfrozen class nodes: " + (updated_count as string))
		)

		updated_count -- return
	),

	/* Handle Hide button mouse event.
	LMB hides effective classes, RMB shows effective classes.
	*/
	function handleHideMouseButton mouse_button =
	(
		left_button = (dotNetClass "System.Windows.Forms.MouseButtons").Left
		right_button = (dotNetClass "System.Windows.Forms.MouseButtons").Right

		if (mouse_button == left_button) then
		(
			setEffectiveClassesHidden true
		)
		else if (mouse_button == right_button) then
		(
			setEffectiveClassesHidden false
		)

		true -- return
	),

	/* Handle Freeze button mouse event.
	LMB freezes effective classes, RMB unfreezes effective classes.
	*/
	function handleFreezeMouseButton mouse_button =
	(
		left_button = (dotNetClass "System.Windows.Forms.MouseButtons").Left
		right_button = (dotNetClass "System.Windows.Forms.MouseButtons").Right

		if (mouse_button == left_button) then
		(
			setEffectiveClassesFrozen true
		)
		else if (mouse_button == right_button) then
		(
			setEffectiveClassesFrozen false
		)

		true -- return
	),

	/* Toggle ignored state for selected listbox classes.
	Ignored classes remain visible but are skipped by actions.
	*/
	function toggleIgnoreForSelectedClasses =
	(
		selected_indices = getSelectedClassIndices()

		if (selected_indices.count == 0) then
		(
			setStatus "Select class rows first."
		)
		else
		(
			ignored_count = 0
			used_count = 0

			for class_index in selected_indices do
			(
				class_key = class_keys[class_index]
				ignored_index = findItem ignored_class_keys class_key

				if (ignored_index > 0) then
				(
					deleteItem ignored_class_keys ignored_index
					used_count += 1
				)
				else
				(
					append ignored_class_keys class_key
					ignored_count += 1
				)
			)

			saveIgnoredValues()
			populateClassListbox preserve_selection:true
			TransformLockClassManager.updateUi()
			setStatus ("Ignore toggled | Ignored: " + (ignored_count as string) + " | Unignored: " + (used_count as string))
		)

		true -- return
	),

	/* Update listbox selection from current scene selection.
	No selected objects means empty listbox selection and global mode.
	*/
	function updateListboxSelectionByCurrentSelection =
	(
		if (ui_is_updating == false) then
		(
			try
			(
				current_nodes = selection as array
				class_indices = getClassIndicesFromNodes current_nodes
				selected_flags = #{}

				for class_index in class_indices do
				(
					selected_flags[class_index] = true
				)

				TransformLockClassManager_ui.lbx_classes.selection = selected_flags
				TransformLockClassManager.updateUi()
			)
			catch
			(
			)
		)

		true -- return
	),

	/* Update all colored lock buttons from effective classes.
	Empty listbox selection means global mode and uses all non-ignored classes.
	*/
	function updateUi =
	(
		ui_is_updating = true

		class_indices = getEffectiveClassIndices()

		for transform_index = 1 to 3 do
		(
			all_button = getAllButtonControl transform_index

			if (all_button != undefined) then
			(
				setColorButtonState all_button (getMixedLockState transform_index 0 class_indices) transform_names[transform_index]
			)

			for axis_index = 1 to 3 do
			(
				axis_button = getAxisButtonControl transform_index axis_index

				if (axis_button != undefined) then
				(
					setColorButtonState axis_button (getMixedLockState transform_index axis_index class_indices) axis_names[axis_index]
				)
			)
		)

		if (isGlobalMode()) then
		(
			setStatus ("Global mode: all non-ignored classes | Classes: " + (class_names.count as string) + " | Section: " + getSceneSectionName())
		)
		else
		(
			setStatus ("Selected classes | Section: " + getSceneSectionName())
		)

		ui_is_updating = false

		true -- return
	),

	/* Get next boolean value from lock state.
	Unlocked and mixed click to locked. Locked clicks to unlocked.
	*/
	function getNextLockValue transform_index axis_index =
	(
		class_indices = getEffectiveClassIndices()
		current_state = getMixedLockState transform_index axis_index class_indices
		next_value = true

		if (current_state == 1) then
		(
			next_value = false
		)

		next_value -- return
	),

	/* Toggle one transform axis from colored button.
	Empty listbox selection means set all non-ignored classes.
	*/
	function toggleAxisFromButton transform_index axis_index =
	(
		if (ui_is_updating == false) then
		(
			class_indices = getEffectiveClassIndices()
			next_value = getNextLockValue transform_index axis_index

			for class_index in class_indices do
			(
				flag_index = getFlagIndex transform_index axis_index
				values[class_index][flag_index] = next_value
			)

			saveValues()
			applyEffectiveClassesToScene()
			TransformLockClassManager.updateUi()
		)

		true -- return
	),

	/* Toggle whole transform row from colored All button.
	Empty listbox selection means set all non-ignored classes.
	*/
	function toggleAllFromButton transform_index =
	(
		if (ui_is_updating == false) then
		(
			class_indices = getEffectiveClassIndices()
			next_value = getNextLockValue transform_index 0

			for class_index in class_indices do
			(
				for axis_index = 1 to 3 do
				(
					flag_index = getFlagIndex transform_index axis_index
					values[class_index][flag_index] = next_value
				)
			)

			saveValues()
			applyEffectiveClassesToScene()
			TransformLockClassManager.updateUi()
		)

		true -- return
	),

	/* Setup all dotNet buttons.
	Called on rollout open.
	*/
	function setupUiButtons =
	(
		setupColorButton TransformLockClassManager_ui.dn_pos_all "Position"
		setupColorButton TransformLockClassManager_ui.dn_rot_all "Rotation"
		setupColorButton TransformLockClassManager_ui.dn_scl_all "Scale"

		setupColorButton TransformLockClassManager_ui.dn_pos_x "X"
		setupColorButton TransformLockClassManager_ui.dn_pos_y "Y"
		setupColorButton TransformLockClassManager_ui.dn_pos_z "Z"

		setupColorButton TransformLockClassManager_ui.dn_rot_x "X"
		setupColorButton TransformLockClassManager_ui.dn_rot_y "Y"
		setupColorButton TransformLockClassManager_ui.dn_rot_z "Z"

		setupColorButton TransformLockClassManager_ui.dn_scl_x "X"
		setupColorButton TransformLockClassManager_ui.dn_scl_y "Y"
		setupColorButton TransformLockClassManager_ui.dn_scl_z "Z"

		setupActionButton TransformLockClassManager_ui.dn_btn_hide "LMB Hide | RMB Show"
		setupActionButton TransformLockClassManager_ui.dn_btn_freeze "LMB Freeze | RMB Unfreeze"

		true -- return
	),

	/* Create test scene nodes.
	Test code does not delete current scene objects.
	*/
	function createTestScene =
	(
		box name:"TLCM_Geometry_Box" pos:[0, 0, 0]
		sphere name:"TLCM_Geometry_Sphere" pos:[40, 0, 0]
		circle name:"TLCM_Shape_Circle" pos:[80, 0, 0]
		dummy name:"TLCM_Helper_Dummy" pos:[120, 0, 0]

		group_box_a = box name:"TLCM_Group_Box_A" pos:[0, 40, 0]
		group_box_b = box name:"TLCM_Group_Box_B" pos:[40, 40, 0]
		group #(group_box_a, group_box_b) name:"TLCM_Group"

		true -- return
	),

	/* Open manager rollout.
	Loads scene classes, stored values, applies them, and enables callbacks.
	*/
	function openRollout =
	(
		try
		(
			destroyDialog TransformLockClassManager_ui
		)
		catch
		(
		)

		createDialog TransformLockClassManager_ui width:560 height:216 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)

		updateUiByScene apply_locks:true preserve_selection:false source_name:"Tool open"
		registerCallbacks()
		updateListboxSelectionByCurrentSelection()

		true -- return
	),

	on create do
	(
		initValues()
	)
)

rollout TransformLockClassManager_ui "Transform Lock Class Manager 0.17" width:560 height:216
(
	multiListBox lbx_classes "" pos:[8, 8] width:170 height:8 items:#()
	button btn_ignore "Ignore / Unignore" pos:[8, 136] width:170 height:24 tooltip:"Toggle selected scene classes between used and ignored."

	dotNetControl dn_pos_all "System.Windows.Forms.Button" pos:[205, 24] width:115 height:30
	dotNetControl dn_pos_x "System.Windows.Forms.Button" pos:[340, 24] width:32 height:30
	dotNetControl dn_pos_y "System.Windows.Forms.Button" pos:[390, 24] width:32 height:30
	dotNetControl dn_pos_z "System.Windows.Forms.Button" pos:[440, 24] width:32 height:30

	dotNetControl dn_rot_all "System.Windows.Forms.Button" pos:[205, 60] width:115 height:30
	dotNetControl dn_rot_x "System.Windows.Forms.Button" pos:[340, 60] width:32 height:30
	dotNetControl dn_rot_y "System.Windows.Forms.Button" pos:[390, 60] width:32 height:30
	dotNetControl dn_rot_z "System.Windows.Forms.Button" pos:[440, 60] width:32 height:30

	dotNetControl dn_scl_all "System.Windows.Forms.Button" pos:[205, 96] width:115 height:30
	dotNetControl dn_scl_x "System.Windows.Forms.Button" pos:[340, 96] width:32 height:30
	dotNetControl dn_scl_y "System.Windows.Forms.Button" pos:[390, 96] width:32 height:30
	dotNetControl dn_scl_z "System.Windows.Forms.Button" pos:[440, 96] width:32 height:30

	dotNetControl dn_btn_hide "System.Windows.Forms.Button" pos:[205, 134] width:115 height:28
	dotNetControl dn_btn_freeze "System.Windows.Forms.Button" pos:[340, 134] width:132 height:28

	label lb_status "" pos:[8, 194] width:540 height:16

	on TransformLockClassManager_ui open do
	(
		TransformLockClassManager.setupUiButtons()
		TransformLockClassManager.updateUiByScene apply_locks:false preserve_selection:false source_name:"Rollout open"
	)

	on lbx_classes selected item_index do
	(
		TransformLockClassManager.updateUi()
	)

	on btn_ignore pressed do
	(
		TransformLockClassManager.toggleIgnoreForSelectedClasses()
	)

	on dn_btn_hide MouseDown mouse_event do
	(
		TransformLockClassManager.handleHideMouseButton mouse_event.button
	)

	on dn_btn_freeze MouseDown mouse_event do
	(
		TransformLockClassManager.handleFreezeMouseButton mouse_event.button
	)

	on dn_pos_all MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAllFromButton 1
	)

	on dn_rot_all MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAllFromButton 2
	)

	on dn_scl_all MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAllFromButton 3
	)

	on dn_pos_x MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 1 1
	)

	on dn_pos_y MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 1 2
	)

	on dn_pos_z MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 1 3
	)

	on dn_rot_x MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 2 1
	)

	on dn_rot_y MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 2 2
	)

	on dn_rot_z MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 2 3
	)

	on dn_scl_x MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 3 1
	)

	on dn_scl_y MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 3 2
	)

	on dn_scl_z MouseDown mouse_event do
	(
		TransformLockClassManager.toggleAxisFromButton 3 3
	)
)


/* Test code.
Run after script is loaded.
*/
-- TransformLockClassManager.createTestScene()
-- TransformLockClassManager.updateUiByScene apply_locks:false preserve_selection:false source_name:"Manual test refresh"
-- TransformLockClassManager.class_names
-- TransformLockClassManager_ui.lbx_classes.items
-- for scene_node in objects collect #(scene_node.name, TransformLockClassManager.getNodeClassKey scene_node)

-- Select some objects and listbox should switch to their exact baseObject classes.
-- select (for scene_node in objects where (isValidNode scene_node and TransformLockClassManager.getNodeClassKey scene_node == "Box") collect scene_node)
-- TransformLockClassManager.updateListboxSelectionByCurrentSelection()

-- Empty selection means global mode.
-- clearSelection()
-- TransformLockClassManager.updateListboxSelectionByCurrentSelection()

-- New objects should add their classes and receive stored class transform locks.
-- teapot name:"TLCM_Callback_Test_Teapot"
-- TransformLockClassManager.class_names
-- getTransformLockFlags $TLCM_Callback_Test_Teapot

-- Ignore button:
-- Select class rows in listbox, then press Ignore / Unignore.

-- Hide button:
-- LMB = hide effective class nodes.
-- RMB = show effective class nodes.

-- Freeze button:
-- LMB = freeze effective class nodes and show them gray.
-- RMB = unfreeze effective class nodes.

-- Stop callbacks manually when needed.
-- TransformLockClassManager.unregisterCallbacks()
)
