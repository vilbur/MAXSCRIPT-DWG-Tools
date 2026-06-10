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
	freezed_layers_unique = true,
	
	/* private */
	/* dependency */
	/* reference */
	/* inhered */

	/** Split layer names by keywords
	  
		param string prefix_mask	regEx  mask to match layer name prefix   E.G.: "\d+" >>> "01 Exterior balcony doors"
		
		param string word_delimeter	split layer name to kywords by delimeter E.G.: "-"   >>> "Exterior-balcony-doors"
	  
	 */
	function splitLayerNamesByKeywords prefix_mask:"^.*?[_-]" word_delimeter:" " = 
	(
		--format "\n"; print "LayerKeywordManager_v.splitLayerNamesByKeywords()"
		--format "prefix_mask: %\n" prefix_mask
		
		--format "\nHOTFIX"
		
		word_delimeter = " "
		
		fn trim _string = trimLeft( trimRight _string " -_") " -_"
		
		keywords	= Dictionary #STRING -- KEY: VALUE:
		
		layers_all = for i = 0 to LayerManager.count - 1 where (layer = LayerManager.getLayer i) != undefined and layer.name != "0" collect layer
		
		layers_top = for layer in layers_all where layer.getParent() == undefined collect layer
		
		
		for layer in layers_top do
		(
			if not layer.isfrozen then
			(
				layer_name_split = this._splitPrefixByRegex layer.name prefix_mask
	
				prefix	= trim layer_name_split[1]
				layer_name	= trim layer_name_split[2]
	
				layer_key = if prefix != "" and layer_name == "" then prefix else layer_name
				
				--layer.getNumChildren()
			
				keywords[layer_key] = Dictionary #STRING
				--keywords[layer.name] = Dictionary #STRING
				
			)
			else
				keywords[layer_name] = #FREEZED 
		)
		--format "keywords.keys: %\n" keywords.keys
		
		/* LOOP EACH LAYER */ 
		for layer in layers_all where findItem layers_top layer == 0 do
		(
			--format "\n-------------------------------------------\n"
			--format "\nlayer.name: %\n" layer.name
			layer_name = trim layer.name
			
			if not layer.isfrozen then
			(
				layer_name_split = this._splitPrefixByRegex layer_name prefix_mask
				
				prefix	= trim layer_name_split[1]
				layer_basename	= trim layer_name_split[2]
				--format "prefix: %\n" prefix
				/* IF LAYER NAME IS ONLY PREFIX, then use prefix as layer name */ 
				layer_basename = if prefix != "" and layer_basename == "" then prefix else layer_basename
				
				--format "layer_basename: %\n" layer_basename
				keyword_split	= filterString layer_basename word_delimeter

				--format "keywords[prefix]: %\n" keywords[prefix]
				
				/*------------------------------------------------------------------------------
				
					CODE BELOW DRIVES
				
				--------------------------------------------------------------------------------*/
				
				if keywords[prefix] != undefined then
 					insertItem prefix keyword_split 1
				
				/*--------------------------------------------------------------------------------*/
				
				--if prefix != "" and layer_name_split.count > 1 then
				(
					keywords_nested = keywords
					
					
					for x = 1 to keyword_split.count do
					(
						--word = toLower keyword_split[x]
						word = keyword_split[x]
						--format "word: %\n" word
						
						if keywords_nested[word] == undefined then
							keywords_nested[word] = Dictionary #STRING
						
						/* NEXT LOOP */ 
						keywords_nested = keywords_nested[word]
					)
				)
				--else
					--keywords[layer_name] = Dictionary #STRING
				
			)
			else
				keywords[layer_name] = #FREEZED 

			--format "layer: %\n" layer_name
		)
		
		--for key in keywords.keys do format "key: % \nVALUE: %\n\n" key keywords[key]
		--for key in keywords.keys do format "key: %\n" key
		
		--format "KEYWORDS: \n\n%\n\n" keywords
		keywords --return
	),
	
	private
	
	/*
    Split string to prefix and basename by regex pattern.
    If prefix is not found then basename is original string.
	*/
	function _splitPrefixByRegex input_string prefix_pattern =
	(
		prefix_string = ""
		basename_string = input_string
	
		dotnet.loadAssembly "System"
	
		regex_obj = dotNetObject "System.Text.RegularExpressions.Regex" prefix_pattern
		match_obj = regex_obj.Match input_string
	
		if match_obj.Success and match_obj.Index == 0 then
		(
			prefix_string = match_obj.Value
			basename_string = substring input_string (match_obj.Length + 1) -1
		)
	
		#(prefix_string, basename_string) -- return
	),
	

	/**
	 */
	on create do
	(
		--format "\n"; print "LayerKeywordManager.onCreate()"
		--for prop in #(  ) where getProperty this prop == undefined do -- CHECK CONSTRUCT PROPERTIES -- Array of this struct properties necessary to run
		--	throw ("\n\n\nUNDEFINED CONSTRUCT PROPERTY\n\n\nSTRUCT:\n\n"+ ((filterString( classof this as string )"(:")[2]) +"\n\n\nPROPERTY:\n\n"+ prop )
	)

)
