clearListener(); print("Cleared in:\n"+getSourceFileName())

global tv_rollout
global DIALOG_dwgtools

global LAYER_MANAGER_APP
global LAYER_NAMES_KEYWORDS

/* UI FRAMEWORK */
filein( getFilenamePath(getSourceFileName()) + "/../MAXSCRIPT-UI-framework/Lib/Dialog/Dialog.ms" )	--"./../MAXSCRIPT-UI-framework/Lib/Dialog/Dialog.ms"

/* CONTENT LOADER */
filein( getFilenamePath(getSourceFileName()) + "/../MAXSCRIPT-UI-framework/Lib/ContentLoader/ContentLoader.ms" )	--"./../MAXSCRIPT-UI-framework/Lib/ContentLoader/ContentLoader.ms"


filein( getFilenamePath(getSourceFileName()) + "/Lib/LayerExporter.ms" )	--"./Lib/LayerExporter.ms"
filein( getFilenamePath(getSourceFileName()) + "/Lib/LayerCleaner.ms" )	--"./Lib/LayerCleaner.ms"
filein( getFilenamePath(getSourceFileName()) + "/Lib/LayerManagerApp.ms" )	--"./Lib/LayerManagerApp.ms"

filein( getFilenamePath(getSourceFileName()) + "/Lib/LayerKeywordManager/LayerKeywordManager.ms" )	--"./Lib/LayerKeywordManager/LayerKeywordManager.ms"

filein( getFilenamePath(getSourceFileName()) + "/Lib/LayerKeywordManager/layerTreeGenerator.ms" )	--"./Lib/LayerKeywordManager/layerTreeGenerator.ms"

filein( getFilenamePath(getSourceFileName()) + "/Lib/Callbacks/layerToggleCallback.ms" )	--"./Lib/Callbacks/layerToggleCallback.ms"

filein( getFilenamePath(getSourceFileName()) + "/loadContentAndCreateDialog.ms" )	--"./loadContentAndCreateDialog.ms"


filein( getFilenamePath(getSourceFileName()) + "/dwgToolsDialog.ms" )	--"./dwgToolsDialog.ms"


LayerManager.editLayerByName "0"

/*------------------------------------------------------------------------------
	CREATE DIALOG
--------------------------------------------------------------------------------*/

LAYER_MANAGER_APP = LayerManagerApp()


Dialog = undefined
dialog_width = 320

/* LAOD CONTENT & CREATE DIALOG */ 
--Dialog = loadContentAndCreateDialog width:dialog_width

--format "classOf Dialog: %\n" ( classOf Dialog )
--format "Dialog._Controls.count: %\n" Dialog._Controls.count

/* MODIFY DIALOG */ 
Dialog = dwgToolsDialog Dialog:Dialog width:dialog_width
--format "Dialog._Controls.count: %\n" Dialog._Controls.count

/* CREATE DIALOG */ 
--Dialog.create()
--Dialog.create height:undefined --width:dialog_width
--
--
----rollout rollout_test "Test"
----(
----	button btn_test "Press Me"
----	--on test rolledUp state do
----	--if state then print "Rolled Down!" else print "Rolled Up!"
----)
--
--layerTreeGenerator layer_names
--
--AddSubRollout DIALOG_dwgtools.subrollouts_1 tv_rollout

