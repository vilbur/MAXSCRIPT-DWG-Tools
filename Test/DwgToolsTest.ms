clearListener(); print("Cleared in:\n"+getSourceFileName())


/*------------------------------------------------------------------------------
	TEST SCENE
--------------------------------------------------------------------------------*/

filein( getFilenamePath(getSourceFileName()) + "/../Lib/LayerKeywordManager/Test/LayerKeywordManagerTest.ms" )	--"./../Lib/LayerKeywordManager/Test/LayerKeywordManagerTest.ms"


/* POPULATE LAYERS */ 
if LayerManager.count == 1 then
(
	--resetMaxFile #noPrompt
	
	/*  Test execution.
		Creates layers with mixed name lengths.
	*/
	--CreateTestLayers prefix_name:#("A01", "B02") keyword_pool:#("Masonry", "Stairs", "Doors") sub_keyword_pool:#( "cut", "seen", "conrete", "render") suffix_pool:#("balcony", "under", "above", "seen")
	CreateTestLayers prefix_name:#("A01", "B02") keyword_pool:#("main_X", "main_Y" ) sub_keyword_pool:#( "sub_1", "sub_2") suffix_pool:#()
	
	
	--CreateTestLayers()
	
	LayerManager.editLayerByName "0"
)


/*------------------------------------------------------------------------------
	CREATE DIALOG
--------------------------------------------------------------------------------*/
filein( getFilenamePath(getSourceFileName()) + "/../DwgTools.ms" )	--"./../DwgTools.ms"