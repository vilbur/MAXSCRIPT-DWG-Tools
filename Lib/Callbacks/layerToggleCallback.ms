/** Layer toggle callback
 */
function layerToggleCallback state item_id =
(
    --format "layerToggleCallback State: % | Item ID: %\n" state item_id

	/** Join array to string
	 */
	function arrayToString arr delimeter = ( _string = ""; for item in arr do _string += item as string  + delimeter; substring _string 1 (_string.count-delimeter.count))
	
	mode = case state of
	(
		0:#HIDE
		1:#SHOW
		2:#FREEZE
	)
	
	
	ignore_prefix = ignore_sufix = "*"
	
	--id_split	= filterString item_id "_"
	--pattern = arrayToString id_split "*"
	
	pattern =  ignore_prefix + item_id
	
	
	--pattern =  ignore_prefix + pattern
	--format "PATTERN: %\n" pattern
	
	
	for i = 0 to LayerManager.count - 1 where (layer = LayerManager.getLayer i) != undefined do
	(
		
		if matchPattern layer.name pattern:( pattern ) then
		--if matchPattern layer.name pattern:( pattern ) then
		(
			layer.on = mode == #SHOW 
			
			layer.isfrozen = mode == #FREEZE
		)
		
	)
)
