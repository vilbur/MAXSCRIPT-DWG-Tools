struct TrimCore
(
    function isNodeUnhidden node_val = (isValidNode node_val and node_val.isHidden == false),
    function isNodeLayerVisible node_val = (isValidNode node_val and (node_val.layer == undefined or node_val.layer.on)),
    
    function isNodeProcessable node_val ignore_frozen:true =
    (
        if (isValidNode node_val and isNodeUnhidden node_val and isNodeLayerVisible node_val) then
            if (not (ignore_frozen == true and node_val.isFrozen == true)) then return true
        return false
    ),

    function isSplineShapeNode node_val = (isValidNode node_val and superClassOf node_val == Shape),

    function isVolumeDummy node_val =
    (
        if (isValidNode node_val and node_val.name != "TRIM_CANVAS" and node_val.name != "TRIM_SELECTION") then
        (
            local c_str = (classOf node_val) as string
            if (c_str == "VolumeHelper" or superClassOf node_val == helper) then return true
        )
        return false
    ),

    function openParentGroups node_val =
    (
        local opened_count = 0
        if (isValidNode node_val) then
        (
            local p_node = node_val.parent
            while (p_node != undefined) do
            (
                if (isGroupHead p_node) then try ( setGroupOpen p_node true; opened_count += 1 ) catch()
                p_node = p_node.parent
            )
        )
        opened_count
    ),

    function openGroupsOfUnhiddenObjects ignore_frozen:true =
    (
        local opened_count = 0
        for n in objects where (isNodeProcessable n ignore_frozen:ignore_frozen) do opened_count += openParentGroups n
        opened_count
    ),

    function getVolumeBoundsData vol_node =
    (
        local vol_tm = vol_node.objectTransform
        #(nodeGetBoundingBox vol_node vol_tm, inverse vol_tm)
    ),

    function isWorldPointInsideVolume world_point bounds_data tol_val:0.001 =
    (
        local min_p = bounds_data[1][1], max_p = bounds_data[1][2], vol_inv = bounds_data[2]
        local p = world_point * vol_inv
        (p.x >= (min_p.x - tol_val) and p.x <= (max_p.x + tol_val) and \
         p.y >= (min_p.y - tol_val) and p.y <= (max_p.y + tol_val) and \
         p.z >= (min_p.z - tol_val) and p.z <= (max_p.z + tol_val))
    ),

    function deleteEmptySplines shape_node =
    (
        local del_count = 0
        for sp_idx = (numSplines shape_node) to 1 by -1 where (numSegments shape_node sp_idx) < 1 do
        (
            deleteSpline shape_node sp_idx
            del_count += 1
        )
        del_count
    ),
    
    function batchPrepareShapes shapes_arr thresh_val =
    (
        if (shapes_arr.count > 0) then
        (
            local prev_cmd_mode = getCommandPanelTaskMode()
            setCommandPanelTaskMode #modify
            
            for s in shapes_arr do
            (
                if (classOf s != SplineShape) then convertToSplineShape s
                select s
                subObjectLevel = 1
                for sp_idx = 1 to (numSplines s) do
                (
                    local k_count = numKnots s sp_idx
                    local k_arr = for k = 1 to k_count collect k
                    setKnotSelection s sp_idx k_arr keep:true
                )
                try ( s.weldThreshold = thresh_val; splineOps.weld s ) catch ()
                subObjectLevel = 0
            )
            clearSelection()
            if (prev_cmd_mode != undefined) then setCommandPanelTaskMode prev_cmd_mode
        )
    ),

    function trimShapeByVolume shape_node b_data tol_val:0.001 delete_empty:true =
    (
        local del_k = 0, del_sp = 0
        if (isValidNode shape_node and isSplineShapeNode shape_node) then
        (
            for sp_idx = (numSplines shape_node) to 1 by -1 do
            (
                local k_count = numKnots shape_node sp_idx
                local is_closed = isClosed shape_node sp_idx
                local out_states = for k = 1 to k_count collect (not (isWorldPointInsideVolume (getKnotPoint shape_node sp_idx k) b_data tol_val:tol_val))
                
                for k_idx = k_count to 1 by -1 do
                (
                    if (out_states[k_idx]) then
                    (
                        local should_del = false
                        if (k_count > 2) then
                        (
                            local p_idx, n_idx
                            if (is_closed) then
                            (
                                p_idx = if (k_idx == 1) then k_count else (k_idx - 1)
                                n_idx = if (k_idx == k_count) then 1 else (k_idx + 1)
                            )
                            else
                            (
                                p_idx = k_idx - 1
                                n_idx = k_idx + 1
                            )
                            local has_p = (p_idx >= 1 and p_idx <= k_count)
                            local has_n = (n_idx >= 1 and n_idx <= k_count)
                            if (has_p and has_n) then
                            (
                                if (out_states[p_idx] == out_states[n_idx]) then should_del = true
                            )
                            else if (has_p and not has_n) then
                            (
                                if (out_states[p_idx]) then should_del = true
                            )
                            else if (not has_p and has_n) then
                            (
                                if (out_states[n_idx]) then should_del = true
                            )
                        )
                        else if (k_count == 2) then
                        (
                            local o_idx = if (k_idx == 1) then 2 else 1
                            if (out_states[o_idx]) then should_del = true
                        )
                        else if (k_count == 1) then
                        (
                            should_del = true
                        )
                        
                        if (should_del) then
                        (
                            deleteKnot shape_node sp_idx k_idx
                            del_k += 1
                        )
                    )
                )
            )
            del_sp = deleteEmptySplines shape_node
            updateShape shape_node
            if (delete_empty and (numSplines shape_node) < 1) then delete shape_node
        )
        #(del_k, del_sp)
    ),

    function run vol_node quiet:false tol_val:0.001 del_empty:true ignore_frz:true =
    (
        if (vol_node == undefined or not isValidNode vol_node) then 
        (
            if (not quiet) then messageBox "Select a valid helper volume." title:"Trim Splines"
            return undefined
        )
        openGroupsOfUnhiddenObjects ignore_frozen:ignore_frz
        local b_data = getVolumeBoundsData vol_node
        local s_nodes = for n in objects where (isSplineShapeNode n and n != vol_node and isNodeProcessable n ignore_frozen:ignore_frz) collect n
        batchPrepareShapes s_nodes tol_val
        
        local p_count = 0, d_s = 0, d_k = 0, d_sp = 0
        for i = 1 to s_nodes.count do
        (
            if (not quiet) then (format "\rProcessing % of %..." i s_nodes.count; windows.processPostedMessages())
            if (isValidNode s_nodes[i]) then
            (
                local res = trimShapeByVolume s_nodes[i] b_data tol_val:tol_val delete_empty:del_empty
                p_count += 1; d_k += res[1]; d_sp += res[2]
                if (not isValidNode s_nodes[i]) then d_s += 1
            )
        )
        if (not quiet) then format "\n"
        if (not quiet) then completeRedraw()
        if (not quiet) then messageBox ("Processed: " + p_count as string + "\nDeleted Knots: " + d_k as string) title:"Trim Splines By Volume"
        #(p_count, d_s, d_k, d_sp)
    )
)