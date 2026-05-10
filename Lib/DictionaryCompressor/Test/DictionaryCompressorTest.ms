clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../DictionaryCompressor.ms" )	--"./../DictionaryCompressor.ms"



/** GENERATE NESTED DICTIONARY WITH VARIABLE LENGTHS
  
	INPUT:
	
		#( "Prefix", "Keyword", "Prop", "Suffix", "Unique"  )
  
	OUTPUT:
	
	
  
 */
function nestedDictionaryFactory dict levels:#() level:1 max_level:undefined  root_index:undefined DEBUG:false =
(
	--format "\n"
	--format "level: %\n" level
	--format "max_level: %\n" max_level
	
	if max_level == undefined then 
		max_level = levels.count
	
	
	if level <= max_level then
	(
		
		--max_count = if level > 3 then 1 else 3
		--max_count = level
		
		--if random 0 1 == 1 then
		nested_items_count = random 1 level
			
		if level > 3 then
			nested_items_count = random 0 1
		
		key = levels[level]
		
		for i = 1 to nested_items_count do
		(
			key += "_" + i as string
			
			dict[ key ] = Dictionary #STRING
			
			nestedDictionaryFactory (dict[ key ]) levels:levels level:( level + 1 ) max_level:max_level 
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
(
	--nested_dict = Dictionary #STRING

	dict_test[ "Layer_" + i as string ] = nestedDictionaryFactory( Dictionary #STRING ) levels:levels_input max_level:(i - keep_first_item_empty) DEBUG:DEBUG
	
)






DictionaryCompressor = DictionaryCompressor_v() --dictionary:dict_test

print "\n=== ORIGINAL ===\n"
--for key in dict_test.keys do format "key: % \nVALUE: %\n\n" key dict_test[key]
DictionaryCompressor.printDictionary(dict_test)

compressed_dict = DictionaryCompressor.compressDictionary(dict_test)

print "\n=== COMPRESSED ===\n"

--for key in compressed_dict.keys do format "key: % \nVALUE: %\n\n" key compressed_dict[key]
	
DictionaryCompressor.printDictionary compressed_dict