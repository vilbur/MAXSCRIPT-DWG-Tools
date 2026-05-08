struct LayerExporter
(
	fn getIniFilePath =
	(
		local scene_name = getFilenameFile maxfilename
		local scene_path = maxfilepath
		if scene_name == "" do scene_name = "Untitled_Scene"
		if scene_path == "" do scene_path = (getDir #temp + "\\")
		return (scene_path + scene_name + ".ini")
	),

	fn sanitizeLayerName l_name =
	(
		local rx = dotnetclass "System.Text.RegularExpressions.Regex"
		return (rx.Replace l_name "^[a-zA-Z]*\\d*[\\s\\-_]+" "")
	),

	fn optimizeKeywords name_list =
	(
		local word_map = #()
		local final_keywords = #()
		
		for n in name_list do
		(
			local words = filterString n " _-"
			for w in words where w.count > 2 do
			(
				local found = false
				for pair in word_map where pair[1] == w do (pair[2] += 1; found = true)
				if not found do append word_map #(w, 1)
			)
		)
		
		for pair in word_map do (if pair[2] > 1 do appendIfUnique final_keywords pair[1])
		
		if final_keywords.count == 0 then return name_list else return final_keywords
	),

	fn exportToIni target_ini =
	(
		if target_ini == unsupplied or target_ini == "" do target_ini = getIniFilePath()
		if (doesFileExist target_ini) do deleteFile target_ini
		
		local sanitized_names = #()
		for i = 0 to (layerManager.count - 1) do
		(
			local l_name = (layerManager.getLayer i).name
			if l_name != "0" do 
			(
				local s_name = sanitizeLayerName l_name
				if s_name != "" do append sanitized_names s_name
			)
		)
		
		local optimized_list = optimizeKeywords sanitized_names
		
		for i = 1 to optimized_list.count do
		(
			setINISetting target_ini "Keywords" ("Key_" + i as string) optimized_list[i]
		)
		format "INI Saved: %\nOptimized to % keywords.\n" target_ini optimized_list.count
	)
)