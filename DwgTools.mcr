filein @"C:\Users\vilbur\AppData\Local\Autodesk\3dsMax\2026 - 64bit\ENU\scripts\MAXSCRIPT-DWG-Tools\DwgTools-filein.ms"

macroscript _DwgTools_open_tools
category:"_DwgTools"
buttonText:"dwgTools"
tooltip:"Open DWG Tools"
(
	
	on execute do
	(
		dwgToolsOpen()
	)
)




macroscript _DwgTools_MassImporter
category:"_DwgTools"
buttonText:"MassImporter"
tooltip:"DWG Mass Import"
(
	
	on execute do
	(
		LayerManager.editLayerByName "0"
		(DwgMassImporter_Main()).run()
	)
)


macroscript _DwgTools_TrimSpline
category:"_DwgTools"
buttonText:"Volume Trim"
tooltip:"Volume Trim"
(
	
	on execute do
	(
		--clearListener(); print("Cleared in: "+getSourceFileName())
		openCanvasTrimSplinesTool()
	)
)

macroscript _DwgTools_DwgLayerManager
category:"_DwgTools"
buttonText:"Dwg Layers"
tooltip:"Open DWG Layer Managerer"
(
	on execute do
	(
		openDwgLayerManager()
	)
)


macroscript _DwgTools_EdgeAlignTool
category:"_DwgTools"
buttonText:"EdgeAlign"
tooltip:"EdgeAlign"
icon:"tooltip:Open Edge Align Tool"
(
	on execute do
	(
		--filein @"C:\Users\vilbur\AppData\Local\Autodesk\3dsMax\2026 - 64bit\ENU\scripts\MAXSCRIPT-DWG-Tools\Lib\EdgeAlignTool\EdgeAlignTool.ms"
		launchEdgeAlignTool()
	)
)

macroscript _DwgTools_TransformLockClassManager
category:"_DwgTools"
buttonText:"LockClass"
tooltip:"LockClass"
icon:"tooltip:Open Transform Lock Class Manager"
(
	on execute do
	(
		--filein @"C:\Users\vilbur\AppData\Local\Autodesk\3dsMax\2026 - 64bit\ENU\scripts\MAXSCRIPT-DWG-Tools\Lib\EdgeAlignTool\EdgeAlignTool.ms"
		(TransformLockClassManager_v()).openRollout()
	)
)

macroscript _DwgTools_WinDoors_Manager
category:"_DwgTools"
buttonText:"WinDoors"
tooltip:"SplineToObj"
icon:"tooltip:Open Transform Lock Class Manager"
(
	on execute do
	(
		winDoorManager()
	)
)