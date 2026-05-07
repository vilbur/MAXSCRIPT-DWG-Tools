
struct LayerManagerApp
(
	exporter = LayerExporter(),
	cleaner = LayerCleaner(),
	
	current_ini_path = "",
	ini_dir = "",
	ini_files = #(),

	/** Get ini files
	 */
	function getIniFiles =
	(
		--format "\n"; print "LayerManagerApp.getIniFiles()"
		ini_dir = maxfilepath
		if ini_dir == "" do ini_dir = (getDir #temp + "\\")
		
		if current_ini_path == "" do current_ini_path = exporter.getIniFilePath()
		
		ini_files = getFiles (ini_dir + "*.ini")
		
		if ini_files.count == 0 do append ini_files current_ini_path
		
		ini_files --return
	),
	
	
	fn getKeywordColor kw =
	(
		local best_color = color 128 128 128
		local max_count = -1
		
		for i = 0 to (layerManager.count - 1) do
		(
			local l = layerManager.getLayer i
			if matchPattern l.name pattern:("*" + kw + "*") ignoreCase:true do
			(
				l.nodes &nds
				local node_count = if nds != undefined then nds.count else 0
				
				-- If this layer has more objects than the previous best match, steal its color
				if node_count > max_count do
				(
					max_count = node_count
					best_color = l.wirecolor
				)
			)
		)
		
		return best_color
	),

	fn selectKeywordObjects kw =
	(
		local objs = #()
		for i = 0 to (layerManager.count - 1) do
		(
			local l = layerManager.getLayer i
			if matchPattern l.name pattern:("*" + kw + "*") ignoreCase:true do
			(
				l.nodes &nds
				if nds != undefined do join objs nds
			)
		)
		
		if keyboard.controlPressed then selectmore objs
		else if keyboard.altPressed then deselect objs
		else select objs
	),

	fn initUi =
	(
		local ddl_items = for f in ini_files collect (getFilenameFile f)
		rlt_layer_manager.ddl_inis.items = ddl_items
		
		local sel_idx = 0
		for i = 1 to ini_files.count do (
			if stricmp ini_files[i] current_ini_path == 0 do sel_idx = i
		)
		if sel_idx > 0 do rlt_layer_manager.ddl_inis.selection = sel_idx
		rlt_layer_manager.et_ini_name.text = getFilenameFile current_ini_path
	),

	-- Defining showUi BEFORE changeIni to fix the scope bug
	fn showUi =
	(
		ini_dir = maxfilepath
		if ini_dir == "" do ini_dir = (getDir #temp + "\\")
		
		if current_ini_path == "" do current_ini_path = exporter.getIniFilePath()
		
		ini_files = getFiles (ini_dir + "*.ini")
		if ini_files.count == 0 do append ini_files current_ini_path
		
		local keys = #()
		if doesFileExist current_ini_path do
		(
			local key_names = getINISetting current_ini_path "Keywords"
			for k in key_names do append keys (getINISetting current_ini_path "Keywords" k)
		)
		
		local r_str = "rollout rlt_layer_manager \"INI Keyword Manager\" width:320 (\n"
		
		r_str += "  button btn_export \"1. Export Layers to INI\" width:300 height:30 offset:[0,5]\n"
		r_str += "  button btn_clean \"2. Clean Unmatched Layers\" width:300 height:30\n"
		r_str += "  label lbl_div1 \"-------------------------------------------------------------\" offset:[0,5]\n"
		r_str += "  dropdownlist ddl_inis \"INI Files in Directory:\" width:300\n"
		r_str += "  edittext et_ini_name \"INI Name:\" width:300\n"
		r_str += "  button btn_save \"Save Keywords & Rename\" width:300 height:30 offset:[0,5]\n"
		r_str += "  label lbl_div2 \"-------------------------------------------------------------\" offset:[0,5]\n"
		
		r_str += "  group \"Keywords\" (\n"
		
		for i = 1 to keys.count do
		(
			local kw = keys[i]
			local matched_layers = #()
			
			-- Count how many layers match this keyword
			for j = 0 to (layerManager.count - 1) do
			(
				local l_name = (layerManager.getLayer j).name
				if matchPattern l_name pattern:("*" + kw + "*") ignoreCase:true do append matched_layers l_name
			)
			
			-- If only one layer matches, use the full layer name instead
			if matched_layers.count == 1 do kw = matched_layers[1]
			
			local i_str = i as string
			-- Adjusted layout parameters to fit perfectly within the 300px Group boundary
			r_str += "    bitmap bmp_" + i_str + " width:16 height:16 across:3 align:#left offset:[5,3]\n"
			r_str += "    button btn_sel_" + i_str + " \"S\" width:20 height:20 align:#left offset:[-10,0] tooltip:\"Ctrl: Add | Alt: Remove | Keyword: " + kw + "\"\n"
			r_str += "    edittext et_" + i_str + " \"\" width:235 align:#left text:\"" + kw + "\" offset:[-30,0]\n"
		)
		r_str += "  )\n"
		
		r_str += "  on btn_export pressed do ( layer_manager_app.exporter.exportToIni layer_manager_app.current_ini_path; layer_manager_app.showUi() )\n"
		r_str += "  on btn_clean pressed do ( layer_manager_app.cleaner.moveUnmatchedLayers layer_manager_app.current_ini_path )\n"
		
		-- Two-way linking between dropdown and edit text
		r_str += "  on ddl_inis selected idx do ( et_ini_name.text = ddl_inis.items[idx]; layer_manager_app.changeIni idx )\n"
		r_str += "  on et_ini_name changed txt do ( local idx = findItem ddl_inis.items txt; if idx > 0 do ddl_inis.selection = idx )\n"
		
		r_str += "  on btn_save pressed do (\n"
		r_str += "    local new_path = layer_manager_app.ini_dir + et_ini_name.text + \".ini\"\n"
		r_str += "    if doesFileExist new_path do delIniSetting new_path \"Keywords\"\n"
		for i = 1 to keys.count do (
			r_str += "    if et_" + i as string + ".text != \"\" do setINISetting new_path \"Keywords\" (\"Key_" + i as string + "\") et_" + i as string + ".text\n"
		)
		r_str += "    layer_manager_app.current_ini_path = new_path\n"
		r_str += "    layer_manager_app.showUi()\n"
		r_str += "  )\n"
		
		for i = 1 to keys.count do (
			r_str += "  on btn_sel_" + i as string + " pressed do ( layer_manager_app.selectKeywordObjects et_" + i as string + ".text )\n"
		)
		
		r_str += "  on rlt_layer_manager open do (\n"
		r_str += "    layer_manager_app.initUi()\n"
		for i = 1 to keys.count do (
			r_str += "    bmp_" + i as string + ".bitmap = bitmap 16 16 color:(layer_manager_app.getKeywordColor et_" + i as string + ".text)\n"
		)
		r_str += "  )\n"
		r_str += ")\n"
		
		try(destroyDialog rlt_layer_manager) catch()
		global rlt_layer_manager = execute r_str
		createDialog rlt_layer_manager style:#(#style_titlebar, #style_border, #style_sysmenu, #style_resizing)
	),

	-- Placed here so showUi() is already defined in scope
	fn changeIni idx =
	(
		if idx > 0 and idx <= ini_files.count do
		(
			current_ini_path = ini_files[idx]
			showUi() 
		)
	)
)

-- Launch UI
--layer_manager_app.showUi()