/*  Compresses nested dictionaries by merging single-child branches.
    Deepest values must be strings.
	
		
		============ ORIGINAL ============
		
		[nature]
			[tree]
				[leaf] = green
		[vehicle]
			[car]
				[sports]
					[wheel] = rubber
		[house]
			[room]
				[kitchen] = white
				[bedroom] = blue
		
		
		
		============ COMPRESSED ============
		
		[nature tree leaf] = green
		[vehicle car sports wheel] = rubber
		[house room]
			[kitchen] = white
			[bedroom] = blue
	
	
*/
struct DictionaryCompressor_v
(
	separator = " ",

	/*  Joins parent and child keys.
	    Uses configurable separator.
	*/
	function joinKeys parent_key child_key =
	(
		if (parent_key == "") then
		(
			child_key
		)
		else
		(
			parent_key + separator + child_key
		)
		-- return
	),

	/*  Recursively compresses dictionary hierarchy.
	    Merges branches containing only one child.
	*/
	function compressDictionary source_dict =
	(
		result_dict = Dictionary #string

		for current_key in source_dict.Keys do
		(
			val = source_dict[current_key]
		
			--if (isDictionaryValue val) then
			if (isKindOf val Dictionary) then
			(
				compressed_child = this.compressDictionary val
				
				if (compressed_child.Count == 1) then
				(
					child_key = compressed_child.Keys[1]
					child_value = compressed_child[child_key]
				
					merged_key = joinKeys current_key child_key
				
					result_dict[merged_key] = child_value
				)
				else
					result_dict[current_key] = compressed_child
			)
			else
				result_dict[current_key] = val
		)

		result_dict -- return
	),


	/*  Prints nested dictionary hierarchy.
	    Used for testing and debugging.
	*/
	function printDictionary source_dict indent:"" =
	(
		for current_key in source_dict.Keys do
		(
			val = source_dict[current_key]

			if (isKindOf val Dictionary) then
			(
				format "%[%]\n" indent current_key

				this.printDictionary val indent:(indent + "    ")
			)
			else
				format "%[%] = %\n" indent current_key val
		)
	),

	on create do
	(
	)
)

