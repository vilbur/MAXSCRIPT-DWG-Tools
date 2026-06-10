/* DwgTools.ms
   Launcher rollout for macros from DwgTools.mcr.
*/
global DwgTools_rollout
global dwg_tools_root_path
global dwgToolsLoadMacros
global dwgToolsRunMacro
global dwgToolsOpen

try
(
	dwg_tools_root_path = getFilenamePath (getSourceFileName())
)
catch
(
	dwg_tools_root_path = ""
)

/* Load DwgTools.mcr from the same repository root.
   This registers or refreshes macros used by launcher buttons.
*/
function dwgToolsLoadMacros =
(
	macro_path = dwg_tools_root_path + "/DwgTools.mcr"
	loaded_ok = false

	if (doesFileExist macro_path) then
	(
		try
		(
			filein macro_path
			loaded_ok = true
		)
		catch
		(
			messageBox ("Failed to load macros:\n" + macro_path + "\n\n" + (getCurrentException())) title:"DwgTools"
			loaded_ok = false
		)
	)
	else
	(
		messageBox ("Missing macro file:\n" + macro_path) title:"DwgTools"
	)

	loaded_ok -- return
)

/* Run one registered DwgTools macro.
   Buttons call macros from category _DwgTools.
*/
function dwgToolsRunMacro macro_name =
(
	run_ok = false

	try
	(
		macros.run "_DwgTools" macro_name
		run_ok = true
	)
	catch
	(
		messageBox ("Failed to run macro:\n" + macro_name + "\n\n" + (getCurrentException())) title:"DwgTools"
		run_ok = false
	)

	run_ok -- return
)

/* Open DWG Tools launcher rollout.
   Each button launches one macro from DwgTools.mcr.
*/
function dwgToolsOpen =
(
	dwgToolsLoadMacros()

	try
	(
		destroyDialog DwgTools_rollout
	)
	catch
	(
	)

	rollout DwgTools_rollout "DWG Tools" width:260 height:304
	(
		label lbl_title "Launch DWG tool macros" pos:[8,8] width:244 height:18 align:#left

		button btn_dwg_layer_manager "DwgLayerManager" pos:[8,36] width:244 height:28 tooltip:"Run _DwgTools_DwgLayerManager"
		button btn_dwg_mass_importer "DwgMassImporter" pos:[8,70] width:244 height:28 tooltip:"Run _DwgTools_DwgMassImporter"
		button btn_edge_align_tool "EdgeAlignTool" pos:[8,104] width:244 height:28 tooltip:"Run _DwgTools_EdgeAlignTool"
		button btn_spline_extractor "SplineExtractor" pos:[8,138] width:244 height:28 tooltip:"Run _DwgTools_SplineExtractor"
		button btn_transform_lock_class_manager "TransformLockClassManager" pos:[8,172] width:244 height:28 tooltip:"Run _DwgTools_TransformLockClassManager"
		button btn_win_door_manager "WinDoorManager" pos:[8,206] width:244 height:28 tooltip:"Run _DwgTools_WinDoorManager"
		button btn_trim_spline_by_volume "trimSplineByVolume" pos:[8,240] width:244 height:28 tooltip:"Run _DwgTools_trimSplineByVolume"

		label lbl_footer "Category: _DwgTools" pos:[8,276] width:244 height:18 align:#left

		on btn_dwg_layer_manager pressed do
		(
			dwgToolsRunMacro "_DwgTools_DwgLayerManager"
		)

		on btn_dwg_mass_importer pressed do
		(
			dwgToolsRunMacro "_DwgTools_DwgMassImporter"
		)

		on btn_edge_align_tool pressed do
		(
			dwgToolsRunMacro "_DwgTools_EdgeAlignTool"
		)

		on btn_spline_extractor pressed do
		(
			dwgToolsRunMacro "_DwgTools_SplineExtractor"
		)

		on btn_transform_lock_class_manager pressed do
		(
			dwgToolsRunMacro "_DwgTools_TransformLockClassManager"
		)

		on btn_win_door_manager pressed do
		(
			dwgToolsRunMacro "_DwgTools_WinDoorManager"
		)

		on btn_trim_spline_by_volume pressed do
		(
			dwgToolsRunMacro "_DwgTools_trimSplineByVolume"
		)
	)

	createDialog DwgTools_rollout width:260 height:304 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)

	true -- return
)

dwgToolsOpen()
