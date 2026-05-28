struct TrimOperations
(
    core = undefined,
    
    function getParentLayer lay_name =
    (
        for i = 0 to LayerManager.count - 1 do
        (
            local p = LayerManager.getLayer i
            if (p != undefined) do
            (
                try (
                    for c = 1 to p.getNumChildren() do
                    (
                        local child = p.getChild c
                        if (child != undefined and child.name == lay_name) then return p
                    )
                ) catch()
            )
        )
        return undefined
    ),

    function isTopLayer lay_name =
    (
        return ((getParentLayer lay_name) == undefined)
    ),
    
    function turnOnLayerChain lay_val =
    (
        if (lay_val != undefined) then
        (
            lay_val.on = true
            local p_lay = getParentLayer lay_val.name
            if (p_lay != undefined) then turnOnLayerChain p_lay
        )
    ),
    
    function unhideLayerHierarchy lay_val =
    (
        lay_val.on = true
        local l_nodes = #()
        lay_val.nodes &l_nodes
        for n in l_nodes where isValidNode n do n.isHidden = false
        try ( for c = 1 to lay_val.getNumChildren() do unhideLayerHierarchy (lay_val.getChild c) ) catch()
    ),
    
    function getVolumesInLayerTree lay_val =
    (
        local arr = #(), n_arr = #()
        lay_val.nodes &n_arr
        for n in n_arr where (core.isVolumeDummy n) do append arr n
        for i = 1 to lay_val.getNumChildren() do
        (
            local c_vols = getVolumesInLayerTree (lay_val.getChild i)
            for v in c_vols do append arr v
        )
        arr
    ),
    
    function collectAllNodesInLayerTree lay_val =
    (
        local arr = #(), n_arr = #()
        lay_val.nodes &n_arr
        for n in n_arr do append arr n
        for i = 1 to lay_val.getNumChildren() do
        (
            local c_nodes = collectAllNodesInLayerTree (lay_val.getChild i)
            for cn in c_nodes do append arr cn
        )
        arr
    ),
    
    function deleteAllNodesInLayerTree lay_val =
    (
        if (lay_val != undefined) then
        (
            local l_nodes = #()
            lay_val.nodes &l_nodes
            for n in l_nodes where isValidNode n do delete n
            for i = 1 to lay_val.getNumChildren() do deleteAllNodesInLayerTree (lay_val.getChild i)
        )
    ),
    
    function deleteLayerTree lay_val =
    (
        if (lay_val != undefined and lay_val.name != "0") then
        (
            for i = lay_val.getNumChildren() to 1 by -1 do deleteLayerTree (lay_val.getChild i)
            LayerManager.deleteLayerByName lay_val.name
        )
    ),
    
    function getOrCreateLayer orig_lay top_name o_names n_lays =
    (
        local idx = findItem o_names orig_lay.name
        if (idx > 0) then return n_lays[idx]
        
        local is_top = isTopLayer orig_lay.name
        local p_lay = getParentLayer orig_lay.name
        
        local n_name = if (is_top) then top_name else (top_name + " - " + orig_lay.name)
        
        local n_lay = LayerManager.getLayerFromName n_name
        if (n_lay == undefined) then n_lay = LayerManager.newLayerFromName n_name
        
        append o_names orig_lay.name; append n_lays n_lay
        
        if (p_lay != undefined) then
        (
            local n_p_lay = getOrCreateLayer p_lay top_name o_names n_lays
            n_lay.setParent n_p_lay
        )
        n_lay
    ),
    
    function recreateLayerTree o_nodes c_nodes top_name =
    (
        local o_names = #(), n_layers = #()
        for i = 1 to o_nodes.count do
        (
            local o_n = o_nodes[i], c_n = c_nodes[i]
            if (isValidNode c_n and isValidNode o_n) then
            (
                c_n.name = o_n.name
                local n_lay = getOrCreateLayer o_n.layer top_name o_names n_layers
                n_lay.addNode c_n
            )
        )
    ),
    
    function compareDist a b =
    (
        if (a[5] < b[5]) then -1
        else if (a[5] > b[5]) then 1
        else 0
    ),
    
    function generateCanvasVolume =
    (
        undo "Generate Canvas" on
        (
            local exist = getNodeByName "TRIM_CANVAS"
            if (isValidNode exist) then delete exist
            local d_layer = LayerManager.getLayer 0
            if (d_layer != undefined) then d_layer.on = true
            core.openGroupsOfUnhiddenObjects ignore_frozen:true
            local s_data = #(), t_knots = 0
            for n in objects where (core.isSplineShapeNode n and n.name != "TRIM_CANVAS" and not isGroupHead n and not isGroupMember n and core.isNodeProcessable n ignore_frozen:true) do
            (
                local bb = nodeGetBoundingBox n (matrix3 1)
                local cent = (bb[1] + bb[2]) / 2.0
                local dist = length cent
                local k_count = 0
                for sp = 1 to (numSplines n) do k_count += numKnots n sp
                if (k_count > 0) then
                (
                    append s_data #(n, bb[1], bb[2], cent, dist, k_count)
                    t_knots += k_count
                )
            )
            local h_size = 500.0
            if (s_data.count > 0) then
            (
                qsort s_data compareDist
                local min_p = [1e9, 1e9, 1e9], max_p = [-1e9, -1e9, -1e9], a_knots = 0, t_target = t_knots * 0.90
                for d in s_data do
                (
                    a_knots += d[6]
                    if (d[2].x < min_p.x) then min_p.x = d[2].x
                    if (d[2].y < min_p.y) then min_p.y = d[2].y
                    if (d[2].z < min_p.z) then min_p.z = d[2].z
                    if (d[3].x > max_p.x) then max_p.x = d[3].x
                    if (d[3].y > max_p.y) then max_p.y = d[3].y
                    if (d[3].z > max_p.z) then max_p.z = d[3].z
                    if (a_knots >= t_target) then exit
                )
                local m_ext = amax (abs min_p.x) (abs min_p.y) (abs min_p.z) (abs max_p.x) (abs max_p.y) (abs max_p.z)
                h_size = m_ext * 1.05 
                if (h_size <= 0) then h_size = 500.0
            )
            try (
                local d = VolumeHelper name:"TRIM_CANVAS" pos:[0,0,0] size:h_size color:(color 255 128 0)
                if (d_layer != undefined) then d_layer.addNode d
                select d; actionMan.executeAction 0 "311"
            ) catch ()
        )
    ),
    
    function trimCanvas quiet:false ignore_frz:true =
    (
        local c_node = getNodeByName "TRIM_CANVAS"
        if (c_node == undefined or not isValidNode c_node) then 
        (
            if (not quiet) then messageBox "TRIM_CANVAS not found." title:"Trim Canvas"
            return undefined
        )
        core.openGroupsOfUnhiddenObjects ignore_frozen:ignore_frz
        local c_bb = nodeGetBoundingBox c_node (matrix3 1)
        local c_min = c_bb[1], c_max = c_bb[2]
        local d_objs = for n in objects where (n != c_node and not isGroupHead n and core.isNodeProcessable n ignore_frozen:ignore_frz) collect n
        local d_count = 0
        undo "Trim Canvas" on
        (
            for n in d_objs do
            (
                local o_bb = nodeGetBoundingBox n (matrix3 1)
                local is_out = (o_bb[2].x < c_min.x or o_bb[1].x > c_max.x or o_bb[2].y < c_min.y or o_bb[1].y > c_max.y or o_bb[2].z < c_min.z or o_bb[1].z > c_max.z)
                if (is_out) then ( delete n; d_count += 1 )
            )
        )
        if (not quiet) then completeRedraw()
        if (not quiet) then messageBox ("Canvas Trim Complete.\nDeleted: " + d_count as string) title:"Trim Canvas"
    ),
    
    function generateVolumes =
    (
        undo "Generate Volumes" on
        (
            local s_nodes = for n in selection where (isValidNode n and n.name != "TRIM_CANVAS" and not (core.isVolumeDummy n) and not isGroupHead n) collect n
            if (s_nodes.count > 0) then
            (
                local min_p = [1e9, 1e9, 1e9], max_p = [-1e9, -1e9, -1e9], valid_b = false
                for n in s_nodes do
                (
                    local bb = nodeGetBoundingBox n (matrix3 1)
                    if (bb[1].x < min_p.x) then min_p.x = bb[1].x; if (bb[1].y < min_p.y) then min_p.y = bb[1].y; if (bb[1].z < min_p.z) then min_p.z = bb[1].z
                    if (bb[2].x > max_p.x) then max_p.x = bb[2].x; if (bb[2].y > max_p.y) then max_p.y = bb[2].y; if (bb[2].z > max_p.z) then max_p.z = bb[2].z
                    valid_b = true
                )
                if (valid_b) then
                (
                    local exist = getNodeByName "TRIM_SELECTION"
                    if (isValidNode exist) then delete exist
                    local cent = (min_p + max_p) / 2.0, sz = max_p - min_p, h_size = (sz.x + sz.y) / 4.0
                    if (h_size <= 0) then h_size = 1.0
                    try ( local d = VolumeHelper name:"TRIM_SELECTION" pos:cent size:h_size color:(color 0 255 0); select d ) catch ()
                )
                messageBox "Generated single volume for selected objects." title:"Generate Volumes"
            )
            else
            (
                local g_count = 0
                for i = 0 to LayerManager.count - 1 do
                (
                    local lay = LayerManager.getLayer i
                    if (lay.on and lay.name != "0") then
                    (
                        if (isTopLayer lay.name) then
                        (
                            local ex_vols = getVolumesInLayerTree lay
                            if (ex_vols.count == 0) then
                            (
                                local a_nodes = collectAllNodesInLayerTree lay
                                local min_p = [1e9, 1e9, 1e9], max_p = [-1e9, -1e9, -1e9], valid_b = false
                                
                                for n in a_nodes where (isValidNode n and n.name != lay.name and n.name != "TRIM_CANVAS" and not (core.isVolumeDummy n) and not isGroupHead n) do
                                (
                                    local bb = nodeGetBoundingBox n (matrix3 1)
                                    if (bb[1].x < min_p.x) then min_p.x = bb[1].x; if (bb[1].y < min_p.y) then min_p.y = bb[1].y; if (bb[1].z < min_p.z) then min_p.z = bb[1].z
                                    if (bb[2].x > max_p.x) then max_p.x = bb[2].x; if (bb[2].y > max_p.y) then max_p.y = bb[2].y; if (bb[2].z > max_p.z) then max_p.z = bb[2].z
                                    valid_b = true
                                )
                                if (valid_b) then
                                (
                                    local cent = (min_p + max_p) / 2.0, sz = max_p - min_p, h_size = (sz.x + sz.y) / 4.0
                                    if (h_size <= 0) then h_size = 1.0
                                    local l_col = color 255 255 255; try (l_col = lay.wireColor) catch()
                                    try ( local d = VolumeHelper name:lay.name pos:cent size:h_size color:l_col; lay.addNode d; g_count += 1 ) catch ()
                                )
                            )
                        )
                    )
                )
                messageBox ("Generated " + g_count as string + " volume helpers.") title:"Generate Volumes"
            )
        )
    ),
    
    function runMassMode quiet:false tol_val:0.001 del_empty:true ignore_frz:true =
    (
        local t_lays = #()
        for i = 0 to LayerManager.count - 1 do
        (
            local lay = LayerManager.getLayer i
            if (lay.name != "0" and findString lay.name "_TO_DELETE_" == undefined and isTopLayer lay.name) then append t_lays lay
        )
        
        local t_p = 0, t_dk = 0, a_vols = #()
        
        for t_lay in t_lays do
        (
            local v_arr = getVolumesInLayerTree t_lay
            if (v_arr.count == 1) then
            (
                local v_n = v_arr[1]; append a_vols v_n
                if (not quiet) then (format "\rMass Mode: '%'..." v_n.name; windows.processPostedMessages())
                for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = false
                turnOnLayerChain t_lay; unhideLayerHierarchy t_lay
                local res = core.run v_n quiet:true tol_val:tol_val del_empty:del_empty ignore_frz:ignore_frz
                if (res != undefined) then ( t_p += res[1]; t_dk += res[3] )
            )
            else if (v_arr.count > 1) then
            (
                local o_n = t_lay.name
                t_lay.setname (o_n + "_TO_DELETE_" + (timestamp() as string))
                local a_nodes = collectAllNodesInLayerTree t_lay
                local c_nodes = for n in a_nodes where (findItem v_arr n == 0) collect n
                
                for v_idx = 1 to v_arr.count do
                (
                    local v_n = v_arr[v_idx]; append a_vols v_n
                    if (not quiet) then (format "\rMass Mode: '%'..." v_n.name; windows.processPostedMessages())
                    
                    local top_name = v_n.name
                    
                    local c_out = #()
                    if (c_nodes.count > 0) then 
                    ( 
                        maxOps.cloneNodes c_nodes cloneType:#copy newNodes:&c_out
                        recreateLayerTree c_nodes c_out top_name 
                    )
                    
                    local dummy_layer = LayerManager.getLayerFromName top_name
                    if (dummy_layer == undefined) then dummy_layer = LayerManager.newLayerFromName top_name
                    dummy_layer.addNode v_n
                    
                    for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = false
                    turnOnLayerChain dummy_layer; unhideLayerHierarchy dummy_layer
                    local res = core.run v_n quiet:true tol_val:tol_val del_empty:del_empty ignore_frz:ignore_frz
                    if (res != undefined) then ( t_p += res[1]; t_dk += res[3] )
                )
                deleteAllNodesInLayerTree t_lay; (LayerManager.getLayer 0).current = true; deleteLayerTree t_lay
            )
        )
        for i = 0 to LayerManager.count - 1 do (LayerManager.getLayer i).on = true
        undo "Delete Mass Volumes" on ( for v in a_vols where isValidNode v do delete v )
        if (not quiet) then format "\n"
        completeRedraw()
        if (not quiet) then messageBox ("Mass Mode Complete\nProcessed Splines: " + t_p as string + "\nKnots Deleted: " + t_dk as string) title:"Mass Mode"
    )
)