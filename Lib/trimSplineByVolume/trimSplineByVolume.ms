clearListener(); print("Cleared in: "+getSourceFileName())
/* version 0.99
    
	Trim splines by selected volume (Reverse Knot Deletion Method - Fixed Matrix)
    Select one box/helper volume, then run: trimSplineByVolume.run quiet:false
*/

struct trimSplineByVolume_v
(
    volume_node = undefined,
    tolerance = 0.001,
    script_version = "v0.99",

    /* Check if a node is valid and its own hidden flag is off. */
    function isNodeUnhidden node_value =
    (
        result_value = false
        if (isValidNode node_value) then
        (
            result_value = (node_value.isHidden == false)
        )
        result_value -- return
    ),

    /* Check if node layer is visible. */
    function isNodeLayerVisible node_value =
    (
        result_value = false
        if (isValidNode node_value) then
        (
            layer_value = node_value.layer
            if (layer_value != undefined) then
            (
                result_value = layer_value.on
            )
        )
        result_value -- return
    ),

    /* Check if a node should be processed. */
    function isNodeProcessable node_value =
    (
        result_value = false
        if (isValidNode node_value) then
        (
            if ((isNodeUnhidden node_value) and (isNodeLayerVisible node_value)) then
            (
                result_value = true
            )
        )
        result_value -- return
    ),

    /* Check if node is a shape class. */
    function isSplineShapeNode node_value =
    (
        result_value = false
        if (isValidNode node_value) then
        (
            if (superClassOf node_value == Shape) then
            (
                result_value = true
            )
        )
        result_value -- return
    ),

    /* Open all parent groups of given node. */
    function openParentGroups node_value =
    (
        opened_count = 0
        if (isValidNode node_value) then
        (
            parent_node = node_value.parent
            while (parent_node != undefined) do
            (
                if (isGroupHead parent_node) then
                (
                    try ( setGroupOpen parent_node true; opened_count += 1 ) catch()
                )
                parent_node = parent_node.parent
            )
        )
        opened_count -- return
    ),

    /* Open groups containing visible nodes on visible layers. */
    function openGroupsOfUnhiddenObjects =
    (
        opened_count = 0
        for node_value in objects do
        (
            if (isNodeProcessable node_value) then
            (
                opened_count += openParentGroups node_value
            )
        )
        opened_count -- return
    ),

    /* Get selected volume node. */
    function getSelectedVolumeNode =
    (
        found_node = undefined
        if (selection.count > 0) then
        (
            for node_value in selection while (found_node == undefined) do
            (
                if ((isValidNode node_value) and (superClassOf node_value != Shape)) then
                (
                    found_node = node_value
                )
            )
            if (found_node == undefined) then
            (
                found_node = selection[1]
            )
        )
        found_node -- return
    ),

    /* Build local volume bounds data. */
    function getVolumeBoundsData volume_node_value =
    (
        volume_tm = volume_node_value.objectTransform
        volume_tm_inv = inverse volume_tm
        bbox_value = nodeGetBoundingBox volume_node_value volume_tm
        #(bbox_value[1], bbox_value[2], volume_tm_inv) -- return
    ),

    /* Test world point against volume bounds. */
    function isWorldPointInsideVolume world_point bounds_data tolerance_value:0.001 =
    (
        min_point = bounds_data[1]
        max_point = bounds_data[2]
        volume_tm_inv = bounds_data[3]
        point_value = world_point * volume_tm_inv
        result_value = false

        if ((point_value.x >= (min_point.x - tolerance_value)) and (point_value.x <= (max_point.x + tolerance_value))) then
        (
            if ((point_value.y >= (min_point.y - tolerance_value)) and (point_value.y <= (max_point.y + tolerance_value))) then
            (
                if ((point_value.z >= (min_point.z - tolerance_value)) and (point_value.z <= (max_point.z + tolerance_value))) then
                (
                    result_value = true
                )
            )
        )
        result_value -- return
    ),

    /* Delete empty splines after knot cleanup (splines with < 1 segment). */
    function deleteEmptySplines shape_node =
    (
        deleted_count = 0
        for spline_index = (numSplines shape_node) to 1 by -1 do
        (
            if ((numSegments shape_node spline_index) < 1) then
            (
                deleteSpline shape_node spline_index
                deleted_count += 1
            )
        )
        deleted_count -- return
    ),
    
    /* Weld all knots of the shape using a specific threshold. */
    function weldAllKnots shape_node threshold_value:0.001 =
    (
        if (getCommandPanelTaskMode() != #modify) do setCommandPanelTaskMode mode:#modify
        if (selection.count != 1 or selection[1] != shape_node) do select shape_node
        if (modPanel.getCurrentObject() != shape_node.baseObject) do modPanel.setCurrentObject shape_node.baseObject
        
        subObjectLevel = 1
        max select all
        try (shape_node.baseObject.weldThreshold = threshold_value) catch ()
        splineOps.weld shape_node
        subObjectLevel = 0
        updateShape shape_node
    ),

    /* Trim shape by iterating and deleting outside knots directly. */
    function trimShapeByVolume shape_node bounds_data tolerance_value:0.001 delete_empty:true =
    (
        deleted_knot_count = 0
        deleted_spline_count = 0
        
        if (isValidNode shape_node and isSplineShapeNode shape_node) then
        (
            -- 1. Force collapse to SplineShape
            if (classOf shape_node != SplineShape) do
            (
                convertToSplineShape shape_node
            )

            -- 2. Weld all knots first
            weldAllKnots shape_node threshold_value:tolerance_value
            
            -- 3. Loop backward through splines and knots
            for spline_index = (numSplines shape_node) to 1 by -1 do
            (
                knot_count = numKnots shape_node spline_index
                
                for knot_index = knot_count to 1 by -1 do
                (
                    -- Evaluate current knot. 
                    -- FIX: getKnotPoint is ALREADY in world space, no need to multiply by objectTransform!
                    current_point = getKnotPoint shape_node spline_index knot_index
                    current_outside = not (isWorldPointInsideVolume current_point bounds_data tolerance_value:tolerance_value)
                    
                    if (knot_index == knot_count) then
                    (
                        -- If it is the last knot on the spline, and outside -> delete it
                        if (current_outside) do
                        (
                            deleteKnot shape_node spline_index knot_index
                            deleted_knot_count += 1
                        )
                    )
                    else if (knot_index > 1) then
                    (
                        -- If current and previous are outside -> delete current knot
                        prev_point = getKnotPoint shape_node spline_index (knot_index - 1)
                        prev_outside = not (isWorldPointInsideVolume prev_point bounds_data tolerance_value:tolerance_value)
                        
                        if (current_outside and prev_outside) do
                        (
                            deleteKnot shape_node spline_index knot_index
                            deleted_knot_count += 1
                        )
                    )
                )
            )
            
            -- 4. Clean up invalid/empty splines
            deleted_spline_count = deleteEmptySplines shape_node
            
            -- 5. Final update per object
            updateShape shape_node
            
            -- 6. Delete the whole object if empty
            if ((delete_empty == true) and ((numSplines shape_node) < 1)) then
            (
                delete shape_node
            )
        )
        #(deleted_knot_count, deleted_spline_count) -- return
    ),

    /* Collect visible spline shapes from visible layers. */
    function collectProcessShapes volume_node_value =
    (
        shape_nodes = #()
        for node_value in objects do
        (
            if ((isSplineShapeNode node_value) and (node_value != volume_node_value)) then
            (
                if (isNodeProcessable node_value) then
                (
                    append shape_nodes node_value
                )
            )
        )
        shape_nodes -- return
    ),

    /* Main run function. */
    function run quiet:false tolerance_value:0.001 delete_empty:true =
    (
        volume_node = getSelectedVolumeNode()
        processed_count = 0
        deleted_shape_count = 0
        deleted_knot_count = 0
        deleted_spline_count = 0
        opened_group_count = 0

        if (volume_node == undefined) then
        (
            messageBox "Select box/helper volume first." title:"Trim Splines By Volume"
        )
        else
        (
            opened_group_count = openGroupsOfUnhiddenObjects()
            bounds_data = getVolumeBoundsData volume_node
            shape_nodes = collectProcessShapes volume_node
            
            total_shapes = shape_nodes.count

            for i = 1 to total_shapes do
            (
                shape_node = shape_nodes[i]
                
                if (quiet == false) do
                (
                    format "\rProcessing % object from % objects..." i total_shapes
                    windows.processPostedMessages()
                )

                if (isValidNode shape_node) then
                (
                    trim_result = trimShapeByVolume shape_node bounds_data tolerance_value:tolerance_value delete_empty:delete_empty
                    processed_count += 1
                    deleted_knot_count += trim_result[1]
                    deleted_spline_count += trim_result[2]
                    if (isValidNode shape_node == false) then
                    (
                        deleted_shape_count += 1
                    )
                )
            )
            
            if (quiet == false and total_shapes > 0) do format "\n"

            if (quiet == false) then
            (
                message_text = "Trim Splines By Volume (" + script_version + ")\n\n"
                message_text += "Processed spline objects: " + processed_count as string + "\n"
                message_text += "Opened parent groups: " + opened_group_count as string + "\n"
                message_text += "Deleted knots: " + deleted_knot_count as string + "\n"
                message_text += "Deleted empty splines: " + deleted_spline_count as string + "\n"
                message_text += "Deleted empty shape nodes: " + deleted_shape_count as string
                messageBox message_text title:"Trim Splines By Volume"
            )
        )
        #(processed_count, deleted_knot_count, deleted_spline_count, deleted_shape_count) -- return
    ),

    /* Create small test scene. */
    function createTestScene =
    (
        delete objects
        volume_box = box name:"TRIM_VOLUME_BOX" length:100 width:100 height:100 pos:[0,0,0]
        test_shape = splineShape name:"TEST_SPLINE_PARTLY_INSIDE"
        addNewSpline test_shape
        addKnot test_shape 1 #corner #line [-200,0,0]
        addKnot test_shape 1 #corner #line [-150,0,0]
        addKnot test_shape 1 #corner #line [0,0,0]
        addKnot test_shape 1 #corner #line [40,0,0]
        updateShape test_shape

        test_shape_2 = splineShape name:"TEST_SPLINE_FULLY_OUTSIDE"
        addNewSpline test_shape_2
        addKnot test_shape_2 1 #corner #line [200,0,0]
        addKnot test_shape_2 1 #corner #line [300,0,0] 
        updateShape test_shape_2

        group_head = group #(test_shape, test_shape_2) name:"TEST_GROUP_HIDDEN_HEAD"
        group_head.isHidden = true
        setGroupOpen group_head false

        select volume_box
        #(volume_box, test_shape, test_shape_2) -- return
    ),

    on create do ()
)

/* Test code
	trimSplineByVolume = trimSplineByVolume_v()
    trimSplineByVolume.createTestScene()
    trimSplineByVolume.run quiet:false tolerance_value:0.001 delete_empty:true
*/

trimSplineByVolume = trimSplineByVolume_v()
trimSplineByVolume.run quiet:false tolerance_value:0.001 delete_empty:true