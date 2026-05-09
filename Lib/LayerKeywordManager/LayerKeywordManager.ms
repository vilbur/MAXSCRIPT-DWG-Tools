/** Layer keyword manager


	1) SPLIT LAYER NAMES BY PATTEN: "prefix keyword sub_keyword unique_name"
	
	2) FILL OBJECT WITH KEYWORDS:
	
		Keyword
			sub_keyword
				unique_name
	
  
  
 */
struct LayerKeywordManager_v
(
	/* construct */
	
	/* required */
	
	/* properties */
	
	
	/* private */
	/* dependency */
	/* reference */
	/* inhered */

	/** Split layer names by keywords
	 */
	function splitLayerNamesByKeywords delimeter:" " prefix_mask:"[0-9a-zA-Z]+" =
	(
		--format "\n"; print "LayerKeywordManager_v.splitLayerNamesByKeywords()"
		
		
		keywords	= Dictionary #STRING -- KEY: VALUE:
		
		for i = 0 to LayerManager.count - 1 where (layer = LayerManager.getLayer i) != undefined and layer.name != "0" do
		(
			format "\n"
			format "layer.name: %\n" layer.name
			
			/* SANITIZE LAYER NAME */ 
			--layer_name = (dotnetclass "System.Text.RegularExpressions.Regex").Replace layer.name "[^a-zA-Z0-9\\d\\s\\-_]+" ""
			layer_name = layer.name
			
			--format "layer_name: %\n" layer_name
			layer_name_split	= filterString layer_name delimeter
			
			prefix = layer_name_split[1]

			
			/* IF LAYER NAME CAN BE SPLITTED */ 
			if prefix != undefined then
			(
				prefix_mask_full_string = trimRight ( trimLeft prefix_mask "^$" )  "^$"
				
				prefix_mask_full_string = "^" + prefix_mask_full_string + "$"

				prefix_match = (( dotNetClass "System.Text.RegularExpressions.RegEx" ).match prefix prefix_mask_full_string ).success
				
				--format "prefix: %\n" prefix
				
				--format "prefix_match: %\n" prefix_match
			)
			
		
			if prefix_match == true and layer_name_split.count > 1 then
			(
				keywords_nested = keywords
				
				for x = 2 to layer_name_split.count do
				(
					keyword = toLower layer_name_split[x]
					
					--keyword += " X"
					
					if keywords_nested[keyword] == undefined then
						keywords_nested[keyword] = Dictionary #STRING
					
					/* NEXT LOOP */ 
					keywords_nested = keywords_nested[keyword]
				)
			)
			else
				keywords[layer_name] = Dictionary #STRING
			
			--format "layer: %\n" layer_name
		)
		
		--for key in keywords.keys do format "key: % \nVALUE: %\n\n" key keywords[key]
		--for key in keywords.keys do format "key: %\n" key
		
		--format "KEYWORDS: \n\n%\n\n" keywords
		keywords --return
	),
	
	
	private
	

	/**
	 */
	on create do
	(
		--format "\n"; print "LayerKeywordManager.onCreate()"
		--for prop in #(  ) where getProperty this prop == undefined do -- CHECK CONSTRUCT PROPERTIES -- Array of this struct properties necessary to run
		--	throw ("\n\n\nUNDEFINED CONSTRUCT PROPERTY\n\n\nSTRUCT:\n\n"+ ((filterString( classof this as string )"(:")[2]) +"\n\n\nPROPERTY:\n\n"+ prop )
	)

)
