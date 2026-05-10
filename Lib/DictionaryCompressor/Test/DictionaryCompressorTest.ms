clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../DictionaryCompressor.ms" )	--"./../DictionaryCompressor.ms"

/**  GENERATE NESTED DICTIONARY WITH VARIABLE LENGTHS
  
  
  
	@param Dictionary variation #(3, 2) on LEVEL:3 make 2 ITEMS
  
  
	INPUT:
	
		#( "Prefix", "Keyword", "Prop", "Suffix", "Unique"  )
  
	OUTPUT:
	
		[Layer_1]
		[Layer_2]
			[Prefix_1]
		[Layer_3]
			[Prefix_1]
				[Keyword_1]
		[Layer_4]
			[Prefix_1]
				[Keyword_1]
					[Prop_1]
		[Layer_5]
			[Prefix_1]
				[Keyword_1]
					[Prop_1]
					[Suffix_2]
					[Suffix_3]
						[Suffix_1]
				[Suffix_1_2]
					[Prop_1]
						[Suffix_1]
					[Suffix_1_2]
					[Suffix_3]
		[Layer_6]
			[Prefix_1]
				[Keyword_1]
					[Prop_1]
						[Suffix_1]
							[Unique_1]
					[Unique_1_2]
		  
  
  
 */
function dictionaryFactory variation:undefined =
(
	--format "\n"; print ".dictionaryFactory()"
	--format "variation: %\n" variation
	
	function nestedDictionaryFactory &dict levels:#() level:1 max_level:undefined  root_index:undefined DEBUG:false variation:undefined =
	(
		--format "\n"; print ".nestedDictionaryFactory()"
		--format "variation: %\n" variation
		
		if max_level == undefined then 
			max_level = levels.count
				
		if level <= max_level then
		(
			-- 1. Explicitly define these as local so recursion doesn't overwrite them
			local nested_items_count = 1
			
			if variation != undefined and variation[level] != undefined then 
			--if variation != undefined then 
			(
				format "\n"
				format "variation: %\n" variation
				format "level: %\n" level
				format "variation[level]: %\n" variation[level]
			)
			
			
			if variation != undefined and variation[level] != undefined then 
				nested_items_count = variation[level]
			
			--if level == 3 then
				--nested_items_count = 2
			
			
			local key = levels[level]
			
			local next_level = level + 1

			for i = 1 to nested_items_count do
			(
				-- 2. Explicitly define the key_index as local to the loop
				local key_index = key + "_" + level as string + "_" + i as string
				
				dict[ key_index ] = Dictionary #STRING

				nestedDictionaryFactory (dict[ key_index ]) levels:levels level:next_level max_level:max_level variation:variation
			)
		)
		
		dict --return
	)
	
	/*------------------------------------------------------------------------------
		RUN FACTORY
	--------------------------------------------------------------------------------*/
	
	
	--levels_input = #( "Prefix", "Keyword", "Prop", "Suffix", "Unique"  )
	levels_input = #( "Prefix", "Keyword", "Prop", "Suffix" )
	--levels_input = #( "Prefix", "Keyword", "Props" )
	--levels_input = #( "Prefix", "Keyword" )

	
	DEBUG = true
	
	dict_test	= Dictionary #STRING
	
	for i = 1 to levels_input.count + (keep_first_item_empty = 1) do 
		dict_test[ "Layer_" + i as string ] = nestedDictionaryFactory( Dictionary #STRING ) levels:levels_input max_level:(i - keep_first_item_empty) DEBUG:DEBUG variation:variation
	
	dict_test --return
)
	






DictionaryCompressor = DictionaryCompressor_v() --dictionary:dict_test

dict_test = dictionaryFactory variation:( Dictionary #( 2, 2 ) #( 4, 2 )  )

print "\n=== ORIGINAL ===\n"
--for key in dict_test.keys do format "key: % \nVALUE: %\n\n" key dict_test[key]
DictionaryCompressor.printDictionary(dict_test)

compressed_dict = DictionaryCompressor.compressDictionary(dict_test)

print "\n=== COMPRESSED ===\n"
DictionaryCompressor.printDictionary compressed_dict