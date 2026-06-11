clearListener(); print("Cleared in: "+getSourceFileName())



/* IMPORT TOOLS */ 
filein( getFilenamePath(getSourceFileName()) + "/DwgTools.ms" )	--"./DwgTools.ms"

filein( getFilenamePath(getSourceFileName()) + "/Tools/DwgMassImporter/DwgMassImporter.ms" )	--"./Tools/DwgMassImporter/DwgMassImporter.ms"

filein( getFilenamePath(getSourceFileName()) + "/Tools/trimSplineByVolume/trimSplineByVolume.ms" )	--"./Tools/trimSplineByVolume/trimSplineByVolume.ms"

filein( getFilenamePath(getSourceFileName()) + "/Tools/EdgeAlignTool/EdgeAlignTool.ms" )	--"./Tools/EdgeAlignTool/EdgeAlignTool.ms"

filein( getFilenamePath(getSourceFileName()) + "/Tools/TransformLockClassManager/TransformLockClassManager.ms" )	--"./Tools/TransformLockClassManager/TransformLockClassManager.ms"

filein( getFilenamePath(getSourceFileName()) + "/Tools/WinDoorManager/WinDoorManager.ms" )	--"./Tools/WinDoorManager/WinDoorManager.ms"

