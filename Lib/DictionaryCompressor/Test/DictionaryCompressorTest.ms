clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../DictionaryCompressor.ms" )	--"./../DictionaryCompressor.ms"

/**  GENERATE NESTED DICTIONARY WITH VARIABLE LENGTHS
  
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
function dictionaryFactory =
(
	--format "\n"; print ".dictionaryFactory()"
	
	/** 
	 */
	function nestedDictionaryFactory &dict levels:#() level:1 max_level:undefined  root_index:undefined DEBUG:false =
	(
		--format "\n"

		if max_level == undefined then 
			max_level = levels.count
		
		
		if level <= max_level then
		(
			--nested_items_count = 1
			nested_items_count = 2
	
			key = levels[level]

			for i = 1 to nested_items_count do
			(
				key_index = key + "_" + level as string
				key_index += "_" + i as string
				
				dict[ key_index ] = Dictionary #STRING
				
				next_level = level + 1

				nestedDictionaryFactory (dict[ key_index ]) levels:levels level:next_level max_level:max_level 
			)
		)
		
		dict --return
	)
	
	levels_input = #( "Prefix", "Keyword", "Prop", "Suffix", "Unique"  )
	--levels_input = #( "Prefix", "Keyword", "Prop", "Suffix" )
	--levels_input = #( "Prefix", "Keyword", "Props" )
	--levels_input = #( "Prefix", "Keyword" )
	
	
	DEBUG = true
	
	dict_test	= Dictionary #STRING
	
	for i = 1 to levels_input.count + (keep_first_item_empty = 1) do 
		dict_test[ "Layer_" + i as string ] = nestedDictionaryFactory( Dictionary #STRING ) levels:levels_input max_level:(i - keep_first_item_empty) DEBUG:DEBUG
	
	dict_test --return
)
	






DictionaryCompressor = DictionaryCompressor_v() --dictionary:dict_test

dict_test = dictionaryFactory()

print "\n=== ORIGINAL ===\n"
--for key in dict_test.keys do format "key: % \nVALUE: %\n\n" key dict_test[key]
DictionaryCompressor.printDictionary(dict_test)

compressed_dict = DictionaryCompressor.compressDictionary(dict_test)

print "\n=== COMPRESSED ===\n"
DictionaryCompressor.printDictionary compressed_dict