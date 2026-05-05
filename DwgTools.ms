clearListener(); print("Cleared in:\n"+getSourceFileName())

/* UI FRAMEWORK */
filein( getFilenamePath(getSourceFileName()) + "/../MAXSCRIPT-UI-framework/Lib/Dialog/Dialog.ms" )	--"./../MAXSCRIPT-UI-framework/Lib/Dialog/Dialog.ms"

/* CONTENT LOADER */
filein( getFilenamePath(getSourceFileName()) + "/../MAXSCRIPT-UI-framework/Lib/ContentLoader/ContentLoader.ms" )	--"./../MAXSCRIPT-UI-framework/Lib/ContentLoader/ContentLoader.ms"


filein( getFilenamePath(getSourceFileName()) + "/loadContentAndCreateDialog.ms" )	--"./loadContentAndCreateDialog.ms"


filein( getFilenamePath(getSourceFileName()) + "/DwgToolsDialog.ms" )	--"./DwgToolsDialog.ms"



/* CREATE DILAOG */ 
--createDwgToolsDialog()


/* LAOD CONTENT & CREATE DILAOG */ 
loadContentAndCreateDialog()