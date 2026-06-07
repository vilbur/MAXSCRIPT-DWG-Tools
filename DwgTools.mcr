macroscript _DwgTools_MassImporter
category:"_DwgTools"
tooltip:"DWG Mass Import"
buttonText:"MassImporter"
(
	
	on execute do
	(
		LayerManager.editLayerByName "0"
		(DwgMassImporter_Main()).run()
	)
)


macroscript _DwgTools_TrimSpline
category:"_DwgTools"
tooltip:"Volume Trim"
buttonText:"Volume Trim"
(
	
	on execute do
	(
		--clearListener(); print("Cleared in: "+getSourceFileName())
		openCanvasTrimSplinesTool()
	)
)

macroscript _DwgTools_Main
category:"_DwgTools"
tooltip:"Dwg Layers"
buttonText:"Dwg Layers"
(
	on execute do
	(
		openDwgLayerManager()
	)
)

macroscript _DwgTools_IMPORT_TOOLS
category:"_DwgTools"
tooltip:"IMPORT_TOOLS"
buttonText:"IMPORT_TOOLS"
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
