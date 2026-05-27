/*
    Description: Core Logic Methods for DWG Mass Importer
    Version: 0.55
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

    function processImportedLayers parent_layer new_nodes old_layers =
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

                local new_layer_name = parent_layer.name + " - " + clean_name
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

    function getTopLayerUnderParent layer_ref parent_layer =
    (
        local top_layer = layer_ref
        local current_layer = layer_ref
        local search_done = false

        while (current_layer != undefined and search_done == false) do
        (
            if (current_layer == parent_layer) then
            (
                top_layer = parent_layer
                search_done = true
            )
            else
            (
                local parent_ref = undefined
                try(parent_ref = current_layer.getParent()) catch(parent_ref = undefined)

                if (parent_ref == parent_layer) then
                (
                    top_layer = current_layer
                    search_done = true
                )
                else
                (
                    current_layer = parent_ref
                )
            )
        )

        top_layer
    ),

    function collectTopHierarchyNodes nodes_array =
    (
        local top_nodes = #()

        for obj in nodes_array do
        (
            if (isValidNode obj) then
            (
                if (obj.parent == undefined or findItem nodes_array obj.parent == 0) then
                (
                    append top_nodes obj
                )
            )
        )

        top_nodes
    ),

    function collectNodeTransforms nodes_array =
    (
        local transform_data = #()

        for obj in nodes_array do
        (
            if (isValidNode obj) then
            (
                append transform_data #(obj, obj.transform)
            )
        )

        transform_data
    ),

    function restoreNodeTransforms transform_data =
    (
        for item in transform_data do
        (
            if (item.count == 2 and isValidNode item[1]) then
            (
                try(item[1].transform = item[2]) catch()
            )
        )
    ),

    function groupObjectsByDwgFile parent_layer final_new_nodes file_name =
    (
        if (settings.group_objects and final_new_nodes.count > 0) then
        (
            local used_top_layers = #()
            local layer_nodes = #()

            for obj in final_new_nodes do
            (
                if (isValidNode obj) then
                (
                    local top_layer = getTopLayerUnderParent obj.layer parent_layer
                    local layer_index = findItem used_top_layers top_layer

                    if (layer_index == 0) then
                    (
                        append used_top_layers top_layer
                        append layer_nodes #(obj)
                    )
                    else
                    (
                        append layer_nodes[layer_index] obj
                    )
                )
            )

            for i = 1 to used_top_layers.count do
            (
                local top_layer = used_top_layers[i]
                local nodes_in_top_layer = layer_nodes[i]
                local top_level_nodes = collectTopHierarchyNodes nodes_in_top_layer

                if (top_level_nodes.count > 0) then
                (
                    local transform_data = collectNodeTransforms nodes_in_top_layer
                    local group_name = top_layer.name

                    if (top_layer == parent_layer) then
                    (
                        group_name = file_name
                    )

                    local grp = undefined
                    try(grp = group top_level_nodes name:group_name select:false) catch(grp = undefined)

                    if (isValidNode grp) then
                    (
                        try(top_layer.addNode grp) catch()
                        restoreNodeTransforms transform_data
                    )
                )
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

    function importDwgFile dwg_file =
    (
        local file_name = getFilenameFile dwg_file
        local parent_layer = createParentLayer file_name
        local old_layers = getCurrentLayers()
        local old_nodes = objects as array

        importFile dwg_file #noPrompt using:DWGIMP

        local temp_new_nodes = #()
        for obj in objects do
        (
            if (findItem old_nodes obj == 0) then append temp_new_nodes obj
        )

        cleanUpDwgBlocks temp_new_nodes

        local final_new_nodes = for obj in temp_new_nodes where isValidNode obj collect obj

        processImportedLayers parent_layer final_new_nodes old_layers
        groupObjectsByDwgFile parent_layer final_new_nodes file_name
        fixImportedMeshes final_new_nodes
    )
)