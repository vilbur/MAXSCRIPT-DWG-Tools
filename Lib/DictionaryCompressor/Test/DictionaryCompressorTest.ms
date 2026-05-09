clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../DictionaryCompressor.ms" )	--"./../DictionaryCompressor.ms"



/** Dictionary factory
 */
function dictionaryFactory root_dict level:1 max_level: =
(
	--format "\n"; print "DictionaryFactory_v.dictionaryFactory()"
	--format "level: %\n" level
	
	levels = #( "Prefix", "Keyword", "Prop", "Suffix" )
	
	if max_level == unsupplied then
		max_level = levels.count

	for i = 1 to levels.count - level + 1 do
	(

		key = levels[level]

		key_1 = key + "_" + i as string
		
		nested_dict =  Dictionary #STRING
			
		root_dict[ key_1 ] = nested_dict

		if level < levels.count  then
			nested_dict = dictionaryFactory(nested_dict) level:( level + 1 ) --smax_level:( max_level - level )
	)
	--format "root_dict: %\n" root_dict
	root_dict --return
)




dict_test	= Dictionary #STRING

dict_test = dictionaryFactory(dict_test)


DictionaryCompressor = DictionaryCompressor_v() --dictionary:dict_test

print "\n=== ORIGINAL ===\n"
--for key in dict_test.keys do format "key: % \nVALUE: %\n\n" key dict_test[key]
DictionaryCompressor.printDictionary(dict_test)

compressed_dict = DictionaryCompressor.compressDictionary(dict_test)

print "\n=== COMPRESSED ===\n"

--for key in compressed_dict.keys do format "key: % \nVALUE: %\n\n" key compressed_dict[key]
	
--DictionaryCompressor.printDictionary compressed_dict