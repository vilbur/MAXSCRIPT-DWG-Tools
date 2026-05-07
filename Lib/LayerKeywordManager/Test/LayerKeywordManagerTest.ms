clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../LayerKeywordManager.ms" )	--"./../LayerKeywordManager.ms"


clearListener()
print ("Cleared in: " + getSourceFileName())


/*  Creates test scene layers with weighted name lengths.
    Pattern: "prefix keyword sub_keyword suffix"
*/
function CreateTestLayers prefix_name:#("A",  "B") keyword_pool:#("MainX", "MainY") sub_keyword_pool:#("subA", "subB") suffix_pool:#("foo", "bar" ) =
(
    created_layers = #()

    /*  Returns random item from array.
        Array must contain at least one item.
    */
    function GetRandomItem source_array =
    (
        source_array[(random 1 source_array.count)]

        -- return
    )

    /*  Creates layer if not existing.
        Returns layer reference.
    */
    function CreateLayerIfMissing layer_name =
    (
        layer_ref = LayerManager.getLayerFromName layer_name

        if layer_ref == undefined then
        (
            layer_ref = LayerManager.newLayerFromName layer_name
        )

        layer_ref

        -- return
    )

    /*  Converts prefix input to array.
        Supports string and array input.
    */
    function NormalizePrefixArray prefix_name =
    (
        if classOf prefix_name == String then
        (
            #(prefix_name)
        )
        else
        (
            prefix_name
        )

        -- return
    )

    /*  Builds layer name from token array.
        Tokens are separated by spaces.
    */
    function BuildLayerName token_array delimeter:" " =
    (
        layer_name = ""

        for i = 1 to token_array.count where ( word = token_array[i] ) != "" do
               layer_name += ( if layer_name != "" then delimeter else "" ) +  word as string

--format "layer_name: %\n" layer_name
        layer_name -- return
    )

    prefix_array = NormalizePrefixArray prefix_name

    /*  Generates many short names.
        Prefix only.
    */
    for prefix_index = 1 to prefix_array.count do
    (
        current_prefix = prefix_array[prefix_index]

        CreateLayerIfMissing current_prefix
    )

    /*  Generates many medium names.
        prefix keyword
    */
    for item_index = 1 to 40 do
    (
        current_prefix = GetRandomItem prefix_array
        keyword_name = GetRandomItem keyword_pool

        layer_name = BuildLayerName #(
            current_prefix,
            keyword_name
        )

        layer_ref = CreateLayerIfMissing layer_name

        append created_layers layer_ref
    )

    /*  Generates fewer long names.
        prefix keyword sub_keyword
    */
    for item_index = 1 to 20 do
    (
        current_prefix = GetRandomItem prefix_array
        keyword_name = GetRandomItem keyword_pool
        sub_keyword_name = GetRandomItem sub_keyword_pool

        layer_name = BuildLayerName #(
            current_prefix,
            keyword_name,
            sub_keyword_name
        )

        layer_ref = CreateLayerIfMissing layer_name

        append created_layers layer_ref
    )

    /*  Generates few full names.
        prefix keyword sub_keyword suffix
    */
    for item_index = 1 to 10 do
    (
        current_prefix = GetRandomItem prefix_array
        keyword_name = GetRandomItem keyword_pool
        sub_keyword_name = GetRandomItem sub_keyword_pool
        suffix_name = GetRandomItem suffix_pool

        layer_name = BuildLayerName #(
            current_prefix,
            keyword_name,
            sub_keyword_name,
            suffix_name
        )

        layer_ref = CreateLayerIfMissing layer_name

        append created_layers layer_ref
    )

    /*  Generates unique layers without prefix.
        keyword sub_keyword suffix
    */
    for item_index = 1 to 8 do
    (
		--format "\n"
		prefix_random = if ( random 0 1) == 0 then GetRandomItem prefix_name else ""
		
        keyword_name = GetRandomItem keyword_pool
        --sub_keyword_name = GetRandomItem sub_keyword_pool
 		sub_keyword_name = if ( random 0 1) == 0 then GetRandomItem sub_keyword_pool else ""
       suffix_name = GetRandomItem suffix_pool

        layer_name = BuildLayerName #(
			prefix_random,
            keyword_name,
            sub_keyword_name,
            ( suffix_name + "_" + (formattedPrint item_index format:"03d"))
           --suffix_name
        ) delimeter:"_"

        layer_ref = CreateLayerIfMissing layer_name

        append created_layers layer_ref
    )

    created_layers

    -- return
)


/** Prepare scene
 */
function generateTestLayers =
(
	--resetMaxFile #noPrompt
	
	/*  Test execution.
		Creates layers with mixed name lengths.
	*/
	--CreateTestLayers prefix_name:#("A01", "B02") keyword_pool:#("Masonry", "Stairs", "Doors") sub_keyword_pool:#( "cut", "seen", "conrete", "render") suffix_pool:#("balcony", "under", "above", "seen")
	
	CreateTestLayers()
	
	LayerManager.editLayerByName "0"
)

/*------------------------------------------------------------------------------

	RUN TEST

	DISABLED FOR INCLUDIONG TO OTHEHR TESTS

--------------------------------------------------------------------------------*/
if LayerManager.count == 1 then
	generateTestLayers()

LayerKeywordManager = LayerKeywordManager_v()


LayerKeywordManager.splitLayerNamesByKeywords()
