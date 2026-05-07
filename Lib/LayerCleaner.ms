
struct LayerCleaner
(
	fn moveUnmatchedLayers target_ini =
	(
		if target_ini == unsupplied or target_ini == "" do target_ini = (LayerExporter()).getIniFilePath()
		
		local keys = getINISetting target_ini "Keywords"
		local keywords = for k in keys collect (getINISetting target_ini "Keywords" k)
		
		if keywords.count == 0 do return (messagebox "No keywords found. Run Exporter first.")

		local del_layer = layerManager.getLayerFromName "_LAYERS-DELETE"
		if del_layer == undefined do (del_layer = layerManager.newLayerFromName "_LAYERS-DELETE")
		
		local moved_count = 0
		for i = 0 to (layerManager.count - 1) do
		(
			local curr = layerManager.getLayer i
			local l_name = curr.name
			
			if l_name != "0" and l_name != "_LAYERS-DELETE" do
			(
				local is_match = false
				for kw in keywords while not is_match do
				(
					if (matchPattern l_name pattern:("*" + kw + "*") ignoreCase:true) do is_match = true
				)
				
				if not is_match do 
				(
					curr.setParent del_layer
					moved_count += 1
				)
			)
		)
		format "Cleanup Complete. Moved % layers to _LAYERS-DELETE.\n" moved_count
	)
)