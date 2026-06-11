struct SplineToObjConvertor_v
(
    version = "0.15",
    z_tolerance = 0.001,
    xy_tolerance = 0.01,
    size_tolerance = 0.001,
    prog_bar = undefined,
    lbl_status = undefined,
    prefix = "",
    dim_tolerance = 0.1,
    instanced_count = 0,
    deleted_nested_count = 0,

    /*  Update rollout progress.
	    
        Keeps UI responsive during long spline operations. */
    function updateProgress val msg =
    (
        if this.prog_bar != undefined then
        (
            try (this.prog_bar.color = (color 0 120 255)) catch()
            this.prog_bar.value = val
        )

        if this.lbl_status != undefined then
        (
            this.lbl_status.text = this.prefix + msg
        )

        windows.processPostedMessages()
    ),

    /*  Explode one spline shape into one node per spline element.
        This is the fast copy/deleteSpline workflow used before merge. */
    function explodeSplineToSplineElements shape_node suffix_separator:"-" =
    (
        created_nodes = #()

        if isValidNode shape_node then
        (
            spline_count = 0

            try
            (
                spline_count = numSplines shape_node
            )
            catch
            (
                spline_count = 0
            )

            if spline_count > 0 then
            (
                digit_count = 1

                if spline_count > 9 then
                (
                    digit_count = (spline_count as string).count
                )

                with redraw off
                (
                    for spline_index = 1 to spline_count do
                    (
                        suffix_number = spline_index as string

                        while suffix_number.count < digit_count do
                        (
                            suffix_number = "0" + suffix_number
                        )

                        copy_node = copy shape_node

                        try
                        (
                            source_layer = shape_node.layer
                            source_layer.addNode copy_node
                        )
                        catch
                        (
                        )

                        copy_node.name = uniqueName (shape_node.name + suffix_separator + suffix_number)

                        for delete_index = spline_count to 1 by -1 do
                        (
                            if delete_index != spline_index then
                            (
                                deleteSpline copy_node delete_index
                            )
                        )

                        updateShape copy_node
                        append created_nodes copy_node
                    )
                )
            )
        )

        created_nodes -- return
    ),

    /*  Extract each spline element into a separate shape node.
        Progress is updated once to avoid slowing down large source shapes. */
    function extractSplines source_shape =
    (
        extracted_shapes = #()

        if isValidNode source_shape then
        (
            this.updateProgress 0.0 "Exploding spline elements..."
            extracted_shapes = this.explodeSplineToSplineElements source_shape suffix_separator:"-"
            this.updateProgress 100.0 ("Exploded spline elements: " + (extracted_shapes.count as string))
        )

        extracted_shapes -- return
    ),

    /*  Get fixed world bbox data of one shape.
        This avoids local transform mismatch while testing pivots. */
    function getWorldBoxData target_shape =
    (
        bounds_array = nodeGetBoundingBox target_shape (matrix3 1)
        bbox_min = bounds_array[1]
        bbox_max = bounds_array[2]
        bbox_size = bbox_max - bbox_min
        bbox_diag = length bbox_size

        #(target_shape, bbox_diag, bbox_min, bbox_max, target_shape.pos, bbox_size) -- return
    ),

    /*  Find largest bbox shape in current working array.
        Invalid nodes are ignored. */
    function getLargestShapeIndex shape_array =
    (
        largest_index = 0
        largest_size = -1.0

        for i = 1 to shape_array.count do
        (
            if isValidNode shape_array[i] then
            (
                shape_data = this.getWorldBoxData shape_array[i]

                if shape_data[2] > largest_size then
                (
                    largest_size = shape_data[2]
                    largest_index = i
                )
            )
        )

        largest_index -- return
    ),

    /*  Test world pivot position against fixed world bbox.
        Z tolerance is separate because spline bboxes often have 0 Z depth. */
    function isPivotInsideWorldBox world_pivot bbox_min bbox_max =
    (
        effective_z_tolerance = this.z_tolerance

        if effective_z_tolerance <= 0.0 then
        (
            effective_z_tolerance = 0.001
        )

        in_x = (world_pivot.x >= (bbox_min.x - this.xy_tolerance)) and (world_pivot.x <= (bbox_max.x + this.xy_tolerance))
        in_y = (world_pivot.y >= (bbox_min.y - this.xy_tolerance)) and (world_pivot.y <= (bbox_max.y + this.xy_tolerance))
        in_z = (world_pivot.z >= (bbox_min.z - effective_z_tolerance)) and (world_pivot.z <= (bbox_max.z + effective_z_tolerance))

        (in_x and in_y and in_z) -- return
    ),

    /*  Attach one child shape into base shape.
        UpdateShape is intentionally not called here. */
    function attachShapeToBase base_shape child_shape =
    (
        attached_ok = false

        if (isValidNode base_shape and isValidNode child_shape) then
        (
            try
            (
                addAndWeld base_shape child_shape 0.0
                attached_ok = true
            )
            catch
            (
                format "SplineToObjConvertor_v %: Attach failed: % -> %\n" this.version child_shape.name base_shape.name
                attached_ok = false
            )
        )

        if attached_ok then
        (
            if isValidNode child_shape then
            (
                delete child_shape
            )
        )

        attached_ok -- return
    ),

    /*  Test if two world bbox sizes are equal.
        Dimensions are compared directly in world XYZ order. */
    function isSameBBoxSize size_a size_b =
    (
        same_x = (abs (size_a.x - size_b.x)) <= this.dim_tolerance
        same_y = (abs (size_a.y - size_b.y)) <= this.dim_tolerance
        same_z = (abs (size_a.z - size_b.z)) <= this.dim_tolerance

        (same_x and same_y and same_z) -- return
    ),

    /*  Get world bbox center of a node.
        Used to preserve world placement when replacing by instance. */
    function getWorldBoxCenter target_shape =
    (
        bbox_center = [0, 0, 0]

        if isValidNode target_shape then
        (
            bounds_array = nodeGetBoundingBox target_shape (matrix3 1)
            bbox_center = (bounds_array[1] + bounds_array[2]) * 0.5
        )

        bbox_center -- return
    ),

    /*  Instance master shape onto target shape placement.
        Target bbox center is preserved after replacement. */
    function instanceMasterAtShape master_shape target_shape =
    (
        new_instance = undefined

        if (isValidNode master_shape and isValidNode target_shape) then
        (
            source_name = target_shape.name
            master_wirecolor = master_shape.wirecolor
            source_transform = target_shape.transform
            source_center = this.getWorldBoxCenter target_shape
            source_layer = undefined

            try
            (
                source_layer = target_shape.layer
            )
            catch
            (
                source_layer = undefined
            )

            new_instance = instance master_shape
            new_instance.transform = source_transform

            new_center = this.getWorldBoxCenter new_instance
            new_instance.pos = new_instance.pos + (source_center - new_center)
            new_instance.wirecolor = master_wirecolor

            delete target_shape
            new_instance.name = source_name

            try
            (
                if source_layer != undefined then
                (
                    source_layer.addNode new_instance
                )
            )
            catch
            (
            )
        )

        new_instance -- return
    ),

    /*  Delete smaller nested shapes inside fixed target bbox.
        The instance already contains these children from master shape. */
    function deleteNestedChildrenFromWorking target_shape working_shapes master_diag =
    (
        target_data = this.getWorldBoxData target_shape
        target_min = target_data[3]
        target_max = target_data[4]
        delete_nodes = #()
        deleted_count = 0

        for child_shape in working_shapes do
        (
            if (isValidNode child_shape and child_shape != target_shape) then
            (
                child_data = this.getWorldBoxData child_shape
                child_diag = child_data[2]
                child_pivot = child_data[5]
                child_is_smaller = child_diag < (master_diag - this.size_tolerance)

                if child_is_smaller then
                (
                    if (this.isPivotInsideWorldBox child_pivot target_min target_max) then
                    (
                        append delete_nodes child_shape
                    )
                )
            )
        )

        for child_shape in delete_nodes do
        (
            child_index = findItem working_shapes child_shape

            if child_index > 0 then
            (
                deleteItem working_shapes child_index
            )

            if isValidNode child_shape then
            (
                delete child_shape
            )

            deleted_count += 1
        )

        deleted_count -- return
    ),

    /*  Merge clusters by largest fixed container bbox.
        Same-size containers are immediately replaced by instances of current master. */
    function groupAndMerge extracted_shapes =
    (
        working_shapes = #()
        final_merged_shapes = #()
        this.instanced_count = 0
        this.deleted_nested_count = 0

        for s in extracted_shapes do
        (
            if isValidNode s then
            (
                centerPivot s
                append working_shapes s
            )
        )

        total_shapes = working_shapes.count
        processed_count = 0

        if total_shapes > 0 then
        (
            while working_shapes.count > 0 do
            (
                base_index = this.getLargestShapeIndex working_shapes

                if base_index < 1 then
                (
                    exit
                )

                base_shape = working_shapes[base_index]
                base_data = this.getWorldBoxData base_shape
                base_diag = base_data[2]
                base_fixed_min = base_data[3]
                base_fixed_max = base_data[4]
                base_bbox_size = base_data[6]

                deleteItem working_shapes base_index
                attach_nodes = #()

                for child_shape in working_shapes do
                (
                    if isValidNode child_shape then
                    (
                        child_data = this.getWorldBoxData child_shape
                        child_diag = child_data[2]
                        child_pivot = child_data[5]
                        is_smaller = child_diag < (base_diag - this.size_tolerance)

                        if is_smaller then
                        (
                            if (this.isPivotInsideWorldBox child_pivot base_fixed_min base_fixed_max) then
                            (
                                append attach_nodes child_shape
                            )
                        )
                    )
                )

                if attach_nodes.count > 0 then
                (
                    for child_shape in attach_nodes do
                    (
                        child_index = findItem working_shapes child_shape

                        if child_index > 0 then
                        (
                            deleteItem working_shapes child_index
                        )

                        this.attachShapeToBase base_shape child_shape
                    )

                    updateShape base_shape
                    centerPivot base_shape
                )

                if isValidNode base_shape then
                (
                    base_shape.name = uniqueName "Reinstated_Window_"
                    append final_merged_shapes base_shape

                    same_size_nodes = #()

                    for other_shape in working_shapes do
                    (
                        if isValidNode other_shape then
                        (
                            other_data = this.getWorldBoxData other_shape
                            other_bbox_size = other_data[6]

                            if (this.isSameBBoxSize base_bbox_size other_bbox_size) then
                            (
                                append same_size_nodes other_shape
                            )
                        )
                    )

                    for target_shape in same_size_nodes do
                    (
                        if isValidNode target_shape then
                        (
                            deleted_count = this.deleteNestedChildrenFromWorking target_shape working_shapes base_diag
                            this.deleted_nested_count += deleted_count

                            target_index = findItem working_shapes target_shape

                            if target_index > 0 then
                            (
                                deleteItem working_shapes target_index
                            )

                            new_instance = this.instanceMasterAtShape base_shape target_shape

                            if isValidNode new_instance then
                            (
                                append final_merged_shapes new_instance
                                this.instanced_count += 1
                            )
                        )
                    )
                )

                processed_count = total_shapes - working_shapes.count
                prog_val = (processed_count as float / total_shapes) * 100.0
                prog_msg = "Merging optimized clusters: " + (processed_count as string) + " / " + (total_shapes as string) + " | Instances: " + (this.instanced_count as string)
                this.updateProgress prog_val prog_msg
            )
        )

        final_merged_shapes -- return
    ),

    /*  Process full source shape in one call.
        Used by Execute Convertor path. */
    function processShape source_shape =
    (
        process_result = undefined

        if (isValidNode source_shape and (classOf source_shape == SplineShape or classOf source_shape == line)) then
        (
            extracted = this.extractSplines source_shape
            process_result = this.groupAndMerge extracted
        )
        else
        (
            print "Selected object is not a valid spline shape."
        )

        process_result -- return
    ),

    on create do
    (
        if this.z_tolerance <= 0.0 then
        (
            this.z_tolerance = 0.001
        )
    )
)

try (destroyDialog spline_obj_rollout) catch()

rollout spline_obj_rollout "Spline Extractor 0.15" width:280
(
    local ini_file = (getDir #plugcfg) + @"\spline_to_obj_settings.ini"
    local original_shapes = #()
    local extracted_shapes = #()
    local splitted_shapes = #()

    label lbl_sel_count "Selected: 0" color:(color 0 255 0) align:#left offset:[0,5]

    label lbl_z_threshold "Z Threshold:" align:#left width:82 across:4 offset:[0,5]
    spinner spn_depth_threshold "" range:[0.001, 1000.0, 20.0] type:#float fieldwidth:64 align:#left width:86 offset:[-2,3]
    label lbl_depth_units "units" align:#left width:60 offset:[20,6]
    button btn_load_depth "L" width:22 height:20 align:#right tooltip:"Load 2x lowest bbox size from selection in cm" offset:[0,3]

    checkbox chk_weld_before "Weld before splitting" checked:true align:#left offset:[0,5]
    label lbl_weld_threshold "Weld Threshold:" align:#left width:92 across:3 offset:[0,0]
    spinner spn_weld_threshold "" range:[0.001, 1000.0, 1.0] type:#float fieldwidth:64 align:#left width:86 offset:[-2,-2]
    label lbl_weld_units "mm" align:#left width:40 offset:[4,1]
    checkbox chk_corner_knots "Make corner knots" checked:true align:#left
    button btn_execute "Execute Convertor" width:190 height:30 align:#center offset:[0,10]

    label lbl_status "Status: Idle" align:#left offset:[0,5] width:250
    progressbar pb_progress color:(color 0 120 255) height:10 width:250 align:#center offset:[0,5]

    group "Select Sets (LMB: Sel | RMB: Isolate)"
    (
        button btn_sel_original "Original" width:170 height:24 align:#center
        button btn_sel_splitted "Splitted" width:170 height:24 align:#center
    )

    timer tck_update interval:200 active:true

    /*  Return minimum allowed Z threshold value in centimeters.
        Threshold is never allowed to be zero. */
    function getMinThresholdValue =
    (
        0.001 -- return
    )

    /*  Clamp Z threshold spinner to safe positive centimeter value.
        This also fixes INI values saved as 0.0. */
    function setThresholdSafe threshold_value =
    (
        safe_value = threshold_value

        if safe_value < getMinThresholdValue() then
        (
            safe_value = getMinThresholdValue()
        )

        spn_depth_threshold.value = safe_value

        safe_value -- return
    )

    /*  Return minimum allowed weld threshold in millimeters.
        Weld threshold is never allowed to be zero. */
    function getMinWeldThresholdValue =
    (
        0.001 -- return
    )

    /*  Clamp weld threshold spinner to safe positive millimeter value.
        This avoids broken zero threshold weld calls. */
    function setWeldThresholdSafe threshold_mm =
    (
        safe_value = threshold_mm

        if safe_value < getMinWeldThresholdValue() then
        (
            safe_value = getMinWeldThresholdValue()
        )

        spn_weld_threshold.value = safe_value

        safe_value -- return
    )

    /*  Convert millimeter spinner value to current 3ds Max system units.
        If unit conversion fails, millimeter value is used directly. */
    function getMillimeterValueInSystemUnits value_mm =
    (
        system_value = value_mm

        try
        (
            system_value = units.decodeValue ((value_mm as string) + "mm")
        )
        catch
        (
            system_value = value_mm
        )

        system_value -- return
    )

    /*  Convert centimeter spinner value to current 3ds Max system units.
        UI display for Z threshold is always centimeters. */
    function getCentimeterValueInSystemUnits value_cm =
    (
        system_value = value_cm

        try
        (
            system_value = units.decodeValue ((value_cm as string) + "cm")
        )
        catch
        (
            system_value = value_cm
        )

        system_value -- return
    )

    /*  Convert current system unit value to UI centimeters.
        Used only by manual load from selection button. */
    function getSystemValueInCentimeters value_system =
    (
        centimeter_value = value_system

        try
        (
            one_cm = units.decodeValue "1cm"

            if one_cm > 0.0 then
            (
                centimeter_value = value_system / one_cm
            )
        )
        catch
        (
            centimeter_value = value_system
        )

        centimeter_value -- return
    )

    /*  Get Z threshold spinner value converted from centimeters to system units.
        This value is used by bbox tests in world space. */
    function getZThresholdValueInSystemUnits =
    (
        z_threshold_cm = setThresholdSafe spn_depth_threshold.value
        z_threshold_system = getCentimeterValueInSystemUnits z_threshold_cm

        z_threshold_system -- return
    )

    /*  Save rollout settings.
        Only persistent user options are written. */
    function saveSettings =
    (
        setThresholdSafe spn_depth_threshold.value
        setINISetting ini_file "Settings" "z_threshold_cm" (spn_depth_threshold.value as string)
        setINISetting ini_file "Settings" "weld_threshold_mm" (spn_weld_threshold.value as string)
        setINISetting ini_file "Settings" "weld_before" (chk_weld_before.checked as string)
        setINISetting ini_file "Settings" "corner_knots" (chk_corner_knots.checked as string)
    )

    /*  Load rollout settings.
        Missing values keep current defaults. */
    function loadSettings =
    (
        val = getINISetting ini_file "Settings" "z_threshold_cm"
        if val != "" then
        (
            setThresholdSafe (val as float)
        )
        else
        (
            setThresholdSafe spn_depth_threshold.value
        )

        val = getINISetting ini_file "Settings" "weld_threshold_mm"
        if val != "" then
        (
            setWeldThresholdSafe (val as float)
        )
        else
        (
            setWeldThresholdSafe spn_weld_threshold.value
        )

        val = getINISetting ini_file "Settings" "weld_before"
        if val != "" then
        (
            chk_weld_before.checked = (val == "true")
        )

        val = getINISetting ini_file "Settings" "corner_knots"
        if val != "" then
        (
            chk_corner_knots.checked = (val == "true")
        )

    )

    /*  Get lowest local bbox axis size from one node.
        Flat spline Z size can return 0.0, which is valid here. */
    function getLowestBBoxAxisSize target_node =
    (
        lowest_axis_size = undefined

        if isValidNode target_node then
        (
            bounds_array = nodeLocalBoundingBox target_node
            bbox_min = bounds_array[1]
            bbox_max = bounds_array[2]
            bbox_size = bbox_max - bbox_min
            axis_sizes = #(abs bbox_size.x, abs bbox_size.y, abs bbox_size.z)

            for axis_value in axis_sizes do
            (
                if lowest_axis_size == undefined then
                (
                    lowest_axis_size = axis_value
                )
                else
                (
                    if axis_value < lowest_axis_size then
                    (
                        lowest_axis_size = axis_value
                    )
                )
            )
        )

        if lowest_axis_size == undefined then
        (
            lowest_axis_size = 0.0
        )

        lowest_axis_size -- return
    )

    /*  Set Z threshold from current selection.
        Threshold is 2x the lowest local bbox axis size in selection. */
    function loadZThresholdFromSelection =
    (
        lowest_selected_size = undefined
        threshold_loaded = false

        if selection.count > 0 then
        (
            for obj in selection do
            (
                if isValidNode obj then
                (
                    current_size = getLowestBBoxAxisSize obj

                    if lowest_selected_size == undefined then
                    (
                        lowest_selected_size = current_size
                    )
                    else
                    (
                        if current_size < lowest_selected_size then
                        (
                            lowest_selected_size = current_size
                        )
                    )
                )
            )

            if lowest_selected_size != undefined then
            (
                setThresholdSafe (getSystemValueInCentimeters (lowest_selected_size * 2.0))
                threshold_loaded = true
            )
        )

        threshold_loaded -- return
    )

    /*  Make all spline knots corner and all segments line.
        Used before splitting source shape. */
    function makeCornerKnots target_shape =
    (
        if isValidNode target_shape then
        (
            for s = 1 to (numSplines target_shape) do
            (
                for k = 1 to (numKnots target_shape s) do
                (
                    setKnotType target_shape s k #corner
                )

                for seg = 1 to (numSegments target_shape s) do
                (
                    setSegmentType target_shape s seg #line
                )
            )

            updateShape target_shape
        )
    )

    /*  Weld spline knots on prepared source copy before explode.
        Uses 3ds Max 2026 weldSpline shape_node threshold command. */
    function weldSplineKnots target_shape threshold_mm =
    (
        weld_ok = false

        if isValidNode target_shape then
        (
            weld_threshold = getMillimeterValueInSystemUnits (setWeldThresholdSafe threshold_mm)

            try
            (
                weldSpline target_shape weld_threshold
                updateShape target_shape
                weld_ok = true
            )
            catch
            (
                format "SplineToObjConvertor_v 0.15: weldSpline failed on % with threshold % mm.\n" target_shape.name threshold_mm
                weld_ok = false
            )
        )

        weld_ok -- return
    )

    /*  Get valid nodes from stored node array.
        Deleted nodes are skipped before select, isolate, or visibility actions. */
    function getValidNodesFromArray target_array =
    (
        valid_nodes = #()

        for obj in target_array do
        (
            if isValidNode obj then
            (
                append valid_nodes obj
            )
        )

        valid_nodes -- return
    )

    /*  Detect if Ctrl key is pressed during button click.
        Used to switch LMB from selection to visibility toggle. */
    function isControlPressed =
    (
        control_is_pressed = false

        try
        (
            control_is_pressed = keyboard.controlPressed
        )
        catch
        (
            control_is_pressed = false
        )

        control_is_pressed -- return
    )

    /*  Toggle node visibility for stored node set.
        If any node is visible, all valid nodes are hidden; otherwise all are unhidden. */
    function toggleNodeSetVisibility target_array =
    (
        valid_nodes = getValidNodesFromArray target_array
        has_visible_node = false
        hidden_count = 0
        shown_count = 0

        for obj in valid_nodes do
        (
            if (not obj.isHidden) then
            (
                has_visible_node = true
            )
        )

        if valid_nodes.count > 0 then
        (
            if has_visible_node then
            (
                for obj in valid_nodes do
                (
                    hide obj
                    hidden_count += 1
                )

                lbl_status.text = "Status: Hidden objects: " + (hidden_count as string)
                format "SplineToObjConvertor_v 0.15: Hidden objects: %\n" hidden_count
            )
            else
            (
                for obj in valid_nodes do
                (
                    unhide obj
                    shown_count += 1
                )

                lbl_status.text = "Status: Shown objects: " + (shown_count as string)
                format "SplineToObjConvertor_v 0.15: Shown objects: %\n" shown_count
            )
        )
        else
        (
            print "No valid objects in this set."
        )

        valid_nodes.count -- return
    )

    /*  Select or isolate stored node set.
        Invalid deleted nodes are skipped. */
    function handleSelection target_array isolate_mode =
    (
        valid_nodes = getValidNodesFromArray target_array

        if valid_nodes.count > 0 then
        (
            clearSelection()
            select valid_nodes

            if isolate_mode then
            (
                IsolateSelection.EnterIsolateSelectionMode()
            )
        )
        else
        (
            print "No valid objects in this set."
        )
    )

    /*  Build prepared copy from source shape.
        Original shape is never modified. */
    function makeWorkingCopy source_shape =
    (
        working_copy = undefined

        if (isValidNode source_shape and (classOf source_shape == SplineShape or classOf source_shape == line)) then
        (
            working_copy = copy source_shape

            try
            (
                source_layer = source_shape.layer
                source_layer.addNode working_copy
            )
            catch
            (
            )

            convertToSplineShape working_copy
            working_copy.name = uniqueName (source_shape.name + "_ExtractSource_")

            if chk_weld_before.checked then
            (
                weldSplineKnots working_copy spn_weld_threshold.value
            )

            if chk_corner_knots.checked then
            (
                makeCornerKnots working_copy
            )
        )

        working_copy -- return
    )

    /*  Run only extraction step.
        Result is kept in Extracted set for testing. */
    function runExtractOnly select_after:true =
    (
        if selection.count > 0 then
        (
            original_shapes = #()
            extracted_shapes = #()
            splitted_shapes = #()

            for obj in selection do
            (
                append original_shapes obj
            )

            for i = 1 to original_shapes.count do
            (
                source_shape = original_shapes[i]
                shape_prefix = "[Extract " + (i as string) + "/" + (original_shapes.count as string) + "] "
                lbl_status.text = shape_prefix + "Preparing..."
                try (pb_progress.color = (color 0 120 255)) catch()
                pb_progress.value = 0
                windows.processPostedMessages()

                working_copy = makeWorkingCopy source_shape

                if working_copy != undefined then
                (
                    window_manager = SplineToObjConvertor_v z_tolerance:(getZThresholdValueInSystemUnits()) prog_bar:pb_progress lbl_status:lbl_status prefix:shape_prefix
                    current_extracted = window_manager.extractSplines working_copy

                    for s in current_extracted do
                    (
                        append extracted_shapes s
                    )

                    if isValidNode working_copy then
                    (
                        delete working_copy
                    )
                )
                else
                (
                    format "Skipped invalid source: %\n" source_shape
                )
            )

            if select_after then
            (
                handleSelection extracted_shapes false
            )

            lbl_status.text = "Extract complete. Extracted: " + (extracted_shapes.count as string)
            pb_progress.value = 100
            try (pb_progress.color = (color 0 220 0)) catch()
            format "SplineToObjConvertor_v 0.15: Extract complete. Extracted nodes: %\n" extracted_shapes.count
        )
        else
        (
            print "Please select shapes to extract."
        )

        extracted_shapes -- return
    )

    /*  Run merge step on given extracted nodes or stored extracted nodes.
        Execute passes extracted nodes directly so selection fallback cannot merge the original shape by mistake. */
    function runMergeOnly input_nodes:undefined =
    (
        merge_input = #()
        splitted_shapes = #()

        if input_nodes != undefined then
        (
            for obj in input_nodes do
            (
                if isValidNode obj then
                (
                    append merge_input obj
                )
            )
        )

        if merge_input.count == 0 then
        (
            for obj in extracted_shapes do
            (
                if isValidNode obj then
                (
                    append merge_input obj
                )
            )
        )

        if merge_input.count == 0 then
        (
            for obj in selection do
            (
                if (isValidNode obj and (classOf obj == SplineShape or classOf obj == line)) then
                (
                    append merge_input obj
                )
            )
        )

        if merge_input.count > 0 then
        (
            lbl_status.text = "Merging extracted shapes..."
            try (pb_progress.color = (color 0 120 255)) catch()
            pb_progress.value = 0
            windows.processPostedMessages()

            window_manager = SplineToObjConvertor_v z_tolerance:(getZThresholdValueInSystemUnits()) prog_bar:pb_progress lbl_status:lbl_status prefix:"[Merge] "
            final_merged_shapes = window_manager.groupAndMerge merge_input

            for rw in final_merged_shapes do
            (
                if isValidNode rw then
                (
                    append splitted_shapes rw
                )
            )

            handleSelection splitted_shapes false
            lbl_status.text = "Merge complete. Clusters: " + (splitted_shapes.count as string) + " | Instances: " + (window_manager.instanced_count as string) + " | Deleted nested: " + (window_manager.deleted_nested_count as string)
            pb_progress.value = 100
            try (pb_progress.color = (color 0 220 0)) catch()
            format "SplineToObjConvertor_v 0.15: Merge complete. Clusters: %, Instances: %, Deleted nested: %\n" splitted_shapes.count window_manager.instanced_count window_manager.deleted_nested_count
        )
        else
        (
            print "No extracted shapes to merge. Use Extract only first, or select extracted spline nodes."
        )

        splitted_shapes -- return
    )

    on spline_obj_rollout open do
    (
        loadSettings()
        lbl_depth_units.text = "cm"
        lbl_weld_units.text = "mm"

    )

    on spline_obj_rollout close do
    (
        saveSettings()
    )

    on tck_update tick do
    (
        lbl_sel_count.text = "Selected: " + (selection.count as string)
    )

    on spn_depth_threshold changed val do
    (
        if val < getMinThresholdValue() then
        (
            spn_depth_threshold.value = getMinThresholdValue()
        )
    )

    on spn_weld_threshold changed val do
    (
        if val < getMinWeldThresholdValue() then
        (
            spn_weld_threshold.value = getMinWeldThresholdValue()
        )
    )

    on btn_load_depth pressed do
    (
        if loadZThresholdFromSelection() then
        (
            lbl_status.text = "Status: Z threshold loaded from selection"
        )
        else
        (
            print "Please select shapes to calculate the bounding box threshold."
        )
    )


    on btn_execute pressed do
    (
        if selection.count > 0 then
        (
            try (pb_progress.color = (color 0 120 255)) catch()

            current_extracted = runExtractOnly select_after:false

            if (current_extracted != undefined and current_extracted.count > 0) then
            (
                extracted_shapes = current_extracted
                runMergeOnly input_nodes:current_extracted
            )
            else
            (
                print "No extracted spline elements were created. Merge skipped."
            )

            try (pb_progress.color = (color 0 220 0)) catch()
            print "SplineToObjConvertor_v 0.15: Execute Convertor complete."
        )
        else
        (
            print "Please select shapes to process."
        )
    )

    on btn_sel_original pressed do
    (
        if isControlPressed() then
        (
            toggleNodeSetVisibility original_shapes
        )
        else
        (
            handleSelection original_shapes false
        )
    )

    on btn_sel_original rightclick do
    (
        handleSelection original_shapes true
    )


    on btn_sel_splitted pressed do
    (
        if isControlPressed() then
        (
            toggleNodeSetVisibility splitted_shapes
        )
        else
        (
            handleSelection splitted_shapes false
        )
    )

    on btn_sel_splitted rightclick do
    (
        handleSelection splitted_shapes true
    )
)

createDialog spline_obj_rollout
