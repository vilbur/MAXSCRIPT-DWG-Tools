/*
    Description: Core Logic Methods for DWG Mass Importer
    Version: 0.60
*/

struct DwgMassImporter_Methods
(
    settings, -- Reference to the global settings struct

    function createParentLayer layer_name =
    (
        local parent_layer = LayerManager.getLayerFromName layer_name
        if (parent_layer == undefined) then
        (
            parent_layer = LayerManager.newLayerFromName layer_name
        )
        parent_layer
    ),

    function getCurrentLayers =
    (
        local layers = #()
        for i = 0 to (LayerManager.count - 1) do
        (
            append layers (LayerManager.getLayer i)
        )
        layers
    ),

    function cleanUpDwgBlocks nodes_array =
    (
        local blocks_to_delete = #()
        for obj in nodes_array do
        (
            if (isValidNode obj and isKindOf obj LinkComposite) then
            (
                if (matchPattern obj.name pattern:"Block:*" ignoreCase:true) then
                (
                    append blocks_to_delete obj
                )
            )
        )
       
        for b in blocks_to_delete do
        (
            if (isValidNode b) then
            (
                local child_nodes = b.children
                for c in child_nodes do
                (
                    c.parent = undefined
                )
                delete b
            )
        )
    ),

    function processImportedLayers parent_layer new_nodes old_layers prefix_layers: =
    (
        parent_layer.current = true

        local used_layers = #()
        local layer_nodes = #()
        local rx = dotNetClass "System.Text.RegularExpressions.Regex"
        
        local search_str = settings.regex_search as string
        local replace_str = settings.regex_replace as string

        for obj in new_nodes do
        (
            if (not isValidNode obj) then continue
            
            local layer_ref = obj.layer
            local idx = findItem used_layers layer_ref
            if (idx == 0) then
            (
                append used_layers layer_ref
                append layer_nodes #(obj)
            )
            else
            (
                append layer_nodes[idx] obj
            )
        )

        for i = 1 to used_layers.count do
        (
            local layer_ref = used_layers[i]
            local nodes_in_layer = layer_nodes[i]
            local orig_name = layer_ref.name

            if (orig_name == "0") then continue

            local is_parent_layer = (orig_name == parent_layer.name)
            if (is_parent_layer) then continue

            local clean_name = orig_name
            if (search_str != "") then
            (
                try ( clean_name = rx.Replace orig_name search_str replace_str ) catch()
            )

            if (clean_name == "") then clean_name = orig_name

            local exact_old_layer = undefined
            local is_shared = false

            for ol in old_layers do 
            (
                if (toLower ol.name == toLower clean_name) then 
                (
                    exact_old_layer = ol
                    is_shared = true
                    exit
                )
            )

            if (not is_shared) then 
            (
                for j = 0 to (LayerManager.count - 1) do 
                (
                    local test_layer = LayerManager.getLayer j
                    if (matchPattern test_layer.name pattern:("* - " + clean_name) ignoreCase:true) then 
                    (
                        is_shared = true
                        exit
                    )
                )
            )

            local is_old_layer = (findItem old_layers layer_ref > 0)
            if (is_parent_layer) then is_shared = true

            if (is_shared) then
            (
                if (exact_old_layer != undefined) then
                (
                    local ex_parent = exact_old_layer.getParent()
                    if (ex_parent != undefined and exact_old_layer.name != ex_parent.name) then
                    (
                        local new_ex_name = ex_parent.name + " - " + clean_name
                        if (exact_old_layer.name != new_ex_name) then
                        (
                            local check_exist = LayerManager.getLayerFromName new_ex_name
                            if (check_exist == undefined) then try(exact_old_layer.setName new_ex_name) catch()
                        )
                    )
                )

				
                local new_layer_name = if prefix_layers then parent_layer.name + " - " + clean_name else clean_name
				
				
                local target_layer = LayerManager.getLayerFromName new_layer_name
                
                if (target_layer == undefined) then
                (
                    target_layer = LayerManager.newLayerFromName new_layer_name
                )
                try(target_layer.setParent parent_layer) catch()

                for obj in nodes_in_layer do 
                (
                    if (isValidNode obj) then target_layer.addNode obj
                )

                if (not is_old_layer and not is_parent_layer) then
                (
                    try(LayerManager.deleteLayerByName orig_name) catch()
                )
            )
            else
            (
                local target_layer = LayerManager.getLayerFromName clean_name

                if (target_layer == undefined) then
                (
                    try(layer_ref.setName clean_name) catch()
                    try(layer_ref.setParent parent_layer) catch()
                )
                else
                (
                    if (target_layer != layer_ref) then
                    (
                        for obj in nodes_in_layer do 
                        (
                            if (isValidNode obj) then target_layer.addNode obj
                        )
                        if (not is_old_layer and not is_parent_layer) then
                        (
                            try(LayerManager.deleteLayerByName orig_name) catch()
                        )
                    )
                    try(target_layer.setParent parent_layer) catch()
                )
            )
        )
    ),

    function groupObjectsByDwgFile parent_layer final_new_nodes file_name =
    (
        if (settings.group_objects and final_new_nodes.count > 0) then
        (
            local top_level_nodes = #()
            
            for obj in final_new_nodes do
            (
                if (isValidNode obj) then
                    if (obj.parent == undefined or findItem final_new_nodes obj.parent == 0) then
                        append top_level_nodes obj
            )
            
            if (top_level_nodes.count > 0) then
            (
                local grp = group top_level_nodes name:file_name select:false
                parent_layer.addNode grp
            )
        )
    ),
    
    function fixImportedMeshes final_new_nodes =
    (
        if (settings.fix_flatten_mesh and final_new_nodes.count > 0) then
        (
            local imported_meshes = #()
            for obj in final_new_nodes do
            (
                if (isValidNode obj and superClassOf obj == GeometryClass) then
                (
                    append imported_meshes obj
                )
            )
            
            if (imported_meshes.count > 0) then
            (
                try ( extractBottomSplines imported_meshes ) catch ( format "extractBottomSplines failed.\n" )
            )
        )
    ),

    function importDwgFile dwg_file is_first:false prefix_layers:true =
    (
        local file_name = getFilenameFile dwg_file
        local parent_layer = createParentLayer file_name
        local old_layers = getCurrentLayers()
        local old_nodes = objects as array

        if (settings.show_prompt and is_first) then
        (
            importFile dwg_file using:DWGIMP
        )
        else
        (
            importFile dwg_file #noPrompt using:DWGIMP
        )

        local temp_new_nodes = #()
        for obj in objects do
        (
            if (findItem old_nodes obj == 0) then append temp_new_nodes obj
        )

        cleanUpDwgBlocks temp_new_nodes

        local final_new_nodes = for obj in temp_new_nodes where isValidNode obj collect obj

		
		processImportedLayers parent_layer final_new_nodes old_layers prefix_layers:prefix_layers
		
        groupObjectsByDwgFile parent_layer final_new_nodes file_name
		
        fixImportedMeshes final_new_nodes
    )
)
