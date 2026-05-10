/*  Compresses nested dictionaries by merging single-child branches.
    Deepest values must be strings.
	
	=== ORIGINAL ===
	
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
	

	=== COMPRESSED ===
	
	[Layer_1]
	[Layer_2 Prefix_1]
	[Layer_3 Prefix_1 Keyword_1]
	[Layer_4 Prefix_1 Keyword_1 Prop_1]
	[Layer_5 Prefix_1]
		[Keyword_1]
			[Prop_1]
			[Suffix_2]
			[Suffix_3 Suffix_1]
		[Suffix_1_2]
			[Prop_1 Suffix_1]
			[Suffix_1_2]
			[Suffix_3]
	[Layer_6 Prefix_1 Keyword_1]
		[Prop_1 Suffix_1 Unique_1]
		[Unique_1_2]
		
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

			if (isKindOf val Dictionary) then
			(
				compressed_child = this.compressDictionary val

				if (compressed_child.keys.Count == 1) then
				(
					child_key = compressed_child.keys[1]
					child_value = compressed_child[child_key]

					merged_key = this.joinKeys current_key child_key

					result_dict[merged_key] = child_value
				)
				else
				(
					result_dict[current_key] = compressed_child
				)
			)
			else
			(
				result_dict[current_key] = val
			)
		)

		result_dict -- return
	),


	/*  Prints nested dictionary hierarchy.
	    Used for testing and debugging.
	*/
	function printDictionary source_dict indent:"" =
	(
		for current_key in sort source_dict.Keys do
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

