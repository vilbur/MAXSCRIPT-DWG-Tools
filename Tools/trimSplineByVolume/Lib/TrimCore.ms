/*
Trim Splines By Volume - Core trimming rules
Version: 6.0

These rules are the source of truth for trimShapeByVolume().
Do not change trimming behavior without updating this header and tests.

RULE 01 - 2D trim only.
    Volume bounds are tested only in XY. Z is infinite and must never delete or keep anything by height.

RULE 02 - Whole-inside spline is protected.
    If all knots of one spline are inside the XY volume, that spline is not modified.

RULE 03 - Whole-outside spline is deleted.
    If no knot of one spline is inside the XY volume, that spline is deleted.

RULE 04 - Mixed spline deletes outside knots only when safe.
    If some knots are inside and some are outside, outside knots are deleted only when the remaining
    inside knots can still form a valid spline: open spline needs 2 knots, closed spline needs 3 knots.

RULE 05 - Unsafe mixed spline is kept unchanged.
    If deleting outside knots would leave an invalid spline, the spline is not modified.
    This prevents one-knot splines, bad updateShape calls, and accidental deletion of inside data.

RULE 06 - Empty spline containers can be removed.
    Truly empty spline sub-objects are removed. If the shape has no splines after trimming, the node can be deleted.

RULE 07 - Keep v4.1 knot test behavior.
    Knot positions are tested the same way as the last known correct v4.1 core.
    Do not replace this with a different transform-space test unless every rule test is updated and passes.
*/

struct TrimCore
(
    trim_rule_keep_whole_inside = #keepWholeInside,
    trim_rule_delete_whole_outside = #deleteWholeOutside,
    trim_rule_delete_outside_knots = #deleteOutsideKnots,
    trim_rule_keep_invalid_mixed = #keepInvalidMixed,

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
        if (isValidNode node_val and node_val.name != "TRIM_CANVAS") then
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

    /* Get knot point used by trim rules.
       This intentionally keeps the v4.1 trim test behavior. */
    function getTrimKnotTestPoint shape_node spline_index knot_index =
    (
        local knot_point = [0.0, 0.0, 0.0]

        try
        (
            knot_point = getKnotPoint shape_node spline_index knot_index
        )
        catch
        (
            knot_point = [0.0, 0.0, 0.0]
        )

        knot_point
        -- return
    ),

    /* Resolve the trimming rule for one spline.
       trimShapeByVolume() executes only this returned rule. */
    function getSplineTrimRuleData shape_node spline_index b_data tol_val:0.001 =
    (
        local knot_count = numKnots shape_node spline_index
        local inside_states = #()
        local inside_count = 0
        local min_safe_knots = 2
        local rule_name = trim_rule_keep_invalid_mixed

        if (knot_count < 1) then
        (
            rule_name = trim_rule_delete_whole_outside
        )
        else
        (
            inside_states = for knot_index = 1 to knot_count collect (isWorldPointInsideVolume (getTrimKnotTestPoint shape_node spline_index knot_index) b_data tol_val:tol_val)

            for state_item in inside_states where state_item do inside_count += 1

            if (inside_count == knot_count) then
            (
                rule_name = trim_rule_keep_whole_inside
            )
            else if (inside_count == 0) then
            (
                rule_name = trim_rule_delete_whole_outside
            )
            else
            (
                local spline_closed = isClosed shape_node spline_index
                min_safe_knots = if spline_closed then 3 else 2

                if (inside_count >= min_safe_knots) then
                (
                    rule_name = trim_rule_delete_outside_knots
                )
                else
                (
                    rule_name = trim_rule_keep_invalid_mixed
                )
            )
        )

        #(rule_name, inside_states, inside_count, knot_count, min_safe_knots)
        -- return
    ),

    /* Trim one shape by 2D volume bounds.
       Whole-inside splines are never touched. */
    function trimShapeByVolume shape_node b_data tol_val:0.001 delete_empty:true =
    (
        local del_k = 0
        local del_sp = 0

        if (isValidNode shape_node and isSplineShapeNode shape_node and b_data != undefined) then
        (
            for spline_index = (numSplines shape_node) to 1 by -1 do
            (
                local rule_data = getSplineTrimRuleData shape_node spline_index b_data tol_val:tol_val
                local rule_name = rule_data[1]
                local inside_states = rule_data[2]
                local knot_count = rule_data[4]

                if (rule_name == trim_rule_keep_whole_inside) then
                (
                    /* RULE 02: protected whole-inside spline. */
                )
                else if (rule_name == trim_rule_delete_whole_outside) then
                (
                    /* RULE 03: whole-outside or empty spline. */
                    deleteSpline shape_node spline_index
                    del_sp += 1
                )
                else if (rule_name == trim_rule_delete_outside_knots) then
                (
                    /* RULE 04: safe mixed spline. */
                    for knot_index = knot_count to 1 by -1 where (not inside_states[knot_index]) do
                    (
                        deleteKnot shape_node spline_index knot_index
                        del_k += 1
                    )
                )
                else
                (
                    /* RULE 05: unsafe mixed spline is kept unchanged. */
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
        -- return
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