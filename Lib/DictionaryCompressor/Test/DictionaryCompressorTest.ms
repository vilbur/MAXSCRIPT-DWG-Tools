clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../DictionaryCompressor.ms" )	--"./../DictionaryCompressor.ms"



/** Dictionary factory
 */
function nestedDictionaryFactory &dict levels:#() level:1 max_level:undefined  root_index:undefined DEBUG:false =
(
	--format "\n"
	--format "level: %\n" level
	--format "max_level: %\n" max_level
	
	if max_level == undefined then 
		max_level = levels.count
	
	
	if level <= max_level then
	(
		
		--if level <=  then
		
		key = levels[level]
	
	
		nested_dict = Dictionary #STRING
		
		dict[ key ] = nested_dict
		
		--nestedDictionaryFactory( nested_dict ) levels:levels_input DEBUG:DEBUG
		--	for level = 1 to levels.count do 
		--	(
				
				--if level < levels.count then
				--if level < max_level then
					nestedDictionaryFactory nested_dict levels:levels level:( level + 1 ) max_level:max_level 
				
			--)
		
	)
	
	
	dict --return
)


	
--levels_input = #( "Prefix", "Keyword", "Prop", "Suffix", "Unique"  )
levels_input = #( "Prefix", "Keyword", "Prop", "Suffix" )
--levels_input = #( "Prefix", "Keyword", "Props" )
--levels_input = #( "Prefix", "Keyword" )


DEBUG = true

dict_test	= Dictionary #STRING


for i = 1 to levels_input.count do 
(
	--nested_dict = Dictionary #STRING

	dict_test[ i as string ] = nestedDictionaryFactory( Dictionary #STRING ) levels:levels max_level:i DEBUG:DEBUG
)



DictionaryCompressor = DictionaryCompressor_v() --dictionary:dict_test

print "\n=== ORIGINAL ===\n"
--for key in dict_test.keys do format "key: % \nVALUE: %\n\n" key dict_test[key]
DictionaryCompressor.printDictionary(dict_test)

--compressed_dict = DictionaryCompressor.compressDictionary(dict_test)

--print "\n=== COMPRESSED ===\n"

--for key in compressed_dict.keys do format "key: % \nVALUE: %\n\n" key compressed_dict[key]
	
--DictionaryCompressor.printDictionary compressed_dict