clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../DictionaryCompressor.ms" )	--"./../DictionaryCompressor.ms"


/** Get test dictionary
 */
function getTestDictionary =
(
	--format "\n"; print ".getTestDictionary()"
	
	root_dict = Dictionary #string
	
	vehicle_dict = Dictionary #string
	car_dict = Dictionary #string
	sports_dict = Dictionary #string
	
	sports_dict["wheel"] = "rubber"
	
	car_dict["sports"] = sports_dict
	vehicle_dict["car"] = car_dict
	
	root_dict["vehicle"] = vehicle_dict
	
	
	nature_dict = Dictionary #string
	tree_dict = Dictionary #string
	
	tree_dict["leaf"] = "green"
	
	nature_dict["tree"] = tree_dict
	
	root_dict["nature"] = nature_dict
	
	
	house_dict = Dictionary #string
	
	room_dict = Dictionary #string
	room_dict["kitchen"] = "white"
	room_dict["bedroom"] = "blue"
	
	house_dict["room"] = room_dict
	
	root_dict["house"] = house_dict
	
	root_dict --return
)



test_dict = getTestDictionary()

DictionaryCompressor = DictionaryCompressor_v() --dictionary:test_dict

format "\n=== ORIGINAL ===\n"
DictionaryCompressor.printDictionary test_dict

compressed_dict = DictionaryCompressor.compressDictionary(test_dict)

format "\n=== COMPRESSED ===\n"
DictionaryCompressor.printDictionary compressed_dict