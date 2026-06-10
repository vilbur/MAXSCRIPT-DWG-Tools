/** Layer toggle callback
 */
function layerToggleCallback state item_id =
(
    format "layerToggleCallback State: % | Item ID: %\n" state item_id

	/** Join array to string
	 */
	--function arrayToString arr delimeter = ( _string = ""; for item in arr do _string += item as string  + delimeter; substring _string 1 (_string.count-delimeter.count))
	
	--function makeRegexPattern pattern_string = ( substituteString pattern_string "*" "[\\s_-]+" ) -- return
	/** Layer name match
	 */
	function layerNameMatch _string pattern = ( dotNetClass "System.Text.RegularExpressions.Regex").IsMatch _string pattern ((dotNetClass "System.Text.RegularExpressions.RegexOptions").IgnoreCase)

	
	mode = case state of
	(
		0:#HIDE
		1:#SHOW
		2:#FREEZE
	)
	
	--all_delimeters = "[\s-_]+"
	
	ignore_prefix = "^.*"
	
	--id_split	= filterString item_id " "
	
	layer_name_pattern =  substituteString item_id "*" "[\\s_-]+"
	
	pattern =  ignore_prefix + layer_name_pattern + "$"
	
	--pattern =  ".*"
	format "PATTERN:|%|\n" pattern
	
	
	for i = 0 to LayerManager.count - 1 where (layer = LayerManager.getLayer i) != undefined do
	(
		
		if layerNameMatch layer.name pattern then
		(
			layer.on = case mode of
			(
				#SHOW: if not layer.isfrozen then true else layer.on
				#HIDE: false
				#FREEZE: false
			)
			
			layer.isfrozen = mode == #FREEZE
		)
		
	)
)
