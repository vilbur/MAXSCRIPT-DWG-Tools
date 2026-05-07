clearListener(); print("Cleared in:\n"+getSourceFileName())

/* UI FRAMEWORK */
filein( getFilenamePath(getSourceFileName()) + "/../MAXSCRIPT-UI-framework/Lib/Dialog/Dialog.ms" )	--"./../MAXSCRIPT-UI-framework/Lib/Dialog/Dialog.ms"


/** Layer toggle callback
 */
function layerToggleCallback state item_id =
(
	format "\n"; print ".layerToggleCallback()"
	format "state: %\n" state
	--format "EventFired: %\n" EventFired
    format "Callback Triggered -> State: % | Item ID: %\n" state item_id

	/** Join array to string
	 */
	function arrayToString arr delimeter = ( _string = ""; for item in arr do _string += item as string  + delimeter; substring _string 1 (_string.count-delimeter.count))
	
	id_split	= filterString item_id "_"
	
	--deleteItem id_split 1

	ignore_prefix = ignore_sufix = "*"
	pattern = arrayToString id_split "*"
	
	format "PATTERN: %\n" pattern
	
	
	for i = 0 to LayerManager.count - 1 where (layer = LayerManager.getLayer i) != undefined do
	(
		
		if matchPattern layer.name pattern:( ignore_prefix + pattern + ignore_sufix ) then
			layer.on = state
			--format "LAYER: %\n" layer.name
		
	)
)
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
	
	
	/* DIALOG */
	if Dialog == undefined then 
		Dialog 	    = Dialog_v ("DwgTools") width:width debug:true --ini:(getSourceFileName()) 
	
	/* DIALOG CONTROLS */ 
	_Controls   = Dialog.Controls group:("Main Controls")
	
	_Button     = _Controls.control #button "1. Export Layers" across:1 width:256
	_Button     = _Controls.control #button "2. Clean Unmatched Layers" across:1 width:256

	_Controls.control #DROPDOWN "Dropdown"  items:( for ini_file in ini_files collect getFilenameFile ini_file )

	_Controls.control #EDITTEXT "Ini Name" value:(getFilenameFile ini_files[1]) across:1
	
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
	
	AddSubRollout DIALOG_dwgtools.subrollouts_1 tvRollout
	
)

