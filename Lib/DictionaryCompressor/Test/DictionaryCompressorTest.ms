clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../DictionaryCompressor.ms" )	--"./../DictionaryCompressor.ms"



/** Dictionary factory
 */
function nestedDictionaryFactory &root_dict level:1 max_level:undefined root_index:undefined  =
(
	--format "\n"; print "DictionaryFactory_v.nestedDictionaryFactory()"

	
	--levels = #( "Prefix", "Keyword", "Prop", "Suffix", "Unique"  )
	levels = #( "Prefix", "Keyword", "Prop", "Suffix" )
	--levels = #( "Prefix", "Keyword", "Props" )
	--levels = #( "Prefix", "Keyword" )
	
	if max_level == undefined then
		max_level = levels.count

	if level <= max_level then
	(
		
		level_next = level + 1
		
		
		/* FIRST LEVEL */ 
		if root_index == undefined then
		(
			/* NUMBER OF ROOT ITEMS -- Same count as available levels */ 
			count = levels.count
			
		)
		/* MAX COUNT OF NESTED ITEMS */ 
		else
		(
			/* ITEMS COUNT == INDEX OF ROOT ITEM ( 3rd root item has 3 nested items ) */ 
			count = root_index
			--count = levels.count
			format "root_index == levels.count: %\n" (root_index == levels.count)
			
			/* LAST ROOT ITEM */ 
			--if root_index == levels.count then
				--count = 1
			
		)
		
		
		is_first_level = root_index == undefined and level == 1 
		--is_first_level = root_index == undefined
		
		
		for i = 1 to count do
		(
			if is_first_level then
				root_index = i
	
			key = levels[level]
	
			key_1 = key
		
			/* UNIQUE NAME */ 
			key_1 += "_" + root_index as string
			key_1 += "_" + level as string
			key_1 += "_" + i as string
		
			
			nested_dict =  Dictionary #STRING
				
			root_dict[ key_1 ] = nested_dict
	
			max_level_next = if is_first_level then i else max_level

			root_index_next = if is_first_level then i else root_index

			
			nested_dict = nestedDictionaryFactory(nested_dict) level:level_next max_level:max_level_next root_index:root_index_next
			
				
			--nested_dict = nestedDictionaryFactory(nested_dict) level:level_next max_level:max_level_next root_index:( i )
		)
	)
	
	--format "root_dict: %\n" root_dict
	root_dict --return
)




dict_test	= Dictionary #STRING

dict_test = nestedDictionaryFactory(dict_test)


DictionaryCompressor = DictionaryCompressor_v() --dictionary:dict_test

print "\n=== ORIGINAL ===\n"
--for key in dict_test.keys do format "key: % \nVALUE: %\n\n" key dict_test[key]
DictionaryCompressor.printDictionary(dict_test)

compressed_dict = DictionaryCompressor.compressDictionary(dict_test)

print "\n=== COMPRESSED ===\n"

--for key in compressed_dict.keys do format "key: % \nVALUE: %\n\n" key compressed_dict[key]
	
--DictionaryCompressor.printDictionary compressed_dict