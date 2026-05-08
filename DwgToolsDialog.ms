clearListener(); print("Cleared in:\n"+getSourceFileName())

/* UI FRAMEWORK */
filein( getFilenamePath(getSourceFileName()) + "/../MAXSCRIPT-UI-framework/Lib/Dialog/Dialog.ms" )	--"./../MAXSCRIPT-UI-framework/Lib/Dialog/Dialog.ms"



/** Addd keywords to
 */
function adddKeywordsTo _Controls keyword keywords width:256 level:0 id: =
(
	--format "\n"; print ".adddKeywordsTo()"
	
	keyword	= ( dotNetObject "System.Text.RegularExpressions.Regex" "[\\s\\-_]+" ).Replace keyword "_"
	
	if id == unsupplied then 
		id = "CBTN"
	
	id += "_" + keyword
	
	id	= ( dotNetObject "System.Text.RegularExpressions.Regex" "_+" ).Replace id "_"

		
	width = width - ( level * 24 )

	format "ID: %\n" id
	_checkbutton = _Controls.control #CHECKBUTTON keyword across:1 width:width id:id align:#RIGHT checked:true --highlightColor:red
	
	_checkbutton.Event #CHANGED "layerToggleCallback"
	
	for keyword in keywords.keys do
		adddKeywordsTo _Controls keyword keywords[keyword] width:width level:(level +1) id:id

		
)

	
/** Create dwg tools dialog
 */
function dwgToolsDialog Dialog: width: =
(
	format "\n"; print ".dwgToolsDialog()"
	format "Dialog: %\n" Dialog
	format "width: %\n" width


	/* SETUP */
	ini_files = LAYER_MANAGER_APP.getIniFiles()
	format "ini_files: %\n" ini_files
	
	/* DIALOG */
	if Dialog == undefined then 
		Dialog 	    = Dialog_v ("DwgTools") width:width debug:true --ini:(getSourceFileName()) 
	
	/* DIALOG CONTROLS */ 
	_Controls   = Dialog.Controls group:("Main Controls")
	
	--_Button     = _Controls.control #button "2. Clean Unmatched Layers" across:1 width:256

	dd_presets = _Controls.control #DROPDOWN "Presets"  items:( for ini_file in ini_files collect getFilenameFile ini_file )

	--for prop in getPropNames dd_presets do format "%: %\n" prop (getProperty dd_presets prop)
	
	dd_presets.printProps()
	
	edit_1 = _Controls.control #EDITTEXT "Ini Name" --value:( dd_presets.getFullId() + ".items[1]" ) across:1
	--edit_2 = _Controls.control #EDITTEXT "Ini Name TEST" across:1
	
	btn_save_preset = _Controls.control #button "Save Preset" across:1 width:256
	btn_load_preset = _Controls.control #button "Load Preset" across:1 width:256
	
	
	/* IF SELECTED OF DROPDOWN ITEM, THEN UPDATE EDIT TEXT */ 	
	dd_presets.Event #SELECTED (edit_1.getFullId() + ".text = "+dd_presets.getFullId() + ".items[val]; LAYER_MANAGER_APP.changeIni val")
	
	/* FIND WRITTEN ITEM IN DROPDOWN */ 
	edit_1.Event #CHANGED ( dd_presets.getFullId() + ".selection = findItem ("+dd_presets.getFullId() + ".items) val")

	
	btn_save_preset.Event #PRESSED "tv_rollout.saveStateToIni layer_manager_app.current_ini_path"
	btn_load_preset.Event #PRESSED "tv_rollout.loadStateFromIni layer_manager_app.current_ini_path"
	
	
	LayerKeywordManager = LayerKeywordManager_v()

	LAYER_NAMES_KEYWORDS = LayerKeywordManager.splitLayerNamesByKeywords()

	--for key in LAYER_NAMES_KEYWORDS.keys do format "key: % \nVALUE: %\n\n" key LAYER_NAMES_KEYWORDS[key]

	/* ROLLOUTS */
	_Rollouts	 = Dialog.Rollouts height:1024
	
	
	/* RETURN DIALOG */ 
	--Dialog --return
	--Dialog.create height:undefined --width:dialog_width
	--Dialog.create height:1280
	Dialog.create height:1600
	
	/*------------------------------------------------------------------------------
		TREE VIEW
	--------------------------------------------------------------------------------*/
	layerTreeGenerator()
	--format "tv_rollout: %\n" tv_rollout
	AddSubRollout DIALOG_dwgtools.subrollouts_1 tv_rollout
	
)

