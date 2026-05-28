
macroscript _DwgTools_Main
category:"_DwgTools"
tooltip:"Dwg Layers"
buttonText:"Dwg Layers"
(
	on execute do
	(
		filein @"C:\Users\vilbur\AppData\Local\Autodesk\3dsMax\2023 - 64bit\ENU\scripts\MAXSCRIPT-DWG-Tools\DwgTools.ms"

		--openDwgLayerManager()
	)
)



macroscript _DwgTools_MassImporter
category:"_DwgTools"
tooltip:"DWG Mass Import"
buttonText:"MassImporter"
(
	
	on execute do
	(
		filein @"C:\Users\vilbur\AppData\Local\Autodesk\3dsMax\2023 - 64bit\ENU\scripts\MAXSCRIPT-DWG-Tools\Lib\DwgMassImporter\DwgMassImporter.ms"

		--(DwgMassImporter_Main()).run()
	)
)

macroscript _DwgTools_TrimSpline
category:"_DwgTools"
tooltip:"Volume Trim"
buttonText:"Volume Trim"
(
	
	on execute do
	(
		filein @"C:\Users\vilbur\AppData\Local\Autodesk\3dsMax\2023 - 64bit\ENU\scripts\MAXSCRIPT-DWG-Tools\Lib\trimSplineByVolume\trimSplineByVolume.ms"

		--openCanvasTrimSplinesTool()
	)
)