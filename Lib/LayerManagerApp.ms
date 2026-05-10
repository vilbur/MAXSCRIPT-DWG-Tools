
struct LayerManagerApp
(
	exporter = LayerExporter(),
	cleaner = LayerCleaner(),
	
	Controls	= Dictionary #NAME, -- KEY: VALUE:
	
	current_ini_path = "",
	ini_dir = "",
	ini_files = #(),

	/** Get ini files
	 */
	function getIniFiles =
	(
		--format "\n"; print "LayerManagerApp.getIniFiles()"
		ini_dir = maxFilePath
		
		if ini_dir == "" then
			ini_dir = (getDir #temp + "\\")
		
		if current_ini_path == "" then
			current_ini_path = exporter.getIniFilePath()
		
		ini_files = sort ( getFiles (ini_dir + "*.ini"))
		
		if ini_files.count == 0 then
			append ini_files current_ini_path

		--format "ini_dir: %\n" ini_dir
		ini_files --return
	),
	
	/** Add control
	 */
	function addControl key _Control_v =
	(
		--format "\n"; print "LayerManagerApp.addControl()"
		
		this.Controls[ key ] = execute ( _Control_v.getFullId() )
	),
	
	function changeIni idx =
	(
		if idx > 0 and idx <= ini_files.count do
		(
			current_ini_path = ini_files[idx]
			--showUi() 
		)
	),
	
	/** Update ini file name
	 */
	function updateIniFileName filename =
	(
		--format "\n"; print "LayerManagerApp.updateIniFileName()"
		this._setIniPath (filename_new)
	),
	
	/** DELETE INI FILE
	 */
	function deleteIniFile =
	(
		--format "\n"; print "LayerManagerApp.deleteIniFile()"
		if queryBox ( "DELETE Preset ?\n\n" + getFilenameFile ( current_ini_path ) ) title:( "DELETE PRESET") then
			if ( index = findItem ini_files current_ini_path ) > 0 then
			(
				deleteItem ini_files index
				
				
				prev_index = index - 1
				
				this.changeIni(prev_index)
				
				this.Controls[ #DD_PRESETS ].items	= sort( for ini_file in ini_files collect getFilenameFile ini_file )
				this.Controls[ #DD_PRESETS ].selection	= if prev_index > 0 then prev_index else 1
				
				deleteFile current_ini_path
			)
	),
	
	/** SAVE INI STATE
	 */
	function saveStateToIni filename =
	(
		format "\n"; print "LayerManagerApp.saveStateToIni()"
		format "this.Controls[ #ROLLOUT ]: %\n" (this.Controls[ #ROLLOUT ])
		--format "filename: %\n" filename
		--format "ini_dir: %\n" ini_dir
		
		filename_new = trimRight (trimLeft filename)
		
		if filename_new.count > 0 then 
			this._setIniPath (filename_new)
		
		
		save_or_update = if filename_new.count > 0 then "SAVE NEW" else "UPDADTE" 
			
		if queryBox ( save_or_update + " Preset ?\n\n" + getFilenameFile ( current_ini_path ) ) title:( save_or_update + " PRESET")  then
			tv_rollout.saveStateToIni this.current_ini_path
		
	),
	

	/** LOAD INI STATE
	 */
	function loadStateFromIni selected_inifile =
	(
		format "\n"; print "LayerManagerApp.loadStateFromIni()"
		--format "ini_dir: %\n" ini_dir
		--format "current_ini_path: %\n" current_ini_path
		/** Get layer names mask
		 */
		function getLayerNamesMask items_ids =
		(
			format "items_ids: %\n" items_ids
			/** Join array to string
			 */
			fn arrayToString arr delimeter = ( _string = ""; for item in arr do _string += item as string  + delimeter; substring _string 1 (_string.count-delimeter.count))
			
			--format "\n"; print "LayerManagerApp.getLayerNamesMask()"
			layers_masks = for items_id in items_ids collect substituteString items_id "_" "."

			"("+(arrayToString layers_masks "|") +")" -- return
		)
		
		/** Is mask matching
		 */
		function isMaskMatching layer_name layers_masks =
		(
			--format "\n"; print "LayerManagerApp.isMaskMatching()"
			regex_options = dotNetClass "System.Text.RegularExpressions.RegexOptions"
			regex_class = dotNetClass "System.Text.RegularExpressions.Regex"
			
			is_enabled = regex_class.IsMatch layer_name layers_masks regex_options.IgnoreCase
		)
		
		
		if selected_inifile > 0 then
		(

			--this.current_ini_path = ini_dir + ini_files[selected_inifile] + ".ini"
			this._setIniPath (ini_files[selected_inifile] )

			--format "this.current_ini_path: %\n" this.current_ini_path
	
			/*------------------------------------------------------------------------------
				SET LAYERS STATE
			--------------------------------------------------------------------------------*/
			
			/* GET REGEX MASKS */ 
			mask_enabled = getLayerNamesMask (tv_rollout.getItemsByState 1)
			mask_mixed   = getLayerNamesMask (tv_rollout.getItemsByState 2)
			format "mask_enabled: %\n" mask_enabled
			format "mask_mixed: %\n" mask_mixed
			/* GET ALL LAYERS */ 
			all_layers = for i = 0 to LayerManager.count - 1 where (layer = LayerManager.getLayer i) != undefined collect layer

			/* RESET LAYERS STATE - HIDE & UNFREEZE ALL LAYERS */ 			
			for layer in all_layers do
			(
				layer.on = false
				
				--layer.isfrozen = false
			)
			
			/*------------------------------------------------------------------------------
				LOAD STATE FROM INI
			--------------------------------------------------------------------------------*/
			tv_rollout.loadStateFromIni (this.current_ini_path)
			
			/* MANAGE EACH LAYER */ 
			for layer in all_layers do
			(
				/* SHOW \ HIDE LAYER */
				
				--if mask_enabled.count > 0 then
					--layer.on = isMaskMatching layer.name mask_enabled

				--if mask_mixed.count > 0 then
					--layer.isfrozen = isMaskMatching layer.name mask_mixed

				--if is_frozen then
				--(
				--	format "\n"
					--format "layer.name: %\n" layer.name
				--	--format "is_enabled: %\n" is_enabled
				--	format "is_frozen: %\n" is_frozen
				--	
				--)
			)
		)
		else /* MESSAGE IF MISSING PRESET NAME */ 
			messageBox "Select some preset from dropdown menu" title:"PRESET NOT SELECTED" 
	),
	
	
	function getKeywordColor kw =
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

	function selectKeywordObjects kw =
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

	function initUi =
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
	function showUi =
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
	private
	
	
	/** Get ini path
	 */
	function _setIniPath filename =
	(
		this.current_ini_path = ini_dir + (getFilenameFile ( filename )) + ".ini"
	),

	/**
	 */
	on create do
	(
		--format "\n"; print "LayerManagerApp.onCreate()"
		--for prop in #(  ) where getProperty this prop == undefined do -- CHECK CONSTRUCT PROPERTIES -- Array of this struct properties necessary to run
		--	throw ("\n\n\nUNDEFINED CONSTRUCT PROPERTY\n\n\nSTRUCT:\n\n"+ ((filterString( classof this as string )"(:")[2]) +"\n\n\nPROPERTY:\n\n"+ prop )
	)

)

-- Launch UI
--layer_manager_app.showUi()
