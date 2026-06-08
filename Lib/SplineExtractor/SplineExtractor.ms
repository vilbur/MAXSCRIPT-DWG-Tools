struct SplineToObjConvertor_v
(
    version = "0.04",
    z_tolerance = 0.0,
    xy_tolerance = 0.01,
    size_tolerance = 0.001,
    prog_bar = undefined,
    lbl_status = undefined,
    prefix = "",

    /*  Update rollout progress.
        Keeps UI responsive during long spline operations. */
    function updateProgress val msg =
    (
        if this.prog_bar != undefined then
        (
            this.prog_bar.value = val
        )

        if this.lbl_status != undefined then
        (
            this.lbl_status.text = this.prefix + msg
        )

        windows.processPostedMessages()
    ),

    /*  Extract each spline element into a separate shape node.
        Result nodes are centered before merge testing. */
    function extractSplines source_shape =
    (
        extracted_shapes = #()

        if isValidNode source_shape then
        (
            num_splines = numSplines source_shape

            for i = 1 to num_splines do
            (
                new_shape = copy source_shape
                convertToSplineShape new_shape

                for j = num_splines to 1 by -1 do
                (
                    if j != i then
                    (
                        deleteSpline new_shape j
                    )
                )

                updateShape new_shape
                centerPivot new_shape
                new_shape.name = uniqueName "Extracted_Spline_"
                append extracted_shapes new_shape

                prog_val = (i as float / num_splines) * 100.0
                prog_msg = "Extracting splines: " + (i as string) + " / " + (num_splines as string)
                this.updateProgress prog_val prog_msg
            )
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
        in_x = (world_pivot.x >= (bbox_min.x - this.xy_tolerance)) and (world_pivot.x <= (bbox_max.x + this.xy_tolerance))
        in_y = (world_pivot.y >= (bbox_min.y - this.xy_tolerance)) and (world_pivot.y <= (bbox_max.y + this.xy_tolerance))
        in_z = (world_pivot.z >= (bbox_min.z - this.z_tolerance)) and (world_pivot.z <= (bbox_max.z + this.z_tolerance))

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
                format "SplineExtractor %: Attach failed: % -> %\n" this.version child_shape.name base_shape.name
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

    /*  Merge clusters by largest fixed container bbox.
        Each container bbox is captured once and cannot grow during this pass. */
    function groupAndMerge extracted_shapes =
    (
        working_shapes = #()
        final_merged_shapes = #()

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
                base_size = base_data[2]
                fixed_min = base_data[3]
                fixed_max = base_data[4]

                deleteItem working_shapes base_index
                attach_indices = #()

                for i = 1 to working_shapes.count do
                (
                    child_shape = working_shapes[i]

                    if isValidNode child_shape then
                    (
                        child_data = this.getWorldBoxData child_shape
                        child_size = child_data[2]
                        child_pivot = child_data[5]
                        is_smaller = child_size < (base_size - this.size_tolerance)

                        if is_smaller then
                        (
                            if (this.isPivotInsideWorldBox child_pivot fixed_min fixed_max) then
                            (
                                append attach_indices i
                            )
                        )
                    )
                )

                if attach_indices.count > 0 then
                (
                    for a = attach_indices.count to 1 by -1 do
                    (
                        child_index = attach_indices[a]
                        child_shape = working_shapes[child_index]

                        if (this.attachShapeToBase base_shape child_shape) then
                        (
                            deleteItem working_shapes child_index
                        )
                    )

                    updateShape base_shape
                    centerPivot base_shape
                )

                if isValidNode base_shape then
                (
                    base_shape.name = uniqueName "Reinstated_Window_"
                    append final_merged_shapes base_shape
                )

                processed_count = total_shapes - working_shapes.count
                prog_val = (processed_count as float / total_shapes) * 100.0
                prog_msg = "Merging fixed clusters: " + (processed_count as string) + " / " + (total_shapes as string)
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
    )
)

struct SplineInstancer_v
(
    dim_tolerance = 0.05,
    prog_bar = undefined,
    lbl_status = undefined,
    prefix = "",

    /*  Update rollout progress.
        Keeps UI responsive during instancing. */
    function updateProgress val msg =
    (
        if this.prog_bar != undefined then
        (
            this.prog_bar.value = val
        )

        if this.lbl_status != undefined then
        (
            this.lbl_status.text = this.prefix + msg
        )

        windows.processPostedMessages()
    ),

    /*  Get local bbox dimensions of a shape.
        Used as one part of the instance signature. */
    function getDimensions target_shape =
    (
        bounds_array = nodeLocalBoundingBox target_shape
        s_min = bounds_array[1]
        s_max = bounds_array[2]

        (s_max - s_min) -- return
    ),

    /*  Count all knots in shape.
        Prevents different clusters with same outer bbox from becoming instances. */
    function getKnotCount target_shape =
    (
        knot_count = 0

        if isValidNode target_shape then
        (
            for s = 1 to (numSplines target_shape) do
            (
                knot_count += numKnots target_shape s
            )
        )

        knot_count -- return
    ),

    /*  Count all segments in shape.
        Extra guard for strict instance matching. */
    function getSegmentCount target_shape =
    (
        segment_count = 0

        if isValidNode target_shape then
        (
            for s = 1 to (numSplines target_shape) do
            (
                segment_count += numSegments target_shape s
            )
        )

        segment_count -- return
    ),

    /*  Test if two shapes are safe to instance.
        Dimensions alone are not enough for this tool. */
    function canInstanceShapes shape_a shape_b =
    (
        can_instance = false

        if (isValidNode shape_a and isValidNode shape_b) then
        (
            dim_a = this.getDimensions shape_a
            dim_b = this.getDimensions shape_b

            x_match = abs (dim_a.x - dim_b.x) <= this.dim_tolerance
            y_match = abs (dim_a.y - dim_b.y) <= this.dim_tolerance
            z_match = abs (dim_a.z - dim_b.z) <= this.dim_tolerance
            spline_match = (numSplines shape_a) == (numSplines shape_b)
            knot_match = (this.getKnotCount shape_a) == (this.getKnotCount shape_b)
            segment_match = (this.getSegmentCount shape_a) == (this.getSegmentCount shape_b)

            can_instance = x_match and y_match and z_match and spline_match and knot_match and segment_match
        )

        can_instance -- return
    ),

    /*  Replace equal merged shapes by instances.
        This is intentionally stricter than bbox-size only. */
    function reinstanceShapes merged_shapes =
    (
        master_shapes = #()
        instanced_results = #()

        if merged_shapes != undefined then
        (
            num_shapes = merged_shapes.count

            for i = 1 to num_shapes do
            (
                prog_val = (i as float / num_shapes) * 100.0
                prog_msg = "Instancing shapes: " + (i as string) + " / " + (num_shapes as string)
                this.updateProgress prog_val prog_msg

                current_shape = merged_shapes[i]

                if isValidNode current_shape then
                (
                    centerPivot current_shape
                    found_master = undefined

                    for m = 1 to master_shapes.count do
                    (
                        master = master_shapes[m]

                        if (this.canInstanceShapes current_shape master) then
                        (
                            found_master = master
                            exit
                        )
                    )

                    if found_master != undefined then
                    (
                        new_instance = instance found_master
                        new_instance.transform = current_shape.transform
                        new_instance.name = uniqueName (found_master.name + "_Instance_")
                        new_instance.wirecolor = found_master.wirecolor

                        delete current_shape
                        append instanced_results new_instance
                    )
                    else
                    (
                        append master_shapes current_shape
                        append instanced_results current_shape
                    )
                )
            )
        )
        else
        (
            print "Error: Input shapes array is undefined. Aborting instancing."
        )

        instanced_results -- return
    ),

    on create do
    (
    )
)

try (destroyDialog spline_obj_rollout) catch()

rollout spline_obj_rollout "Spline Convertor 0.04" width:220
(
    local ini_file = (getDir #plugcfg) + @"\spline_to_obj_settings.ini"
    local original_shapes = #()
    local extracted_shapes = #()
    local splitted_shapes = #()

    label lbl_sel_count "Selected: 0" color:(color 0 255 0) align:#left offset:[0,5]

    spinner spn_depth_threshold "Z Threshold: " range:[0.0, 1000.0, 0.0] type:#float align:#left width:165 across:2 offset:[0,5]
    button btn_load_depth "L" width:20 height:20 align:#right tooltip:"Load min depth from selection bounds" offset:[0,3]

    checkbox chk_weld_before "Weld before splitting" checked:true align:#left offset:[0,5]
    checkbox chk_corner_knots "Make corner knots" checked:true align:#left
    checkbox chk_make_instances "Instance equal merged shapes" checked:false align:#left

    button btn_extract "Extract only" width:190 height:28 align:#center offset:[0,10]
    button btn_merge "Merge extracted" width:190 height:28 align:#center offset:[0,2]
    button btn_execute "Execute Convertor" width:190 height:30 align:#center offset:[0,6]

    label lbl_status "Status: Idle" align:#left offset:[0,5] width:200
    progressbar pb_progress color:(color 0 255 0) height:10 width:200 align:#center offset:[0,5]

    group "Select Sets (LMB: Sel | RMB: Isolate)"
    (
        button btn_sel_original "Original" width:170 height:24 align:#center
        button btn_sel_extracted "Extracted" width:170 height:24 align:#center
        button btn_sel_splitted "Splitted" width:170 height:24 align:#center
    )

    timer tck_update interval:200 active:true

    /*  Save rollout settings.
        Only persistent user options are written. */
    function saveSettings =
    (
        setINISetting ini_file "Settings" "z_threshold" (spn_depth_threshold.value as string)
        setINISetting ini_file "Settings" "weld_before" (chk_weld_before.checked as string)
        setINISetting ini_file "Settings" "corner_knots" (chk_corner_knots.checked as string)
        setINISetting ini_file "Settings" "make_instances" (chk_make_instances.checked as string)
    )

    /*  Load rollout settings.
        Missing values keep current defaults. */
    function loadSettings =
    (
        val = getINISetting ini_file "Settings" "z_threshold"
        if val != "" then
        (
            spn_depth_threshold.value = val as float
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

        val = getINISetting ini_file "Settings" "make_instances"
        if val != "" then
        (
            chk_make_instances.checked = (val == "true")
        )
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

    /*  Weld selected spline knots on prepared source copy.
        Keeps source object untouched. */
    function weldSplineKnots target_shape =
    (
        if isValidNode target_shape then
        (
            old_mode = getCommandPanelTaskMode()

            setCommandPanelTaskMode #modify
            select target_shape
            subObjectLevel = 1
            max select all
            splineOps.weld target_shape
            subObjectLevel = 0

            setCommandPanelTaskMode old_mode
        )
    )

    /*  Select or isolate stored node set.
        Invalid deleted nodes are skipped. */
    function handleSelection target_array isolate_mode =
    (
        valid_nodes = #()

        for obj in target_array do
        (
            if isValidNode obj then
            (
                append valid_nodes obj
            )
        )

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
            convertToSplineShape working_copy
            working_copy.name = uniqueName (source_shape.name + "_ExtractSource_")

            if chk_weld_before.checked then
            (
                weldSplineKnots working_copy
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
    function runExtractOnly =
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
                pb_progress.value = 0
                windows.processPostedMessages()

                working_copy = makeWorkingCopy source_shape

                if working_copy != undefined then
                (
                    window_manager = SplineToObjConvertor_v z_tolerance:spn_depth_threshold.value prog_bar:pb_progress lbl_status:lbl_status prefix:shape_prefix
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

            handleSelection extracted_shapes false
            lbl_status.text = "Extract only complete. Extracted: " + (extracted_shapes.count as string)
            pb_progress.value = 100
            format "SplineExtractor 0.04: Extract only complete. Extracted nodes: %\n" extracted_shapes.count
        )
        else
        (
            print "Please select shapes to extract."
        )

        extracted_shapes -- return
    )

    /*  Run only merge step on previously extracted nodes.
        If Extracted set is empty, current selection is used as test input. */
    function runMergeOnly =
    (
        merge_input = #()
        splitted_shapes = #()

        for obj in extracted_shapes do
        (
            if isValidNode obj then
            (
                append merge_input obj
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
            pb_progress.value = 0
            windows.processPostedMessages()

            window_manager = SplineToObjConvertor_v z_tolerance:spn_depth_threshold.value prog_bar:pb_progress lbl_status:lbl_status prefix:"[Merge] "
            final_merged_shapes = window_manager.groupAndMerge merge_input

            if chk_make_instances.checked then
            (
                instancer = SplineInstancer_v dim_tolerance:0.1 prog_bar:pb_progress lbl_status:lbl_status prefix:"[Instance] "
                reinstanced_shapes = instancer.reinstanceShapes final_merged_shapes

                for rw in reinstanced_shapes do
                (
                    append splitted_shapes rw
                )
            )
            else
            (
                for rw in final_merged_shapes do
                (
                    if isValidNode rw then
                    (
                        append splitted_shapes rw
                    )
                )
            )

            handleSelection splitted_shapes false
            lbl_status.text = "Merge complete. Clusters: " + (splitted_shapes.count as string)
            pb_progress.value = 100
            format "SplineExtractor 0.04: Merge complete. Clusters: %\n" splitted_shapes.count
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
    )

    on spline_obj_rollout close do
    (
        saveSettings()
    )

    on tck_update tick do
    (
        lbl_sel_count.text = "Selected: " + (selection.count as string)
    )

    on btn_load_depth pressed do
    (
        max_depth = 0.0

        if selection.count > 0 then
        (
            for obj in selection do
            (
                if isValidNode obj then
                (
                    local_bounds = nodeLocalBoundingBox obj
                    s_min = local_bounds[1]
                    s_max = local_bounds[2]

                    dim_x = abs (s_max.x - s_min.x)
                    dim_y = abs (s_max.y - s_min.y)
                    dim_z = abs (s_max.z - s_min.z)
                    current_depth = amin #(dim_x, dim_y, dim_z)

                    if current_depth > max_depth then
                    (
                        max_depth = current_depth
                    )
                )
            )

            spn_depth_threshold.value = max_depth
        )
        else
        (
            print "Please select shapes to calculate the bounding box depth."
        )
    )

    on btn_extract pressed do
    (
        runExtractOnly()
    )

    on btn_merge pressed do
    (
        runMergeOnly()
    )

    on btn_execute pressed do
    (
        if selection.count > 0 then
        (
            runExtractOnly()
            runMergeOnly()
            print "SplineExtractor 0.04: Execute Convertor complete."
        )
        else
        (
            print "Please select shapes to process."
        )
    )

    on btn_sel_original pressed do
    (
        handleSelection original_shapes false
    )

    on btn_sel_original rightclick do
    (
        handleSelection original_shapes true
    )

    on btn_sel_extracted pressed do
    (
        handleSelection extracted_shapes false
    )

    on btn_sel_extracted rightclick do
    (
        handleSelection extracted_shapes true
    )

    on btn_sel_splitted pressed do
    (
        handleSelection splitted_shapes false
    )

    on btn_sel_splitted rightclick do
    (
        handleSelection splitted_shapes true
    )
)

createDialog spline_obj_rollout
