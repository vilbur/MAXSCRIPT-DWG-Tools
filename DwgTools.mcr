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

macroscript _DwgTools_Main
category:"_DwgTools"
buttonText:"Dwg Layers"
tooltip:"Dwg Layers"
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

macroscript _DwgTools_SplineToObjConvertor
category:"_DwgTools"
buttonText:"SplineToObj"
tooltip:"SplineToObj"
icon:"tooltip:Open Transform Lock Class Manager"
(
	on execute do
	(
		
		splineToObjConvertorExecute()
	)
)



macroscript _DwgTools_IMPORT_TOOLS
category:"_DwgTools"
buttonText:"IMPORT TOOLS"
tooltip:"IMPORT TOOLS"
icon:"tooltip:IMPORT DWG Tools"
(
	
	on execute do
	(
		try(
			
		format "\nDEV-IMPORT.ms\n"
		filein @"C:\Users\vilbur\AppData\Local\Autodesk\3dsMax\2026 - 64bit\ENU\scripts\MAXSCRIPT-DWG-Tools\DEV-IMPORT.ms"
			
			)catch(
			
		format "\nWTF FAIL TO IMPORT DEV-IMPORT.ms\n"
			
		)
		
	)
)
