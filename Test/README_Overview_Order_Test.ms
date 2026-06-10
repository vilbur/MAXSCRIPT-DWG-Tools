/* Test README section order.
   Checks that Overview is before Entry script in each tool README.
*/
function testDwgToolsReadmeOverviewOrder repo_root_path: =
(
	dotnet_directory = dotNetClass "System.IO.Directory"
	dotnet_file = dotNetClass "System.IO.File"
	dotnet_path = dotNetClass "System.IO.Path"

	tools_path = dotnet_path.Combine repo_root_path "Tools"
	ok_count = 0
	failed_count = 0

	if (dotnet_directory.Exists tools_path) then
	(
		tool_dirs = dotnet_directory.GetDirectories tools_path

		for tool_dir in tool_dirs do
		(
			readme_path = dotnet_path.Combine tool_dir "README.md"

			if (dotnet_file.Exists readme_path) then
			(
				readme_text = dotnet_file.ReadAllText readme_path
				overview_index = readme_text.IndexOf "## Overview"
				entry_index = readme_text.IndexOf "## Entry script"

				if ((overview_index >= 0) and (entry_index >= 0) and (overview_index < entry_index)) then
				(
					ok_count += 1
					format "OK: %\n" readme_path
				)
				else
				(
					failed_count += 1
					format "WRONG ORDER: %\n" readme_path
				)
			)
			else
			(
				failed_count += 1
				format "MISSING: %\n" readme_path
			)
		)
	)
	else
	(
		failed_count += 1
		format "MISSING TOOLS FOLDER: %\n" tools_path
	)

	format "\nOK files: %\n" ok_count
	format "Failed files: %\n" failed_count

	(failed_count == 0) -- return
)

/* Test.
*/
testDwgToolsReadmeOverviewOrder repo_root_path:@"D:\GitHub\MAXSCRIPT-DWG-Tools"
