global dwg_tools_root_path
global dwgToolsGetRootPath
global dwgToolsGetToolPath
global dwgToolsFileInTool
global dwgToolsFileInRootScript

if (dwg_tools_root_path == undefined) then
(
	try
	(
		dwg_tools_root_path = getFilenamePath (getSourceFileName())
	)
	catch
	(
		dwg_tools_root_path = ""
	)
)

/* Get repository root path.
   DwgTools.ms can set this before loading this macroscript.
*/
function dwgToolsGetRootPath =
(
	root_path = dwg_tools_root_path

	if (root_path == undefined or root_path == "") then
	(
		try
		(
			root_path = getFilenamePath (getSourceFileName())
		)
		catch
		(
			root_path = ""
		)
	)

	root_path -- return
)

/* Build path to one tool entry script.
   Folder name and entry script name must be identical.
*/
function dwgToolsGetToolPath tool_name =
(
	root_path = dwgToolsGetRootPath()
	tool_path = root_path + "/Tools/" + tool_name + "/" + tool_name + ".ms"

	tool_path -- return
)

/* File in one tool by folder name.
   Returns true when the entry script was loaded.
*/
function dwgToolsFileInTool tool_name =
(
	tool_path = dwgToolsGetToolPath tool_name
	file_loaded = false

	if (doesFileExist tool_path) then
	(
		try
		(
			filein tool_path
			file_loaded = true
		)
		catch
		(
			messageBox ("Failed to filein tool:\n" + tool_path + "\n\n" + (getCurrentException())) title:"DwgTools"
			file_loaded = false
		)
	)
	else
	(
		messageBox ("Missing tool file:\n" + tool_path) title:"DwgTools"
	)

	file_loaded -- return
)

/* File in one root script.
   Used by the optional DwgTools launcher macro.
*/
function dwgToolsFileInRootScript script_name =
(
	root_path = dwgToolsGetRootPath()
	script_path = root_path + "/" + script_name
	file_loaded = false

	if (doesFileExist script_path) then
	(
		try
		(
			filein script_path
			file_loaded = true
		)
		catch
		(
			messageBox ("Failed to filein script:\n" + script_path + "\n\n" + (getCurrentException())) title:"DwgTools"
			file_loaded = false
		)
	)
	else
	(
		messageBox ("Missing script file:\n" + script_path) title:"DwgTools"
	)

	file_loaded -- return
)

macroscript _DwgTools_OpenTools
category:"_DwgTools"
buttonText:"DwgTools"
tooltip:"Open DWG Tools launcher"
(
	on execute do
	(
		dwgToolsFileInRootScript "DwgTools.ms"
	)
)

macroscript _DwgTools_DwgLayerManager
category:"_DwgTools"
buttonText:"DwgLayerManager"
tooltip:"Open DwgLayerManager"
(
	on execute do
	(
		if (dwgToolsFileInTool "DwgLayerManager") then
		(
			openDwgLayerManager()
		)
	)
)

macroscript _DwgTools_DwgMassImporter
category:"_DwgTools"
buttonText:"DwgMassImporter"
tooltip:"Open DwgMassImporter"
(
	on execute do
	(
		if (dwgToolsFileInTool "DwgMassImporter") then
		(
			try
			(
				LayerManager.editLayerByName "0"
			)
			catch
			(
			)

			(DwgMassImporter_Main()).run()
		)
	)
)

macroscript _DwgTools_EdgeAlignTool
category:"_DwgTools"
buttonText:"EdgeAlignTool"
tooltip:"Open EdgeAlignTool"
(
	on execute do
	(
		if (dwgToolsFileInTool "EdgeAlignTool") then
		(
			launchEdgeAlignTool()
		)
	)
)

macroscript _DwgTools_SplineExtractor
category:"_DwgTools"
buttonText:"SplineExtractor"
tooltip:"Open SplineExtractor"
(
	on execute do
	(
		dwgToolsFileInTool "SplineExtractor"
	)
)

macroscript _DwgTools_TransformLockClassManager
category:"_DwgTools"
buttonText:"TransformLockClassManager"
tooltip:"Open TransformLockClassManager"
(
	on execute do
	(
		if (dwgToolsFileInTool "TransformLockClassManager") then
		(
			TransformLockClassManager = TransformLockClassManager_v()
			TransformLockClassManager.openRollout()
		)
	)
)

macroscript _DwgTools_WinDoorManager
category:"_DwgTools"
buttonText:"WinDoorManager"
tooltip:"Open WinDoorManager"
(
	on execute do
	(
		if (dwgToolsFileInTool "WinDoorManager") then
		(
			winDoorManager()
		)
	)
)

macroscript _DwgTools_trimSplineByVolume
category:"_DwgTools"
buttonText:"trimSplineByVolume"
tooltip:"Open trimSplineByVolume"
(
	on execute do
	(
		if (dwgToolsFileInTool "trimSplineByVolume") then
		(
			openCanvasTrimSplinesTool()
		)
	)
)
