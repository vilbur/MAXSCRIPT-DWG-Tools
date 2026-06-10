/* Test DwgTools macro coverage.
   Checks root DwgTools.mcr against Tools\<ToolName>\<ToolName>.ms.
*/
function testDwgToolsMacroCoverage repo_root_path: =
(
	directory_class = dotNetClass "System.IO.Directory"
	path_class = dotNetClass "System.IO.Path"
	file_class = dotNetClass "System.IO.File"
	regex_class = dotNetClass "System.Text.RegularExpressions.Regex"

	tools_path = path_class.Combine repo_root_path "Tools"
	macro_path = path_class.Combine repo_root_path "DwgTools.mcr"

	if (not (directory_class.Exists tools_path)) then
	(
		format "MISSING Tools folder: %\n" tools_path
		false -- return
	)
	else if (not (file_class.Exists macro_path)) then
	(
		format "MISSING DwgTools.mcr: %\n" macro_path
		false -- return
	)
	else
	(
		macro_text = file_class.ReadAllText macro_path
		tool_dirs = directory_class.GetDirectories tools_path
		missing_macro_count = 0
		missing_tool_entry_count = 0

		for tool_dir in tool_dirs do
		(
			tool_name = path_class.GetFileName tool_dir
			tool_entry_path = path_class.Combine tool_dir (tool_name + ".ms")
			macro_name = "_DwgTools_" + tool_name
			macro_pattern = "(?i)macroscript\s+" + (regex_class.Escape macro_name) + "\b"

			if (not (file_class.Exists tool_entry_path)) then
			(
				missing_tool_entry_count += 1
				format "MISSING TOOL ENTRY: %\n" tool_entry_path
			)

			if (not ((regex_class.Match macro_text macro_pattern).Success)) then
			(
				missing_macro_count += 1
				format "MISSING MACRO: % for %\n" macro_name tool_entry_path
			)
			else
			(
				format "OK: % -> %\n" macro_name tool_entry_path
			)
		)

		format "\nMissing tool entries: %\n" missing_tool_entry_count
		format "Missing macros: %\n" missing_macro_count

		((missing_tool_entry_count == 0) and (missing_macro_count == 0)) -- return
	)
)

/* Test.
*/
testDwgToolsMacroCoverage repo_root_path:@"D:\GitHub\MAXSCRIPT-DWG-Tools"
