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

	--format "ID: %\n" id
	_checkbutton = _Controls.control #CHECKBUTTON keyword across:1 width:width id:id align:#RIGHT checked:true --highlightColor:red
	
	_checkbutton.Event #CHANGED "layerToggleCallback"
	
	for keyword in keywords.keys do
		adddKeywordsTo _Controls keyword keywords[keyword] width:width level:(level +1) id:id

		
)

	
/** Create dwg tools dialog
 */
function dwgToolsDialog Dialog: width: =
(
	--format "\n"; print ".dwgToolsDialog()"
	--format "Dialog: %\n" Dialog
	--format "width: %\n" width

	dialog_height = (getMAXWindowSize()).y - 256

	/* SETUP */
	ini_files = LAYER_MANAGER_APP.getIniFiles()
	--format "ini_files: %\n" ini_files
	
	/* DIALOG */
	if Dialog == undefined then 
		Dialog 	    = Dialog_v ("DwgTools") width:width height:dialog_height debug:true --ini:(getSourceFileName()) 
	
	/*------------------------------------------------------------------------------
		PRESET CONTROLS
	--------------------------------------------------------------------------------*/
	_Controls   = Dialog.Controls group:("LAYERS PRESET")
	
	
	preset_name = _Controls.control #EDITTEXT "[Ini Name]" --value:( preset_list.getFullId() + ".items[1]" ) across:1
	preset_list = _Controls.control #DROPDOWN "[Presets List]"  items:( for ini_file in ini_files collect getFilenameFile ini_file )

	--preset_list.printProps()
	
	--btn_preset_TEST = _Controls.control #BUTTON "TEST" across:1 width:256 height:32
	--btn_preset_TEST.Event #PRESSED "tv_rollout.setMixedItemsVisibility false"
	--format "btn_preset_TEST: %\n" btn_preset_TEST
	
	--_Controls.Defaults #(#across, 3, #width, 96 ) type:#BUTTON
	_Controls.Default #across 3 type:#BUTTON
	_Controls.Default #width 72 type:#BUTTON
	
	btn_preset_save = _Controls.control #BUTTON "Save Preset" --across:1 width:48
	btn_preset_load = _Controls.control #BUTTON "Load Preset" --across:1 width:48
	btn_preset_delete = _Controls.control #BUTTON "Delete Preset" --across:1 width:48
	
	/* IF SELECTED OF DROPDOWN ITEM, THEN UPDATE EDIT TEXT */ 	
	callback_load_preset = "LAYER_MANAGER_APP.loadStateFromIni ( " + preset_list.getFullId() + ".selection )"
	
	preset_list.Event #SELECTED (preset_name.getFullId() + ".text = "+preset_list.getFullId() + ".items[val]; LAYER_MANAGER_APP.changeIni val;"+callback_load_preset)
	
	/* FIND WRITTEN ITEM IN DROPDOWN */
	
	preset_name.Event #CHANGED ( preset_list.getFullId() + ".selection = findItem ("+preset_list.getFullId() + ".items) val")

	btn_preset_save.Event	#PRESSED ("LAYER_MANAGER_APP.saveStateToIni(" + preset_name.getFullId() + ".text )")
	btn_preset_load.Event	#PRESSED ( callback_load_preset )
	btn_preset_delete.Event	#PRESSED ("LAYER_MANAGER_APP.deleteIniFile()")
	
	
	_Rollouts	 = Dialog.Rollouts height:1024


	--for key in LAYER_NAMES_KEYWORDS.keys do format "key: % \nVALUE: %\n\n" key LAYER_NAMES_KEYWORDS[key]

	/* ROLLOUTS */
	_Rollout_cfg	 = _Rollouts.Roll "Layer Names Config"
	
	/*------------------------------------------------------------------------------
		LAYER NAME CONTROLS
	--------------------------------------------------------------------------------*/
	_Controls_cfg   = _Rollout_cfg.Controls() --group:("LAYER NAMES CONFIG") 

	_Controls_cfg.Default #fieldWidth	128	type:#EDITTEXT
	_Controls_cfg.Default #offset	[ -64, 0]	type:#EDITTEXT
	

	btn_word_delimeter	= _Controls_cfg.control #EDITTEXT "Word Delimeter"	value:"\\s+" --fieldWidth:128
	btn_prefix_match	= _Controls_cfg.control #EDITTEXT "Prefix Match"	value:"[0-9a-zA-Z]+" --fieldWidth:128
	
	
	
	
	
	/* RETURN DIALOG */ 
	--Dialog --return
	--Dialog.create height:undefined --width:dialog_width
	--Dialog.create height:1280
	Dialog.create height:dialog_height

	LAYER_MANAGER_APP.Controls [#ROLLOUT]	= tv_rollout
	
	LAYER_MANAGER_APP.addControl #DD_PRESETS 	preset_list
	LAYER_MANAGER_APP.addControl #btn_preset_save 	btn_preset_save
	LAYER_MANAGER_APP.addControl #btn_preset_load 	btn_preset_load
	LAYER_MANAGER_APP.addControl #btn_preset_delete 	btn_preset_delete
	
	LAYER_MANAGER_APP.addControl #btn_word_delimeter 	btn_word_delimeter
	LAYER_MANAGER_APP.addControl #btn_prefix_match 	btn_prefix_match
	
	
	/*------------------------------------------------------------------------------
		TREE VIEW
	--------------------------------------------------------------------------------*/
	
	
	LayerKeywordManager = LayerKeywordManager_v()

	LAYER_NAMES_KEYWORDS = LayerKeywordManager.splitLayerNamesByKeywords()
	
	--layerTreeGenerator( dialog_height  )
	layerTreeGenerator()
	
	
	--format "tv_rollout: %\n" tv_rollout
	AddSubRollout DIALOG_dwgtools.subrollouts_1 tv_rollout
	
	format "DIALOG_dwgtools.subrollouts_1.ROLLOUT_layer_names_config.height: %\n" DIALOG_dwgtools.subrollouts_1.ROLLOUT_layer_names_config.height
	
	rollout_height = dialog_height - DIALOG_dwgtools.subrollouts_1.pos.y - DIALOG_dwgtools.subrollouts_1.ROLLOUT_layer_names_config.height - 52
	
	format "dialog_height: %\n" dialog_height
	format "rollout_height: %\n" rollout_height
	tv_rollout.height = rollout_height
	tv_rollout.tv.height = tv_rollout.height - 16
	
)

