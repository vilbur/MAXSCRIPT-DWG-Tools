/** Layer toggle callback
 */
function layerToggleCallback state item_id =
(
	--format "\n"; print ".layerToggleCallback()"
	--format "state: %\n" state
	--format "EventFired: %\n" EventFired
    format "Callback Triggered -> State: % | Item ID: %\n" state item_id

	/** Join array to string
	 */
	function arrayToString arr delimeter = ( _string = ""; for item in arr do _string += item as string  + delimeter; substring _string 1 (_string.count-delimeter.count))
	
	id_split	= filterString item_id "_"
	
	--deleteItem id_split 1

	ignore_prefix = ignore_sufix = "*"
	pattern = arrayToString id_split "*"
	
	--format "PATTERN: %\n" pattern
	
	
	for i = 0 to LayerManager.count - 1 where (layer = LayerManager.getLayer i) != undefined do
	(
		
		if matchPattern layer.name pattern:( ignore_prefix + pattern + ignore_sufix ) then
			layer.on = state
			--format "LAYER: %\n" layer.name
		
	)
)
