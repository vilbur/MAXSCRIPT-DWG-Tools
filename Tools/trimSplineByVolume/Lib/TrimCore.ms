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
            if (classOf node_val == VolumeHelper) then return true
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

    /* Get 2D world bounds from volume helper.
       Z is intentionally ignored by all trim tests. */
    function getVolumeBoundsData vol_node =
    (
        if (isValidNode vol_node) then
        (
            local vol_box = nodeGetBoundingBox vol_node (matrix3 1)
            local min_p = vol_box[1]
            local max_p = vol_box[2]

            if (min_p.x > max_p.x) then
            (
                local swap_x = min_p.x
                min_p.x = max_p.x
                max_p.x = swap_x
            )

            if (min_p.y > max_p.y) then
            (
                local swap_y = min_p.y
                min_p.y = max_p.y
                max_p.y = swap_y
            )

            #(min_p, max_p)
        )
        else
        (
            undefined
        )
        -- return
    ),

    /* Test point against volume in XY only.
       Z is infinite, so point.z is never tested. */
    function isWorldPointInsideVolume world_point bounds_data tol_val:0.001 =
    (
        if (bounds_data != undefined and bounds_data.count >= 2) then
        (
            local min_p = bounds_data[1]
            local max_p = bounds_data[2]

            (world_point.x >= (min_p.x - tol_val) and world_point.x <= (max_p.x + tol_val) and \
             world_point.y >= (min_p.y - tol_val) and world_point.y <= (max_p.y + tol_val))
        )
        else
        (
            false
        )
        -- return
    ),

    /* Test bbox against volume in XY only.
       Used by canvas/object deletion paths. */
    function isWorldBBoxOutsideVolume2D world_box bounds_data tol_val:0.001 =
    (
        if (bounds_data != undefined and bounds_data.count >= 2 and world_box != undefined and world_box.count >= 2) then
        (
            local min_p = bounds_data[1]
            local max_p = bounds_data[2]
            local box_min = world_box[1]
            local box_max = world_box[2]

            (box_max.x < (min_p.x - tol_val) or box_min.x > (max_p.x + tol_val) or \
             box_max.y < (min_p.y - tol_val) or box_min.y > (max_p.y + tol_val))
        )
        else
        (
            true
        )
        -- return
    ),

    /* Delete only truly empty spline containers.
       Splines with knots are preserved here to avoid invalid curve updates. */
    function deleteEmptySplines shape_node =
    (
        local del_count = 0
        for sp_idx = (numSplines shape_node) to 1 by -1 where (numKnots shape_node sp_idx) < 1 do
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

    /* Trim one shape by 2D volume bounds.
       Whole-inside splines are never touched. */
    function trimShapeByVolume shape_node b_data tol_val:0.001 delete_empty:true =
    (
        local del_k = 0
        local del_sp = 0

        if (isValidNode shape_node and isSplineShapeNode shape_node and b_data != undefined) then
        (
            for sp_idx = (numSplines shape_node) to 1 by -1 do
            (
                local k_count = numKnots shape_node sp_idx

                if (k_count > 0) then
                (
                    local inside_states = for k = 1 to k_count collect (isWorldPointInsideVolume (getKnotPoint shape_node sp_idx k) b_data tol_val:tol_val)
                    local inside_count = 0

                    for state_item in inside_states where state_item do inside_count += 1

                    if (inside_count == k_count) then
                    (
                        /* Whole spline is inside XY volume. Do nothing. */
                    )
                    else if (inside_count == 0) then
                    (
                        deleteSpline shape_node sp_idx
                        del_sp += 1
                    )
                    else
                    (
                        local is_closed = isClosed shape_node sp_idx
                        local min_safe_knots = if is_closed then 3 else 2

                        if (inside_count >= min_safe_knots) then
                        (
                            for k_idx = k_count to 1 by -1 where (not inside_states[k_idx]) do
                            (
                                deleteKnot shape_node sp_idx k_idx
                                del_k += 1
                            )
                        )
                    )
                )
            )

            del_sp += deleteEmptySplines shape_node

            if ((numSplines shape_node) > 0) then
            (
                try
                (
                    updateShape shape_node
                )
                catch
                (
                    format "updateShape failed on %. Shape kept for safety.\n" shape_node.name
                )
            )

            if (delete_empty and isValidNode shape_node and ((numSplines shape_node) < 1)) then delete shape_node
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